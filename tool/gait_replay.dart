import 'dart:io';

import 'package:silversole/core/gait/gait_recording.dart';

/// Prints what each raw gait recording comes to, for tuning `GaitConfig`.
///
///     dart run tool/gait_replay.dart walk100.json sit2min.json
void main(List<String> paths) {
  if (paths.isEmpty) {
    stderr.writeln('usage: dart run tool/gait_replay.dart <recording.json>...');
    exitCode = 64;
    return;
  }
  String pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
  for (final path in paths) {
    final result = replayGaitRecording(File(path).readAsStringSync());
    if (result == null) {
      stdout.writeln('$path: not a gait recording');
      continue;
    }
    final d = result.day;
    stdout.writeln(
      [
        path,
        'samples=${result.samples}',
        'contacts=${result.rawContacts}',
        'steps=${d.steps}',
        'walking=${(d.walkingMs / 1000).toStringAsFixed(1)}s',
        'cadence=${d.cadence?.toStringAsFixed(1) ?? '-'}',
        'stance=${pct(d.stanceRatio)}',
        'cv=${pct(d.strideCv)}',
        'symmetry=${pct(d.symmetry)}',
        'double_support=${pct(d.doubleSupportRatio)}',
      ].join('  '),
    );
  }
}
