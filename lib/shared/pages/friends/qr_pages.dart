import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/qr_timing.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/add_flows.dart';
import 'package:silversole/shared/pages/friends/enter_code_page.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// `/friends/my-qr` — show my QR and friend code to someone standing next to
/// me (spec §3.1).
///
/// The QR is a 5-minute token, renewed at half its life while the page stays
/// open (timed with a [Stopwatch], so a phone whose clock is off still shows
/// a live QR). When the server cannot be reached the page says so and offers
/// a retry, while retrying on its own with growing gaps.
///
/// Requests that arrive while it is showing pop up right here, so both
/// people can finish on the spot: the page re-reads requests every 3 seconds
/// (the app does not use Realtime).
class MyQrPage extends ConsumerStatefulWidget {
  const MyQrPage({super.key});

  @override
  ConsumerState<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends ConsumerState<MyQrPage> {
  static const _tickEvery = Duration(seconds: 1);
  static const _pollEveryTicks = 3;

  /// A request that never answers counts as a failure, so the page cannot
  /// spin forever.
  static const _requestTimeout = Duration(seconds: 15);

  final _elapsed = Stopwatch()..start();
  final _renewal = QrTokenRenewal(ttl: kQrTokenTtl);
  QrToken? _token;
  Object? _tokenError;
  bool _fetching = false;
  Timer? _timer;
  int _ticks = 0;
  late final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _renewToken();
    _timer = Timer.periodic(_tickEvery, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _renewToken() async {
    if (_fetching) return;
    _fetching = true;
    final result = await ref
        .read(friendsRepositoryProvider)
        .createQrToken()
        .timeout(
          _requestTimeout,
          onTimeout: () =>
              const Result.error(FriendException(FriendError.offline)),
        );
    if (!mounted) return;
    setState(() {
      _fetching = false;
      switch (result) {
        case Ok(:final value):
          _token = value;
          _tokenError = null;
          _renewal.issued(_elapsed.elapsed);
        case Error(:final error):
          _tokenError = error;
          _renewal.failed(_elapsed.elapsed);
      }
    });
  }

  void _tick() {
    final now = _elapsed.elapsed;
    if (_renewal.shouldRenew(now)) _renewToken();
    // Renewals kept failing and this one has run out: take it off the
    // screen rather than show a QR that no longer works.
    if (_token != null && _renewal.isExpired(now)) {
      setState(() => _token = null);
    }
    if (++_ticks % _pollEveryTicks == 0) {
      ref.invalidate(friendRequestsProvider);
    }
  }

  /// The QR on its white card, a spinner while the first one is on its way,
  /// or what went wrong and a retry button.
  Widget _qrBox() {
    final token = _token;
    final error = _tokenError;
    if (token == null && error != null) {
      return Column(
        spacing: AppSpacing.base,
        children: [
          Text(
            friendErrorText(error),
            style: context.textTheme.titleLarge?.copyWith(
              color: context.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          FriendButton(
            label: 'friends_qr_retry'.tr(),
            icon: Icons.refresh,
            onPressed: _renewToken,
          ),
        ],
      );
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.colorScheme.outline),
        ),
        child: token == null
            ? const SizedBox(
                width: 260,
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : QrImageView(
                data: personQrPayload(token.token),
                size: 260,
                backgroundColor: Colors.white,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myFriendProfileProvider).value;
    final requests = ref.watch(friendRequestsProvider).value ?? const [];
    // Only what came in while this page was up — older ones live on the
    // requests page.
    final arrivedHere = requests
        .where((r) => r.incoming && r.createdAt.isAfter(_openedAt))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('friends_my_qr'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            for (final r in arrivedHere) _InlineRequest(request: r),
            FriendText('friends_my_qr_hint'.tr(), center: true),
            const SizedBox(height: AppSpacing.base),
            _qrBox(),
            const SizedBox(height: AppSpacing.lg),
            if (me != null) ...[
              FriendText('friends_or_read_code'.tr(), center: true),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatCode(me.friendCode),
                style: context.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FriendButton(
                label: 'friends_rotate_code'.tr(),
                secondary: true,
                onPressed: () => _confirmRotate(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRotate(BuildContext context) async {
    final ok = await confirmFriendAction(
      context,
      title: 'friends_rotate_code'.tr(),
      body: 'friends_rotate_code_confirm'.tr(),
      confirmLabel: 'friends_rotate_code_yes'.tr(),
    );
    if (!ok) return;
    await runFriendAction(
      ref,
      ref.read(friendsRepositoryProvider).rotateFriendCode,
      successText: 'friends_rotate_code_done'.tr(),
    );
  }
}

class _InlineRequest extends ConsumerWidget {
  const _InlineRequest({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          spacing: AppSpacing.md,
          children: [
            Row(
              spacing: AppSpacing.md,
              children: [
                FriendAvatar.of(request.other, size: 64),
                Expanded(
                  child: FriendText(
                    'friends_wants_to_add_you'.tr(
                      args: [request.other.nickname],
                    ),
                  ),
                ),
              ],
            ),
            FriendButton(
              label: 'friends_accept'.tr(),
              onPressed: () => runFriendAction(
                ref,
                () => ref
                    .read(friendsRepositoryProvider)
                    .respondFriendRequest(
                      request.id,
                      FriendRequestAction.accept,
                    ),
                successText: 'friends_now_friends'.tr(
                  args: [request.other.nickname],
                ),
              ),
            ),
            FriendButton(
              label: 'friends_decline'.tr(),
              secondary: true,
              onPressed: () => runFriendAction(
                ref,
                () => ref
                    .read(friendsRepositoryProvider)
                    .respondFriendRequest(
                      request.id,
                      FriendRequestAction.decline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `/friends/scan` — scan a friend's QR or an org poster.
class ScanQrPage extends ConsumerStatefulWidget {
  const ScanQrPage({super.key});

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final _elapsed = Stopwatch()..start();

  /// A code that was just dealt with is not picked up again while it stays
  /// in view — an org poster on the wall would otherwise spend a lookup on
  /// every frame.
  final _debounce = ScanDebouncer();
  bool _handling = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !_debounce.accept(raw, _elapsed.elapsed)) return;
    _handling = true;
    await _controller.stop();
    await _handle(ScannedQr.parse(raw));
    if (!mounted) return;
    _debounce.settle(_elapsed.elapsed);
    _handling = false;
    await _controller.start();
  }

  Future<void> _handle(ScannedQr qr) async {
    final repo = ref.read(friendsRepositoryProvider);
    switch (qr) {
      case PersonQr(:final token):
        final result = await repo.previewByQr(token);
        if (!mounted) return;
        switch (result) {
          case Ok(:final value):
            setState(() => _message = null);
            final sent = await showAddFriendSheet(
              context,
              ref,
              person: value,
              source: FriendSource.qr,
              reference: token,
            );
            if (sent && mounted) Navigator.of(context).maybePop();
          case Error(:final error):
            setState(
              () => _message = friendErrorText(error, FriendErrorScope.qr),
            );
        }
      case OrgQr(:final joinCode):
        final result = await repo.previewOrg(joinCode);
        if (!mounted) return;
        switch (result) {
          case Ok(:final value):
            setState(() => _message = null);
            await showJoinOrgSheet(
              context,
              ref,
              org: value,
              joinCode: joinCode,
            );
          case Error(:final error):
            setState(
              () => _message = friendErrorText(error, FriendErrorScope.org),
            );
        }
      case UnknownQr():
        setState(() => _message = 'friends_not_our_qr'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'friends_scan_qr'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: FriendText('friends_scan_hint'.tr(), center: true),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => Container(
                      color: context.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      alignment: Alignment.center,
                      child: FriendText(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'friends_camera_denied'.tr()
                            : 'friends_camera_failed'.tr(),
                        center: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                spacing: AppSpacing.sm,
                children: [
                  if (_message != null)
                    Text(
                      _message!,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: context.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  FriendButton(
                    label: 'friends_type_code_instead'.tr(),
                    secondary: true,
                    icon: Icons.dialpad,
                    onPressed: () => context.pushReplacement(
                      '/friends/code',
                      extra: CodeMode.friend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
