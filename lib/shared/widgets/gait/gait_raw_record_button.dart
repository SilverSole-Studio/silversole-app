import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/gait/gait_recording.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/create_file_and_share.dart';

/// Debug builds only: records raw live samples from every sole and shares
/// them as a file for `tool/gait_replay.dart`.
///
/// Not localized on purpose — release builds never show it (the analytics
/// pages guard it with `kDebugMode`).
class GaitRawRecordButton extends ConsumerStatefulWidget {
  const GaitRawRecordButton({super.key});

  @override
  ConsumerState<GaitRawRecordButton> createState() =>
      _GaitRawRecordButtonState();
}

class _GaitRawRecordButtonState extends ConsumerState<GaitRawRecordButton> {
  GaitRecording? _recording;
  StreamSubscription<SoleSample>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    final recording = GaitRecording(clock.now());
    _sub = ref.read(soleSampleBusProvider).stream.listen((s) {
      final d = s.data;
      recording.add(
        at: clock.now(),
        soleKey: s.identityKey,
        foot: ref
            .read(settingsProvider)
            .pairedDevicesList
            .firstWhereOrNull((p) => p.identityKey == s.identityKey)
            ?.footSide,
        pressure: d.pressure,
        imu: [d.ax, d.ay, d.az, d.gx, d.gy, d.gz],
      );
      // Redraw the sample count about once a second, not on every packet.
      if (recording.length % 50 == 0 && mounted) setState(() {});
    });
    setState(() => _recording = recording);
  }

  Future<void> _stop() async {
    final recording = _recording;
    await _sub?.cancel();
    _sub = null;
    setState(() => _recording = null);
    if (recording == null || recording.length == 0) return;
    final stamp = recording.startedAt.toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    await createFileAndShare(
      fileName: 'gait_raw_$stamp.json',
      content: recording.encode(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    return OutlinedButton.icon(
      onPressed: recording == null ? _start : _stop,
      icon: Icon(recording == null ? Icons.fiber_manual_record : Icons.stop),
      label: Text(
        recording == null
            ? 'Record raw gait data (debug)'
            : 'Stop and share · ${recording.length} samples',
      ),
    );
  }
}
