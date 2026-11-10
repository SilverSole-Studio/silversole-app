import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/game_orientation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final orientationCalls = <List<dynamic>>[];
  final uiModes = <String>[];

  setUp(() {
    orientationCalls.clear();
    uiModes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add(call.arguments as List<dynamic>);
          } else if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            uiModes.add(call.arguments.toString());
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('entering allows landscape, leaving goes back to portrait only', (
    tester,
  ) async {
    var show = true;
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return show
                ? const GameOrientationScope(child: SizedBox())
                : const SizedBox();
          },
        ),
      ),
    );
    expect(
      orientationCalls.last,
      containsAll([
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]),
    );

    set(() => show = false);
    await tester.pump();
    expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('landscape hides system bars, rotation keeps the child state', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: GameOrientationScope(child: SizedBox(key: key)),
        ),
      );
    }

    addTearDown(tester.view.reset);
    await pumpAt(const Size(400, 800));
    final element = key.currentContext;
    await pumpAt(const Size(800, 400));
    expect(uiModes.last, contains('immersiveSticky'));
    expect(key.currentContext, same(element));
  });
}
