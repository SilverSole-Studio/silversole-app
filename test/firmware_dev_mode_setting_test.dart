import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('developer mode survives a restart and can be switched off', () async {
    SharedPreferences.setMockInitialValues({'firmware_dev_mode': 'true'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(settingsProvider);
    await _settle();
    expect(container.read(settingsProvider).firmwareDevMode, isTrue);

    await container.read(settingsProvider.notifier).setFirmwareDevMode(false);
    expect(container.read(settingsProvider).firmwareDevMode, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('firmware_dev_mode'), 'false');
  });
}
