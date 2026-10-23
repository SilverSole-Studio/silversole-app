import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';

const _site = 'https://h5.silversole.dongyu.company/';

PermissionRequest _req(String origin, List<PermissionResourceType> resources) =>
    PermissionRequest(origin: WebUri(origin), resources: resources);

void main() {
  group('answerGamePermission', () {
    late int asked;
    Future<bool> Function() ask(bool granted) => () async {
      asked++;
      return granted;
    };

    setUp(() => asked = 0);

    Future<PermissionResponseAction?> answer(
      PermissionRequest request, {
      bool granted = true,
      String base = _site,
    }) async => (await answerGamePermission(
      request,
      gameBase: base,
      askCamera: ask(granted),
    )).action;

    test(
      'grants the camera to the game site once the wearer allows it',
      () async {
        final request = _req('https://h5.silversole.dongyu.company/', [
          PermissionResourceType.CAMERA,
        ]);
        expect(await answer(request), PermissionResponseAction.GRANT);
        expect(asked, 1);
      },
    );

    test('origin without a trailing slash still matches', () async {
      final request = _req('https://h5.silversole.dongyu.company', [
        PermissionResourceType.CAMERA,
      ]);
      expect(await answer(request), PermissionResponseAction.GRANT);
    });

    test('denies the page when the wearer turns the camera down', () async {
      final request = _req(_site, [PermissionResourceType.CAMERA]);
      expect(
        await answer(request, granted: false),
        PermissionResponseAction.DENY,
      );
      expect(asked, 1);
    });

    test('denies the microphone without asking', () async {
      final request = _req(_site, [PermissionResourceType.MICROPHONE]);
      expect(await answer(request), PermissionResponseAction.DENY);
      expect(asked, 0);
    });

    test('denies camera plus microphone without asking', () async {
      for (final resources in [
        [PermissionResourceType.CAMERA, PermissionResourceType.MICROPHONE],
        [PermissionResourceType.CAMERA_AND_MICROPHONE],
      ]) {
        expect(
          await answer(_req(_site, resources)),
          PermissionResponseAction.DENY,
        );
      }
      expect(asked, 0);
    });

    test('denies an empty request without asking', () async {
      expect(await answer(_req(_site, [])), PermissionResponseAction.DENY);
      expect(asked, 0);
    });

    test('denies other pages without asking', () async {
      for (final origin in [
        'https://evil.example.com/',
        'https://h5.silversole.dongyu.company.evil.com/',
        'http://h5.silversole.dongyu.company/',
        'https://h5.silversole.dongyu.company:8443/',
      ]) {
        expect(
          await answer(_req(origin, [PermissionResourceType.CAMERA])),
          PermissionResponseAction.DENY,
          reason: origin,
        );
      }
      expect(asked, 0);
    });

    test('follows a GAME_URL override, port included', () async {
      const local = 'http://localhost:8080/';
      expect(
        await answer(
          _req('http://localhost:8080/', [PermissionResourceType.CAMERA]),
          base: local,
        ),
        PermissionResponseAction.GRANT,
      );
      expect(
        await answer(
          _req('http://localhost:7456/', [PermissionResourceType.CAMERA]),
          base: local,
        ),
        PermissionResponseAction.DENY,
      );
    });
  });
}
