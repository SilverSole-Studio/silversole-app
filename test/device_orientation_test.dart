import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/device_orientation.dart';

void main() {
  test('phones stay portrait, tablets rotate freely', () {
    expect(defaultOrientationsFor(tablet: false), [
      DeviceOrientation.portraitUp,
    ]);
    expect(
      defaultOrientationsFor(tablet: true),
      containsAll([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  });

  testWidgets('a tablet display is told apart by its physical size', (
    tester,
  ) async {
    final view = tester.view;
    addTearDown(view.reset);
    addTearDown(view.display.reset);
    // The display is what counts, not the (possibly tiny) window.
    view.physicalSize = const Size(600, 800);
    view.display
      ..size = const Size(2732, 2048)
      ..devicePixelRatio = 2; // 1366x1024 logical
    expect(isTabletDisplay(view), isTrue);
    view.display
      ..size = const Size(1170, 2532)
      ..devicePixelRatio = 3; // 390x844 logical
    expect(isTabletDisplay(view), isFalse);
  });
}
