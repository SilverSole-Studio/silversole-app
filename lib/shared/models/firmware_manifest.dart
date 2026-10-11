import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_manifest.freezed.dart';
part 'firmware_manifest.g.dart';

/// One channel's current release (the firmware handoff's §2.2).
@freezed
abstract class FirmwareManifest with _$FirmwareManifest {
  const factory FirmwareManifest({
    /// Format version; anything but `firmwareManifestSchema` is not understood.
    required int schema,
    required String channel,
    required String version,
    required int size,

    /// SHA-256 of `fw.bin`, lowercase hex.
    required String sha256,
    @JsonKey(name: 'bin_path') required String binPath,
    @JsonKey(name: 'sig_path') required String sigPath,
    @Default('') String notes,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
  }) = _FirmwareManifest;

  factory FirmwareManifest.fromJson(Map<String, dynamic> json) =>
      _$FirmwareManifestFromJson(json);
}
