import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';

final _bin = List<int>.generate(1000, (i) => i & 0xFF);
final _sig = List<int>.filled(64, 7);

FirmwareManifest _manifest({int? size, String? sha}) => FirmwareManifest(
  schema: 1,
  channel: 'stable',
  version: '0.4.0',
  size: size ?? _bin.length,
  sha256: sha ?? sha256.convert(_bin).toString(),
  binPath: 'releases/0.4.0/fw.bin',
  sigPath: 'releases/0.4.0/fw.bin.sig',
);

void main() {
  test('parses the manifest the handoff specifies', () {
    final m = FirmwareManifest.fromJson({
      'schema': 1,
      'channel': 'stable',
      'version': '0.4.0',
      'size': 69236,
      'sha256':
          '03828d993ac25c06342183424f8c58c8819c75d9fefef7fd79a93f7806d46138',
      'bin_path': 'releases/0.4.0/fw.bin',
      'sig_path': 'releases/0.4.0/fw.bin.sig',
      'notes': '修正 xxx',
      'published_at': '2026-10-10T12:00:00Z',
    });
    expect(m.binPath, 'releases/0.4.0/fw.bin');
    expect(m.sigPath, 'releases/0.4.0/fw.bin.sig');
    expect(m.size, 69236);
    expect(m.publishedAt, DateTime.utc(2026, 10, 10, 12));
  });

  test('notes may be missing or null', () {
    final m = FirmwareManifest.fromJson({
      'schema': 1,
      'channel': 'beta',
      'version': '0.4.0-rc.1',
      'size': 1,
      'sha256': '00',
      'bin_path': 'b',
      'sig_path': 's',
      'notes': null,
    });
    expect(m.notes, '');
  });

  test('each channel has its own manifest', () {
    expect(
      firmwareManifestPath(FirmwareChannel.stable),
      'channels/stable/manifest.json',
    );
    expect(
      firmwareManifestPath(FirmwareChannel.beta),
      'channels/beta/manifest.json',
    );
  });

  group('validateImage', () {
    test('a matching image passes', () {
      expect(
        validateImage(manifest: _manifest(), bin: _bin, signature: _sig),
        isNull,
      );
    });

    test('an uppercase digest in the manifest still matches', () {
      final upper = sha256.convert(_bin).toString().toUpperCase();
      expect(
        validateImage(
          manifest: _manifest(sha: upper),
          bin: _bin,
          signature: _sig,
        ),
        isNull,
      );
    });

    test('rejects an empty or oversized image', () {
      expect(
        validateImage(
          manifest: _manifest(size: 0),
          bin: const [],
          signature: _sig,
        ),
        isNotNull,
      );
      final huge = List<int>.filled(425985, 0);
      expect(validateImage(bin: huge, signature: _sig), isNotNull);
    });

    test('rejects a size that differs from the manifest', () {
      expect(
        validateImage(
          manifest: _manifest(size: 999),
          bin: _bin,
          signature: _sig,
        ),
        contains('size'),
      );
    });

    test('rejects a digest that differs from the manifest', () {
      expect(
        validateImage(
          manifest: _manifest(sha: 'ab' * 32),
          bin: _bin,
          signature: _sig,
        ),
        contains('sha256'),
      );
    });

    test('rejects a signature that is not 64 bytes', () {
      expect(
        validateImage(
          manifest: _manifest(),
          bin: _bin,
          signature: List.filled(63, 0),
        ),
        contains('signature'),
      );
    });

    test(
      'a local image without a manifest is checked for size and signature only',
      () {
        expect(validateImage(bin: _bin, signature: _sig), isNull);
        expect(validateImage(bin: _bin, signature: const [1]), isNotNull);
      },
    );
  });
}
