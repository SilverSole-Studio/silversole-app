import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/game_path.dart';

void main() {
  final opened = Uri.parse(
    'https://h5.silversole.dongyu.company/game/laojie/lantern/?theme=xinbei&from=world',
  );
  bool stays(String next) => staysOnGamePath(opened, Uri.parse(next));

  test('the same path stays, whatever the query or fragment', () {
    expect(
      stays('https://h5.silversole.dongyu.company/game/laojie/lantern/'),
      isTrue,
    );
    expect(
      stays(
        'https://h5.silversole.dongyu.company/game/laojie/lantern/?theme=xinbei&from=world&r=2',
      ),
      isTrue,
    );
    expect(
      stays('https://h5.silversole.dongyu.company/game/laojie/lantern/#win'),
      isTrue,
    );
  });

  test(
    'a trailing slash, the case of the host and the default port do not matter',
    () {
      expect(
        stays('https://h5.silversole.dongyu.company/game/laojie/lantern'),
        isTrue,
      );
      expect(
        stays('https://H5.SilverSole.dongyu.company/game/laojie/lantern/'),
        isTrue,
      );
      expect(
        stays('https://h5.silversole.dongyu.company:443/game/laojie/lantern/'),
        isTrue,
      );
    },
  );

  test('another path leaves: the town, another stage, the site root', () {
    for (final next in [
      'https://h5.silversole.dongyu.company/game/world/',
      'https://h5.silversole.dongyu.company/game/laojie/goldfish/?theme=taipei',
      'https://h5.silversole.dongyu.company/game/laojie/',
      'https://h5.silversole.dongyu.company/game/laojie/lantern/extra/',
      'https://h5.silversole.dongyu.company/',
    ]) {
      expect(stays(next), isFalse, reason: next);
    }
  });

  test('another host, scheme or port leaves', () {
    for (final next in [
      'https://evil.example/game/laojie/lantern/',
      'http://h5.silversole.dongyu.company/game/laojie/lantern/',
      'https://h5.silversole.dongyu.company:8443/game/laojie/lantern/',
    ]) {
      expect(stays(next), isFalse, reason: next);
    }
  });

  test('with nothing to compare there is nothing to stop', () {
    expect(staysOnGamePath(null, Uri.parse('https://x.example/')), isTrue);
    expect(staysOnGamePath(opened, null), isTrue);
  });

  test('a game at the site root is compared as "/"', () {
    final root = Uri.parse('https://h5.silversole.dongyu.company');
    expect(
      staysOnGamePath(root, Uri.parse('https://h5.silversole.dongyu.company/')),
      isTrue,
    );
    expect(
      staysOnGamePath(
        root,
        Uri.parse('https://h5.silversole.dongyu.company/game/world/'),
      ),
      isFalse,
    );
  });
}
