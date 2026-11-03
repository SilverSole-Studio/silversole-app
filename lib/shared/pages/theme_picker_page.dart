import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';
import 'package:silversole/shared/providers/theme_variant_provider.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// Translation key of a look's name.
String themeNameKey(AppThemeVariant v) => switch (v) {
  AppThemeVariant.mascot => 'theme_mascot',
  AppThemeVariant.techLight => 'theme_tech_light',
  AppThemeVariant.techDark => 'theme_tech_dark',
  AppThemeVariant.dashboard => 'theme_dashboard',
  AppThemeVariant.journal => 'theme_journal',
};

String _hintKey(AppThemeVariant v) => '${themeNameKey(v)}_hint';

/// 設定 → 切換主題: the five looks, each with a small picture and a name. The
/// three free ones switch at once; the two for subscribers show a lock and
/// 「訂閱後可用」, and tapping one opens the subscription page.
class ThemePickerPage extends ConsumerWidget {
  const ThemePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeVariantProvider);
    final subscribed = ref.watch(subscriptionActiveProvider);

    Widget tile(AppThemeVariant v) {
      final locked = v.requiresSubscription && !subscribed;
      return AppCard(
        weight: v == current ? CardWeight.hero : CardWeight.standard,
        onTap: () async {
          if (locked) {
            context.push('/subscription');
            return;
          }
          await ref.read(settingsProvider.notifier).setThemeVariant(v);
        },
        child: Row(
          children: [
            ThemeThumb(variant: v),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    themeNameKey(v).tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked ? 'theme_locked'.tr() : _hintKey(v).tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (v == current)
              _Badge(label: 'theme_in_use'.tr(), icon: LucideIcons.check)
            else if (locked)
              Icon(
                LucideIcons.lock,
                size: 24,
                color: context.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      );
    }

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(text, style: context.textTheme.titleLarge),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'theme_picker_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.xxl,
        ),
        children: [
          section('theme_free_section'.tr()),
          const SizedBox(height: AppSpacing.md),
          for (final v in AppThemeVariant.free) ...[
            tile(v),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          section('theme_subscribers_section'.tr()),
          const SizedBox(height: AppSpacing.md),
          for (final v in AppThemeVariant.values.where(
            (v) => v.requiresSubscription,
          )) ...[tile(v), const SizedBox(height: AppSpacing.md)],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.primary,
        borderRadius: AppRadius.pillR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A miniature of a look's home screen, drawn with plain boxes: enough to tell
/// the five apart at a glance without shipping five screenshots.
class ThemeThumb extends StatelessWidget {
  const ThemeThumb({super.key, required this.variant});

  final AppThemeVariant variant;

  static const double width = 60;
  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: _frame(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: _screen(),
        ),
      ),
    );
  }

  BoxDecoration _frame() {
    final line = switch (variant) {
      AppThemeVariant.mascot => AppPaletteT2.ink,
      AppThemeVariant.journal => AppPaletteC.ink,
      AppThemeVariant.dashboard => AppPaletteB.line,
      AppThemeVariant.techLight => const Color(0xFFCFCFCF),
      AppThemeVariant.techDark => const Color(0xFF4A4A4A),
    };
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: line,
        width: variant == AppThemeVariant.mascot ? 2.5 : 1.5,
      ),
    );
  }

  Widget _bar(Color c, {double h = 6, double? w, double r = 3}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
  );

  Widget _screen() {
    switch (variant) {
      case AppThemeVariant.mascot:
        return Container(
          color: AppPaletteT2.canvas,
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(AppPaletteT2.sky, h: 14, r: 2),
              const SizedBox(height: 4),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppPaletteT2.card,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppPaletteT2.ink, width: 1.5),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 9,
                decoration: BoxDecoration(
                  color: AppPaletteT2.gold,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppPaletteT2.ink, width: 1.5),
                ),
              ),
              const Spacer(),
              _bar(AppPaletteT2.card, h: 8, r: 2),
            ],
          ),
        );
      case AppThemeVariant.techLight:
        return Container(
          color: const Color(0xFFF2F3F5),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(const Color(0xFF1B1B1F), w: 24, h: 5),
              const SizedBox(height: 5),
              Container(
                height: 30,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _bar(AppPalette.brandSeed, h: 14, w: 22, r: 2),
              ),
              const SizedBox(height: 4),
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const Spacer(),
              _bar(Colors.white, h: 8, r: 2),
            ],
          ),
        );
      case AppThemeVariant.techDark:
        return Container(
          color: const Color(0xFF121316),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(const Color(0xFFE6E6EA), w: 24, h: 5),
              const SizedBox(height: 5),
              Container(
                height: 30,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _bar(AppPalette.brandSeed, h: 14, w: 22, r: 2),
              ),
              const SizedBox(height: 4),
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F24),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const Spacer(),
              _bar(const Color(0xFF1E1F24), h: 8, r: 2),
            ],
          ),
        );
      case AppThemeVariant.dashboard:
        return Container(
          color: AppPaletteB.bg,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPaletteB.yellow, width: 4),
                ),
              ),
              const SizedBox(height: 6),
              _bar(AppPaletteB.yellow, h: 9, r: 5),
              const SizedBox(height: 5),
              _bar(AppPaletteB.panel, h: 14, r: 5),
              const Spacer(),
              _bar(AppPaletteB.panel, h: 8, r: 2),
            ],
          ),
        );
      case AppThemeVariant.journal:
        return Container(
          color: AppPaletteC.paper,
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.rotate(
                angle: -0.03,
                child: _bar(AppPaletteC.sage, h: 6, w: 22, r: 1),
              ),
              const SizedBox(height: 5),
              Transform.rotate(
                angle: -0.03,
                child: _bar(AppPaletteC.butter, h: 34, r: 2),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(child: _bar(AppPaletteC.sage, h: 16, r: 6)),
                  const SizedBox(width: 3),
                  Expanded(child: _bar(AppPaletteC.peach, h: 16, r: 6)),
                ],
              ),
              const Spacer(),
              _bar(AppPaletteC.card, h: 8, r: 2),
            ],
          ),
        );
    }
  }
}
