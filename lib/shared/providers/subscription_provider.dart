import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/shared/providers/dev_tools_provider.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';

/// Monthly price shown on the subscription page (NT\$).
const kSubscriptionMonthlyPrice = 149;

/// The test switch on the subscription page: "pretend subscribed". Stored on
/// this phone only, and only honoured in debug builds and developer mode (see
/// [subscriptionActiveProvider]).
class FakeSubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final raw = await loadLocalValue(LocalSavableKey.fakeSubscription);
    if (!ref.mounted) return;
    if (raw == 'true') state = true;
  }

  /// Test-only switch (debug / developer mode).
  Future<void> setFake(bool on) async {
    await saveLocalValue(
      LocalSavableKey.fakeSubscription,
      on ? 'true' : 'false',
    );
    if (!ref.mounted) return;
    state = on;
  }
}

final fakeSubscriptionProvider =
    NotifierProvider<FakeSubscriptionNotifier, bool>(
      FakeSubscriptionNotifier.new,
    );

/// Whether the signed-in account's subscription covers today, as the server
/// says it (the `subscriptions` row has `active_until >= today`; read through
/// `diamond_balance`). False before the first answer, offline and signed out.
final serverSubscribedProvider = Provider<bool>(
  (ref) =>
      ref.watch(diamondsProvider.select((s) => s.balance?.subscribed ?? false)),
);

/// Whether this account has an active subscription.
///
/// The server decides. There is no billing yet (user 2026-11-02: open it by
/// hand): an admin sets `active_until` on the account's `subscriptions` row,
/// see `docs/diamonds-subscription-admin.md`. In debug builds and developer
/// mode the test switch on the subscription page can also force it on, which
/// is a display-only pretence: the server still pays no diamonds to an
/// account it does not know as subscribed. When Google Play Billing /
/// StoreKit is wired up, the store should write the same row.
final subscriptionActiveProvider = Provider<bool>((ref) {
  if (ref.watch(serverSubscribedProvider)) return true;
  return ref.watch(devToolsVisibleProvider) &&
      ref.watch(fakeSubscriptionProvider);
});
