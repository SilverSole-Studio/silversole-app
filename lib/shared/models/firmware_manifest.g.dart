// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firmware_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FirmwareManifest _$FirmwareManifestFromJson(Map<String, dynamic> json) =>
    _FirmwareManifest(
      schema: (json['schema'] as num).toInt(),
      channel: json['channel'] as String,
      version: json['version'] as String,
      size: (json['size'] as num).toInt(),
      sha256: json['sha256'] as String,
      binPath: json['bin_path'] as String,
      sigPath: json['sig_path'] as String,
      notes: json['notes'] as String? ?? '',
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
    );

Map<String, dynamic> _$FirmwareManifestToJson(_FirmwareManifest instance) =>
    <String, dynamic>{
      'schema': instance.schema,
      'channel': instance.channel,
      'version': instance.version,
      'size': instance.size,
      'sha256': instance.sha256,
      'bin_path': instance.binPath,
      'sig_path': instance.sigPath,
      'notes': instance.notes,
      'published_at': instance.publishedAt?.toIso8601String(),
    };
