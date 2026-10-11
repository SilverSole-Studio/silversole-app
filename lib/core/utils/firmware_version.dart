import 'package:pub_semver/pub_semver.dart';

enum FirmwareComparison { upgrade, downgrade, same }

/// A firmware version as the sole reports it and the manifest writes it
/// (`0.4.0`, `0.4.0-rc.1`), or null when it is not semver.
Version? parseFirmwareVersion(String? raw) {
  if (raw == null) return null;
  try {
    return Version.parse(raw.trim());
  } on FormatException {
    return null;
  }
}

/// How [server] relates to the version on the [device], by semver rules —
/// `0.4.0-rc.1 < 0.4.0`, `0.10.0 > 0.9.0` — or null when either side is not
/// semver.
FirmwareComparison? compareFirmware(String? device, String? server) {
  final d = parseFirmwareVersion(device);
  final s = parseFirmwareVersion(server);
  if (d == null || s == null) return null;
  final c = s.compareTo(d);
  if (c > 0) return FirmwareComparison.upgrade;
  if (c < 0) return FirmwareComparison.downgrade;
  return FirmwareComparison.same;
}
