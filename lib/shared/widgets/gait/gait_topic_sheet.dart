import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';

/// The ⓘ beside a metric name. Opens what the number means, the caveat a family
/// member needs, and the literature it rests on.
///
/// Every metric on the gait tab carries one, because a number a family is asked
/// to act on has to be able to explain itself.
class GaitTopicButton extends StatelessWidget {
  const GaitTopicButton({super.key, required this.topic});

  final GaitTopic topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showGaitTopicSheet(context, topic),
      icon: const Icon(LucideIcons.circleHelp),
      iconSize: 15,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      color: context.colorScheme.onSurfaceVariant,
      tooltip: topic.titleKey.tr(),
    );
  }
}

Future<void> showGaitTopicSheet(BuildContext context, GaitTopic topic) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GaitTopicSheet(topic: topic),
    );

class _GaitTopicSheet extends StatelessWidget {
  const _GaitTopicSheet({required this.topic});

  final GaitTopic topic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.base,
            children: [
              Text(topic.titleKey.tr(), style: context.textTheme.titleLarge),
              Text(topic.bodyKey.tr(), style: context.textTheme.bodyLarge),
              if (topic.hasNote)
                _Aside(
                  label: 'gait_help_note_label'.tr(),
                  text: topic.noteKey.tr(),
                  accent: context.tokens.dataOrange,
                ),
              if (topic.hasEvidence)
                _Aside(
                  label: 'gait_help_evidence_label'.tr(),
                  text: topic.evidenceKey.tr(),
                  accent: context.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A block with an accent rule down its left edge, the way the design marks an
/// aside apart from the body copy.
class _Aside extends StatelessWidget {
  const _Aside({required this.label, required this.text, required this.accent});

  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(AppRadius.sub),
        ),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(color: accent),
            ),
            Text(text, style: context.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
