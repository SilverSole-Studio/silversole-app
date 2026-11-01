import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/ai_missions_provider.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

/// Opens the "daily missions" sheet (the home FAB's mission action).
Future<void> showDailyMissionsBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const DailyMissionsSheet(),
  );
}

/// A single daily mission, as the sheet draws it.
class _Mission {
  const _Mission({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.completed = false,
    this.onGo,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Already done → shows the "done" pill instead of a button.
  final bool completed;

  /// Tapped from the gray "go" button on an incomplete mission. Null when
  /// [completed].
  final VoidCallback? onGo;
}

/// The icon of each mission in [MissionCatalog].
const _missionIcons = <String, IconData>{
  MissionCatalog.footCheck: LucideIcons.scanLine,
  'walkgroup': LucideIcons.users,
  'bike': LucideIcons.bike,
  'canoe': LucideIcons.ship,
  'fish': LucideIcons.fish,
  'ski': LucideIcons.snowflake,
  'hop': LucideIcons.footprints,
  'rhythm': LucideIcons.music,
  'quiz': LucideIcons.circleQuestionMark,
  'pool': LucideIcons.circleDot,
  MissionCatalog.laojie: LucideIcons.landmark,
};

/// Bottom-sheet body listing today's missions. Incomplete missions show a gray
/// "go" button that routes to where the mission is done (no reward amount —
/// there are no rewards); completed ones show a "done" pill.
///
/// Which missions are listed is today's [MissionPlan]
/// ([todayMissionPlanProvider]): picked from the wearer's own record the first
/// time the sheet opens that day, then kept. A mission is done only when the
/// app itself recorded it: a foot check finished today ([lastFootCheckProvider])
/// or a round of that very game the game page reported today
/// ([gameActivityProvider]). There is no walking mission here: the app has no
/// pedometer of its own to count it with.
///
/// Only with `AI_MISSIONS` on ([aiMissionsEnabledProvider]): the first opening
/// asks whether the wearer agrees to have their numbers sent so Claude can
/// write the day's wording, the bottom of the sheet has a switch to change
/// that, and a plan the server wrote shows its greeting, each mission's
/// reason and an "AI picks" label. With it off none of that exists.
class DailyMissionsSheet extends ConsumerStatefulWidget {
  const DailyMissionsSheet({super.key});

  @override
  ConsumerState<DailyMissionsSheet> createState() => _DailyMissionsSheetState();
}

class _DailyMissionsSheetState extends ConsumerState<DailyMissionsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askFirstTime());
  }

  /// The first time the sheet opens with AI on and no answer yet. Closing the
  /// dialog any other way than a button leaves it unanswered: asked again next
  /// time.
  Future<void> _askFirstTime() async {
    if (!ref.read(aiMissionsEnabledProvider)) return;
    final consent = await ref.read(aiMissionsConsentProvider.future);
    if (!mounted || consent != AiMissionsConsent.unset) return;
    final agreed = await _askConsent(context);
    if (agreed == null) return;
    await ref
        .read(aiMissionsConsentProvider.notifier)
        .set(agreed ? AiMissionsConsent.yes : AiMissionsConsent.no);
  }

  /// The switch at the bottom. Turning it on from anything but a yes asks
  /// again, so what is sent is always shown before it is agreed to.
  Future<void> _onSwitch(bool on) async {
    final notifier = ref.read(aiMissionsConsentProvider.notifier);
    if (!on) return notifier.set(AiMissionsConsent.no);
    final agreed = await _askConsent(context);
    if (agreed == true) await notifier.set(AiMissionsConsent.yes);
  }

  _Mission _mission(
    BuildContext context,
    MissionPlanItem item, {
    required DateTime today,
    required bool done,
  }) {
    final id = item.id;
    final isCheck = id == MissionCatalog.footCheck;
    final title = MissionCatalog.titleKey(id).tr();
    return _Mission(
      icon: _missionIcons[id] ?? LucideIcons.circle,
      title: title,
      // A finished row says so, whatever the plan wrote; the AI's reason is
      // for the missions still to do.
      subtitle: done
          ? 'mission_done'.tr()
          : (item.reason ??
                (isCheck
                    ? 'mission_measure_subtitle'.tr()
                    : 'mission_game_subtitle'.tr())),
      completed: done,
      onGo: done
          ? null
          : () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              if (isCheck) {
                router.push('/foot-check');
              } else {
                router.push(
                  '/game-webview',
                  extra: {
                    'url':
                        '${Constants.gameUrl}${MissionCatalog.gamePath(id, today)}',
                    'title': title,
                    // A finished game's "back to the town" leaves this game:
                    // close the page and land back on the home screen.
                    'closeOnLeavePath': true,
                  },
                );
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final footCheck = ref.watch(lastFootCheckProvider);
    final activity = ref.watch(gameActivityProvider);
    final today = clock.now();
    final saved = ref.watch(todayMissionPlanProvider);
    // The plan only fails to load if something unexpected broke: show the
    // rules' pick for today rather than a spinner that never ends.
    final plan =
        saved.value ??
        (saved.hasError
            ? planByRules(
                today: today,
                activity: activity,
                lastFootCheck: footCheck,
              )
            : null);
    final missions = [
      for (final item in plan?.items ?? const <MissionPlanItem>[])
        _mission(
          context,
          item,
          today: today,
          done: MissionCatalog.isCompleted(
            item.id,
            today: today,
            activity: activity,
            lastFootCheck: footCheck,
          ),
        ),
    ];
    final remaining = missions.where((m) => !m.completed).length;
    final aiEnabled = ref.watch(aiMissionsEnabledProvider);
    final consent = aiEnabled
        ? ref.watch(aiMissionsConsentProvider).value
        : null;
    final isAi = plan?.source == MissionPlanSource.ai;
    final greeting = isAi ? plan?.greeting : null;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    'daily_missions_title'.tr(),
                    style: context.textTheme.displaySmall,
                  ),
                  if (isAi) const _AiBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (greeting != null) ...[
                Text(greeting, style: context.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (plan != null)
                Text(
                  'daily_missions_subtitle'.tr(args: ['$remaining']),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              if (plan == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (var i = 0; i < missions.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.xl),
                _MissionRow(mission: missions[i]),
              ],
              if (aiEnabled) ...[
                const Divider(height: AppSpacing.xl),
                SwitchListTile(
                  key: const Key('ai_missions_switch'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    LucideIcons.sparkles,
                    color: context.colorScheme.primary,
                  ),
                  title: Text('ai_missions_toggle'.tr()),
                  value: consent == AiMissionsConsent.yes,
                  onChanged: consent == null ? null : _onSwitch,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks whether the numbers may be sent. True for agree, false for "not now",
/// null when the dialog is closed some other way.
Future<bool?> _askConsent(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      const bullets = [
        'ai_missions_consent_item_games',
        'ai_missions_consent_item_plays',
        'ai_missions_consent_item_check',
        'ai_missions_consent_item_gait',
      ];
      return AlertDialog(
        title: Text('ai_missions_consent_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ai_missions_consent_intro'.tr()),
              const SizedBox(height: AppSpacing.sm),
              for (final key in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('・${key.tr()}'),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text('ai_missions_consent_outro'.tr()),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('ai_consent_no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ai_missions_consent_no'.tr()),
          ),
          FilledButton(
            key: const Key('ai_consent_yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('ai_missions_consent_yes'.tr()),
          ),
        ],
      );
    },
  );
}

/// The "AI picks" label by the sheet's title: an icon and words, so it does
/// not rest on a colour or a symbol alone.
class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sparkles, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'ai_missions_badge'.tr(),
            style: context.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});

  final _Mission mission;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: Icon(
              mission.icon,
              size: 32,
              color: context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mission.title, style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                mission.subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _Trailing(mission: mission),
      ],
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.mission});

  final _Mission mission;

  @override
  Widget build(BuildContext context) {
    if (mission.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: ShapeDecoration(
          color: context.tokens.success.withValues(alpha: 0.14),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'mission_done'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.tokens.success,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(LucideIcons.check, size: 16, color: context.tokens.success),
          ],
        ),
      );
    }

    // Incomplete: a neutral gray "go" button (no reward amount) that routes to
    // where the mission is completed.
    return FilledButton(
      onPressed: mission.onGo,
      style: FilledButton.styleFrom(
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        foregroundColor: context.colorScheme.onSurface,
        elevation: 0,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        textStyle: context.textTheme.labelLarge,
        shape: AppRadius.pillShape,
      ),
      child: Text('mission_go'.tr()),
    );
  }
}
