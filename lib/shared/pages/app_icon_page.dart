import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/app_icon/app_icon_choice.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// Overridable in tests.
final appIconGatewayProvider = Provider<AppIconGateway>(
  (_) => const PluginAppIconGateway(),
);

/// The icon in use right now, as the platform reports it.
final appIconChoiceProvider = FutureProvider.autoDispose<AppIconChoice>((
  ref,
) async {
  final gateway = ref.watch(appIconGatewayProvider);
  try {
    return await gateway.current();
  } catch (_) {
    return AppIconChoice.standard;
  }
});

/// 我的 → App 圖示: three big icons, tap one, the chosen one wears a tick.
class AppIconPage extends ConsumerStatefulWidget {
  const AppIconPage({super.key, this.showAndroidNote});

  /// Null = show the Android note on Android only.
  final bool? showAndroidNote;

  @override
  ConsumerState<AppIconPage> createState() => _AppIconPageState();
}

class _AppIconPageState extends ConsumerState<AppIconPage> {
  AppIconChoice? _picked;
  bool _busy = false;

  Future<void> _choose(AppIconChoice c) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _picked = c;
    });
    try {
      await ref.read(appIconGatewayProvider).choose(c);
      ref.invalidate(appIconChoiceProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _picked = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('app_icon_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appIconChoiceProvider).value;
    final selected = _picked ?? current ?? AppIconChoice.standard;
    final note = widget.showAndroidNote ?? Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(
        title: Text('app_icon_title'.tr(), style: context.textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xxl,
        ),
        children: [
          if (note) ...[
            Text(
              'app_icon_note_android'.tr(),
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.base),
          ],
          for (final c in AppIconChoice.values) ...[
            AppCard(
              weight: c == selected ? CardWeight.hero : CardWeight.standard,
              onTap: () => _choose(c),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      c.previewAsset,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Text(
                      c.nameKey.tr(),
                      style: context.textTheme.titleLarge,
                    ),
                  ),
                  if (c == selected)
                    Icon(
                      LucideIcons.circleCheck,
                      size: 36,
                      color: context.colorScheme.primary,
                      semanticLabel: 'app_icon_in_use'.tr(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
