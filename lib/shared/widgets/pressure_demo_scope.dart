import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/demo_motion_clip.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';

/// Canned motions the sample menu can replay, each backed by a bundled
/// recording. A schema-2 clip carries both feet, already time-aligned.
enum DemoMotion {
  walk(
    'walk',
    'assets/foot-pressure-heatmpt-samples/synthetic_walk_pair_30s.json',
  );

  const DemoMotion(this.labelKey, this.asset);

  /// Key in `strings.csv`.
  final String labelKey;
  final String asset;
}

/// The readings a [PressureDemoScope] hands to its builder.
class PressureReading {
  const PressureReading({
    required this.right,
    required this.left,
    required this.hasData,
  });

  final List<int> right;

  /// Null whenever nothing is feeding the left foot — which is every live BLE
  /// session, since the sole only reports a right foot.
  final List<int>? left;

  /// False only when there is nothing to show at all.
  final bool hasData;
}

/// Signature of [PressureDemoScope.builder]: the readings to render, plus the
/// sample menu to place above the heat map.
typedef PressureDemoBuilder =
    Widget Function(
      BuildContext context,
      PressureReading reading,
      Widget header,
    );

/// Owns sample-clip playback for the plantar-pressure heat map, and hands the
/// readings to render to [builder] — a looping clip frame while a sample plays,
/// otherwise the latest live BLE sample.
///
/// State is local to this widget, so nothing here touches the live telemetry
/// providers and playback stops as soon as the host leaves the screen.
class PressureDemoScope extends ConsumerStatefulWidget {
  const PressureDemoScope({super.key, required this.builder});

  final PressureDemoBuilder builder;

  @override
  ConsumerState<PressureDemoScope> createState() => _PressureDemoScopeState();
}

class _PressureDemoScopeState extends ConsumerState<PressureDemoScope> {
  DemoMotion? _motion;
  DemoMotionClip? _clip;
  Timer? _ticker;
  int _frame = 0;

  /// Bumped per selection so a slow asset load cannot revive a motion the user
  /// has already switched away from.
  int _loadId = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Starts looping [motion], or returns to live telemetry when null.
  Future<void> _select(DemoMotion? motion) async {
    _ticker?.cancel();
    _ticker = null;
    final loadId = ++_loadId;
    setState(() {
      _motion = motion;
      _clip = null;
      _frame = 0;
    });
    if (motion == null) return;

    final clip = await _loadClip(motion.asset);
    if (!mounted || loadId != _loadId) return;
    if (clip == null) {
      setState(() => _motion = null);
      return;
    }
    setState(() => _clip = clip);
    _ticker = Timer.periodic(clip.frameInterval, (_) {
      setState(() => _frame = (_frame + 1) % clip.right.length);
    });
  }

  /// Decodes the bundle bytes here rather than via `loadString`, which hands
  /// large payloads to an isolate — these clips are small enough to decode
  /// inline and it keeps playback deterministic.
  Future<DemoMotionClip?> _loadClip(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      return DemoMotionClip.parse(
        utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imu = ref.watch(telemetryViewProvider).recentImu;
    final clip = _clip;
    final left = clip?.left;

    return widget.builder(
      context,
      PressureReading(
        right:
            clip?.right[_frame] ??
            (imu.isNotEmpty ? imu.last.pressure : const <int>[0, 0, 0]),
        // Same frame index — the parser already put both feet on one timeline.
        left: left?[_frame],
        hasData: clip != null || imu.isNotEmpty,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [_DemoMenuButton(active: _motion, onSelect: _select)],
      ),
    );
  }
}

/// Every entry acts through [PopupMenuItem.onTap] because `onSelected` cannot
/// carry the "stop" choice — a null menu value is indistinguishable from
/// dismissing the menu.
class _DemoMenuButton extends StatelessWidget {
  const _DemoMenuButton({required this.active, required this.onSelect});

  final DemoMotion? active;
  final ValueChanged<DemoMotion?> onSelect;

  @override
  Widget build(BuildContext context) {
    final color = active == null
        ? context.colorScheme.onSurfaceVariant
        : context.tokens.dataOrange;
    return PopupMenuButton<void>(
      tooltip: 'demo_motion'.tr(),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final motion in DemoMotion.values)
          CheckedPopupMenuItem<void>(
            checked: motion == active,
            onTap: () => onSelect(motion),
            child: Text(motion.labelKey.tr()),
          ),
        if (active != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            onTap: () => onSelect(null),
            child: Text('demo_motion_off'.tr()),
          ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'demo_motion'.tr(),
              style: context.textTheme.labelLarge?.copyWith(color: color),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(LucideIcons.chevronDown, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
