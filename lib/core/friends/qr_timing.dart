// Timing rules for the two QR screens, kept free of widgets and clocks so
// they can be tested with plain durations. The pages feed them a Stopwatch's
// elapsed time, never the device clock: a phone whose clock is off must not
// show a dead QR or renew it every tick.

/// Decides which detections on the scan screen are acted on.
///
/// Once a code has been handled — a sheet shown and closed, an error shown,
/// 「先不要」 tapped — the same code is ignored until it has been out of frame
/// for [absence], and in any case for [cooldown] after it was handled. A QR
/// left in view therefore does not pop the same sheet again, and an org
/// poster on the wall does not spend a lookup on every frame.
class ScanDebouncer {
  ScanDebouncer({
    this.absence = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 5),
  });

  final Duration absence;
  final Duration cooldown;

  String? _raw;
  Duration? _lastSeen;
  Duration? _settledAt;

  /// Whether [raw], seen at [now], should be handled. Every sighting of the
  /// code being held back counts as "still in frame".
  bool accept(String raw, Duration now) {
    if (raw == _raw) {
      final lastSeen = _lastSeen;
      final settledAt = _settledAt;
      final stillInView = lastSeen != null && now - lastSeen < absence;
      final coolingDown = settledAt != null && now - settledAt < cooldown;
      _lastSeen = now;
      if (stillInView || coolingDown) return false;
    }
    _raw = raw;
    _lastSeen = now;
    _settledAt = null;
    return true;
  }

  /// The code last accepted has been dealt with at [now]. The scanner is
  /// usually paused while it is handled, so this also counts as the moment it
  /// was last seen.
  void settle(Duration now) {
    if (_raw == null) return;
    _lastSeen = now;
    _settledAt = now;
  }
}

/// When "my QR" asks the server for a fresh token.
///
/// A token is renewed once it is half its [ttl] old, so the QR on screen
/// always has at least half its life left. A failed request is retried after
/// [retryDelays] (the last one repeats); the page shows the error and a retry
/// button meanwhile rather than a spinner.
class QrTokenRenewal {
  QrTokenRenewal({
    required this.ttl,
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
  });

  final Duration ttl;
  final List<Duration> retryDelays;

  /// The server's clock started a little before ours did (the request took
  /// time), so the token is treated as expired this much early.
  static const _expiryMargin = Duration(seconds: 10);

  Duration? _issuedAt;
  Duration? _failedAt;
  int _failures = 0;

  /// Failed attempts since the last token came back.
  int get failures => _failures;

  /// Whether a new token should be requested at [now].
  bool shouldRenew(Duration now) {
    final failedAt = _failedAt;
    if (failedAt != null) {
      final delay =
          retryDelays[(_failures - 1).clamp(0, retryDelays.length - 1)];
      return now - failedAt >= delay;
    }
    final issuedAt = _issuedAt;
    return issuedAt == null || now - issuedAt >= ttl ~/ 2;
  }

  /// Whether the token on hand (if any) can no longer be shown at [now].
  bool isExpired(Duration now) {
    final issuedAt = _issuedAt;
    return issuedAt == null || now - issuedAt >= ttl - _expiryMargin;
  }

  /// A token arrived at [now].
  void issued(Duration now) {
    _issuedAt = now;
    _failedAt = null;
    _failures = 0;
  }

  /// A request for a token failed at [now].
  void failed(Duration now) {
    _failedAt = now;
    _failures++;
  }
}
