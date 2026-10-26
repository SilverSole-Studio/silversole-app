import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/play_in_app_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.dongyutech.silversole/in_app_update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?>? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('maps the flow name Play started', () async {
    for (final (wire, flow) in [
      ('immediate', InAppUpdateFlow.immediate),
      ('flexible', InAppUpdateFlow.flexible),
      ('none', InAppUpdateFlow.none),
    ]) {
      answer((_) async => wire);
      expect(await PlayInAppUpdate.checkForUpdate(), flow);
    }
  });

  test('a channel error means no update, not a crash', () async {
    answer((_) async => throw PlatformException(code: 'IN_APP_UPDATE'));
    expect(await PlayInAppUpdate.checkForUpdate(), InAppUpdateFlow.none);
    expect(await PlayInAppUpdate.isInstalledFromPlay(), isFalse);
  });

  test('reports the installer the native side saw', () async {
    answer((call) async => call.method == 'isInstalledFromPlay');
    expect(await PlayInAppUpdate.isInstalledFromPlay(), isTrue);
  });

  test('off Android it never touches the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var called = false;
    answer((_) async {
      called = true;
      return 'immediate';
    });
    expect(await PlayInAppUpdate.isInstalledFromPlay(), isFalse);
    expect(await PlayInAppUpdate.checkForUpdate(), InAppUpdateFlow.none);
    expect(called, isFalse);
  });

  test('only a sideloaded Android copy gets the GitHub APK prompt', () {
    expect(
      updateRoute(TargetPlatform.android, installedFromPlay: true),
      UpdateRoute.play,
    );
    expect(
      updateRoute(TargetPlatform.android, installedFromPlay: false),
      UpdateRoute.github,
    );
    // TestFlight and the App Store update iOS themselves; an APK link is wrong there.
    expect(
      updateRoute(TargetPlatform.iOS, installedFromPlay: false),
      UpdateRoute.none,
    );
    expect(
      updateRoute(TargetPlatform.macOS, installedFromPlay: false),
      UpdateRoute.none,
    );
  });
}
