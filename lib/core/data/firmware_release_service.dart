import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The public Supabase Storage bucket the firmware is published to (the
/// handoff's §2.1). It is public on purpose and must not get a SELECT policy
/// on storage.objects: the app only fetches known paths, and such a policy
/// would let anyone list the bucket.
const firmwareBucket = 'firmware';

/// The only manifest format this app understands.
const firmwareManifestSchema = 1;

enum FirmwareChannel { stable, beta }

String firmwareManifestPath(FirmwareChannel channel) =>
    'channels/${channel.name}/manifest.json';

/// An image ready to send: its bytes, its signature and their checks done.
@immutable
class FirmwareImage {
  const FirmwareImage({
    required this.bin,
    required this.signature,
    required this.sha256,
    this.version,
    this.notes = '',
  });

  final Uint8List bin;
  final Uint8List signature;

  /// SHA-256 of [bin], the 32 bytes START carries.
  final Uint8List sha256;

  /// The version it installs; null for a developer's own file, which comes
  /// without a manifest.
  final String? version;
  final String notes;
}

/// What is wrong with an image, or null when it may go to the sole (the
/// handoff's §2.3). Without a [manifest] — a developer's own file — only the
/// checks that need none are made.
String? validateImage({
  FirmwareManifest? manifest,
  required List<int> bin,
  required List<int> signature,
}) {
  if (bin.isEmpty || bin.length > dfuMaxImageSize) {
    return 'size ${bin.length} is outside 1..$dfuMaxImageSize';
  }
  if (manifest != null) {
    if (bin.length != manifest.size) {
      return 'size ${bin.length} != manifest ${manifest.size}';
    }
    final digest = sha256.convert(bin).toString();
    if (digest != manifest.sha256.toLowerCase()) {
      return 'sha256 $digest != manifest ${manifest.sha256}';
    }
  }
  if (signature.length != dfuSignatureLength) {
    return 'signature is ${signature.length} bytes, not $dfuSignatureLength';
  }
  return null;
}

/// Reads the firmware server: a channel's manifest, then the image and its
/// signature by the paths it names.
class FirmwareReleaseService {
  FirmwareReleaseService({Dio? dio, String Function(String path)? publicUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
            ),
          ),
      _publicUrl =
          publicUrl ??
          ((path) => Supabase.instance.client.storage
              .from(firmwareBucket)
              .getPublicUrl(path));

  final Dio _dio;
  final String Function(String path) _publicUrl;

  Future<Result<FirmwareManifest>> fetchManifest(
    FirmwareChannel channel,
  ) async {
    try {
      final res = await _dio.get<String>(
        _publicUrl(firmwareManifestPath(channel)),
        options: Options(responseType: ResponseType.plain),
      );
      final json = jsonDecode(res.data ?? '') as Map<String, dynamic>;
      return Result.ok(FirmwareManifest.fromJson(json));
    } catch (e) {
      // Network trouble, a missing manifest, or one that does not parse: in
      // every case there is nothing to offer.
      return Result.error(DfuException(DfuFailure.manifestUnavailable, '$e'));
    }
  }

  Future<Result<FirmwareImage>> download(FirmwareManifest manifest) async {
    final Uint8List bin;
    final Uint8List signature;
    try {
      bin = await _bytes(manifest.binPath);
      signature = await _bytes(manifest.sigPath);
    } catch (e) {
      return Result.error(DfuException(DfuFailure.downloadFailed, '$e'));
    }
    final problem = validateImage(
      manifest: manifest,
      bin: bin,
      signature: signature,
    );
    if (problem != null) {
      return Result.error(DfuException(DfuFailure.imageInvalid, problem));
    }
    return Result.ok(
      FirmwareImage(
        bin: bin,
        signature: signature,
        sha256: Uint8List.fromList(sha256.convert(bin).bytes),
        version: manifest.version,
        notes: manifest.notes,
      ),
    );
  }

  /// A developer's own image (debug builds only), checked as far as possible
  /// without a manifest.
  Result<FirmwareImage> localImage(Uint8List bin, Uint8List signature) {
    final problem = validateImage(bin: bin, signature: signature);
    if (problem != null) {
      return Result.error(DfuException(DfuFailure.imageInvalid, problem));
    }
    return Result.ok(
      FirmwareImage(
        bin: bin,
        signature: signature,
        sha256: Uint8List.fromList(sha256.convert(bin).bytes),
      ),
    );
  }

  Future<Uint8List> _bytes(String path) async {
    final res = await _dio.get<List<int>>(
      _publicUrl(path),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}
