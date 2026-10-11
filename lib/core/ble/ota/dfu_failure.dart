/// Why a firmware update stopped. Every one of them leaves the sole on its
/// old firmware, still working — the firmware guarantees that.
enum DfuFailure {
  notConnected,
  disconnected,
  timeout,
  tooManyRetries,
  cancelled,
  dfuUnsupported,
  unsupportedVersion,
  mtuTooSmall,
  lowBattery,
  batteryUnknown,
  badState,
  hashMismatch,
  flashError,
  badSignature,
  tooLarge,
  badCommand,
  manifestUnavailable,
  downloadFailed,
  imageInvalid;

  /// False where trying again cannot help: the image, its signature or the
  /// sole's firmware itself is the problem (the handoff's §3.5).
  bool get retryable => switch (this) {
    badSignature ||
    tooLarge ||
    badCommand ||
    unsupportedVersion ||
    dfuUnsupported ||
    imageInvalid => false,
    _ => true,
  };

  /// The strings.csv key of its message, e.g. `ota_fail_too_many_retries`.
  String get messageKey =>
      'ota_fail_${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}';
}

class DfuException implements Exception {
  const DfuException(this.failure, [this.detail]);

  final DfuFailure failure;

  /// What happened, for the log — never shown to the user.
  final String? detail;

  @override
  String toString() => detail == null
      ? 'DfuException(${failure.name})'
      : 'DfuException(${failure.name}: $detail)';
}
