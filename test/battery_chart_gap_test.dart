import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';
import 'package:silversole/shared/widgets/chart/record_imu_chart_section.dart';

const _batteries = [80, 255, 60];

ImuNotifyDataModel _imu(int battery) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: const [0, 0, 0],
  batteryPercent: battery,
  isCharging: false,
);

RecordImuNotifyDataModel _record(int battery) => RecordImuNotifyDataModel(
  timestamp: 0,
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: const [0, 0, 0],
  wearStatus: true,
  batteryPercent: battery,
);

/// Renders [chart] against telemetry seeded by [seed] and returns the spots of
/// its single drawn line.
Future<List<FlSpot>> _renderedSpots(
  WidgetTester tester,
  Widget chart,
  void Function(LiveTelemetryNotifier live) seed,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  seed(container.read(liveTelemetryProvider.notifier));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: chart)),
    ),
  );
  await tester.pumpAndSettle();

  final bars = tester
      .widget<LineChart>(find.byType(LineChart))
      .data
      .lineBarsData;
  return bars.single.spots;
}

void _expectGapAtInvalidBattery(List<FlSpot> spots) {
  expect(spots, hasLength(_batteries.length));
  expect(spots[0].y, 80);
  expect(spots[1].isNull(), isTrue);
  expect(spots[2].y, 60);
}

void main() {
  testWidgets('live battery line skips a 255 reading', (tester) async {
    final spots = await _renderedSpots(
      tester,
      const ImuChartSection(type: ChardDisplayType.single, selectedList: [4]),
      (live) => _batteries.map(_imu).forEach(live.updateImuNotifyData),
    );
    _expectGapAtInvalidBattery(spots);
  });

  testWidgets('record battery line skips a 255 reading', (tester) async {
    final spots = await _renderedSpots(
      tester,
      const RecordImuChartSection(
        type: ChardDisplayType.single,
        selectedList: [3],
      ),
      (live) => _batteries.map(_record).forEach(live.updateRecordImuNotifyData),
    );
    _expectGapAtInvalidBattery(spots);
  });
}
