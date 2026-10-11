import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/error/result.dart';

/// Sends one firmware image into the sole (the firmware handoff's §4).
///
/// Flow control is one flash page at a time: send `[committed, committed +
/// 4096)`, then wait for the sole to report `committed` moving on. A packet
/// lost in the air shows up as BAD_OFFSET — or, when it was the last of its
/// page, as nothing at all, which is why every page wait has a timeout. Either
/// way the page is sent again from `committed`.
class DfuTransfer {
  DfuTransfer(
    this._link, {
    this.statusTimeout = const Duration(seconds: 2),
    this.applyTimeout = const Duration(seconds: 30),
    this.resendDelay = const Duration(milliseconds: 100),
    this.batteryRetryDelay = const Duration(seconds: 10),
    this.batteryRetries = 3,
    this.maxResends = 10,
    this.packetGap = const Duration(milliseconds: 10),
  });

  final DfuLink _link;
  final Duration statusTimeout;

  /// Checking a 416 KiB image takes the sole several seconds.
  final Duration applyTimeout;

  /// Lets packets already on their way drain before a page is resent.
  final Duration resendDelay;
  final Duration batteryRetryDelay;
  final int batteryRetries;
  final int maxResends;

  /// Pause between data packets, so the phone's BLE buffer does not overflow
  /// and drop them. Tune on hardware.
  final Duration packetGap;

  _StatusQueue? _queue;
  Completer<void>? _sleeper;
  var _cancelled = false;
  var _applySent = false;

  /// Whether APPLY went out. From then on the sole may install the image even
  /// if its answer is lost, and only the version it boots with can tell.
  bool get applySent => _applySent;

  Future<Result<void>> run({
    required List<int> image,
    required List<int> sha256,
    required List<int> signature,
    void Function(int committed, int size)? onProgress,
  }) async {
    if (!_link.isConnected) {
      return const Result.error(DfuException(DfuFailure.notConnected));
    }
    if (_link.mtu < dfuMinMtu) {
      return Result.error(
        DfuException(DfuFailure.mtuTooSmall, 'mtu ${_link.mtu}'),
      );
    }
    final queue = _StatusQueue(await _link.subscribeStatus());
    _queue = queue;
    try {
      var restarted = false;
      while (true) {
        try {
          await _start(queue, image.length, sha256);
          await _sendImage(queue, image, dfuPayloadSize(_link.mtu), onProgress);
          await _apply(queue, signature);
          return const Result.ok(null);
        } on DfuException catch (e) {
          // The image went bad on the way or in flash: worth one clean resend
          // from START (the handoff's §3.5), not more.
          final resend =
              e.failure == DfuFailure.hashMismatch ||
              e.failure == DfuFailure.flashError;
          if (!resend || restarted || _cancelled) return Result.error(e);
          debugPrint('dfu: ${e.failure.name}, sending the image again');
          restarted = true;
          _applySent = false;
        }
      }
    } finally {
      _queue = null;
      // Fire-and-forget: a broadcast StreamSubscription.cancel() Future can
      // outlive the Zone it was created in (observed under fake_async, which
      // never resolves it), and nothing downstream needs to wait on it.
      unawaited(queue.close());
    }
  }

  /// Stops the transfer: the sole is told to ABORT, and [run] ends with
  /// [DfuFailure.cancelled]. Safe at any point — the sole keeps its firmware.
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _queue?.interrupt();
    final sleeper = _sleeper;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
    try {
      await _link.writeControl(dfuAbortCommand);
    } catch (e) {
      debugPrint('dfu: ABORT failed: $e');
    }
  }

  Future<void> _start(_StatusQueue queue, int size, List<int> sha256) async {
    for (var attempt = 0; ; attempt++) {
      final status = await _command(
        queue,
        dfuStartCommand(size, sha256),
        statusTimeout,
      );
      if (status.result == DfuResult.batteryUnknown &&
          attempt < batteryRetries) {
        // Just booted (e.g. right after an update): its first battery reading
        // takes about 10 s.
        await _sleep(batteryRetryDelay);
        continue;
      }
      if (status.state == DfuState.receiving && status.result == DfuResult.ok) {
        return;
      }
      throw _failureOf(status);
    }
  }

  Future<void> _sendImage(
    _StatusQueue queue,
    List<int> image,
    int payload,
    void Function(int committed, int size)? onProgress,
  ) async {
    final size = image.length;
    var committed = 0;
    var resends = 0;
    onProgress?.call(0, size);
    while (committed < size) {
      _check();
      final pageEnd = math.min(committed + dfuPageSize, size);
      var lost = false;
      for (var offset = committed; offset < pageEnd; offset += payload) {
        final end = math.min(offset + payload, pageEnd);
        try {
          await _link.writeData(
            dfuDataPacket(offset, image.sublist(offset, end)),
          );
        } catch (e) {
          if (!_link.isConnected) {
            throw const DfuException(DfuFailure.disconnected);
          }
          // A full BLE buffer (Android 13+ reports
          // ERROR_GATT_WRITE_REQUEST_BUSY): the packet never left, so the page
          // is resent like any other loss.
          debugPrint('dfu: data write at $offset failed: $e');
          lost = true;
          break;
        }
        if (packetGap > Duration.zero) await _sleep(packetGap);
        _check();
      }

      final status = lost ? null : await queue.next(statusTimeout);
      _check();
      if (status != null &&
          status.result == DfuResult.ok &&
          status.committed > committed) {
        committed = status.committed;
        resends = 0;
        onProgress?.call(committed, size);
        continue;
      }
      if (status != null &&
          status.result != DfuResult.ok &&
          status.result != DfuResult.badOffset) {
        throw _failureOf(status);
      }
      if (status == null && !_link.isConnected) {
        throw const DfuException(DfuFailure.disconnected);
      }

      // A lost packet: BAD_OFFSET, silence (the page's last packet went
      // missing) or a failed write. The sole now only takes `committed`,
      // which BAD_OFFSET carries — it may be ahead of ours when a STATUS was
      // missed.
      if (status != null && status.committed > committed) {
        committed = status.committed;
        onProgress?.call(committed, size);
      }
      resends++;
      if (resends > maxResends) {
        throw DfuException(DfuFailure.tooManyRetries, 'page at $committed');
      }
      debugPrint(
        'dfu: resending from $committed '
        '(${status?.result.name ?? 'no status'}, #$resends)',
      );
      await _sleep(resendDelay);
      _check();
      queue.clear();
    }
  }

  Future<void> _apply(_StatusQueue queue, List<int> signature) async {
    _check();
    queue.clear();
    await _writeControl(dfuApplyCommand(signature));
    _applySent = true;
    // Verifying can keep the sole from answering for seconds — even the
    // VERIFYING status may come late — so both waits are long.
    var status = await _next(queue, applyTimeout);
    if (status.state == DfuState.verifying && status.result == DfuResult.ok) {
      status = await _next(queue, applyTimeout);
    }
    if (status.state == DfuState.applied && status.result == DfuResult.ok) {
      return;
    }
    throw _failureOf(status);
  }

  Future<DfuStatus> _command(
    _StatusQueue queue,
    List<int> bytes,
    Duration timeout,
  ) async {
    _check();
    queue.clear();
    await _writeControl(bytes);
    return _next(queue, timeout);
  }

  Future<void> _writeControl(List<int> bytes) async {
    try {
      await _link.writeControl(bytes);
    } catch (e) {
      throw _linkFailure(e);
    }
  }

  Future<DfuStatus> _next(_StatusQueue queue, Duration timeout) async {
    final status = await queue.next(timeout);
    _check();
    if (status == null) {
      throw _linkFailure('no status within ${timeout.inSeconds} s');
    }
    return status;
  }

  DfuException _linkFailure(Object cause) => _link.isConnected
      ? DfuException(DfuFailure.timeout, '$cause')
      : const DfuException(DfuFailure.disconnected);

  void _check() {
    if (_cancelled) throw const DfuException(DfuFailure.cancelled);
  }

  /// A delay that [cancel] cuts short.
  Future<void> _sleep(Duration duration) {
    final sleeper = Completer<void>();
    _sleeper = sleeper;
    final timer = Timer(duration, () {
      if (!sleeper.isCompleted) sleeper.complete();
    });
    return sleeper.future.whenComplete(() {
      timer.cancel();
      if (identical(_sleeper, sleeper)) _sleeper = null;
    });
  }

  static DfuException _failureOf(DfuStatus status) =>
      DfuException(switch (status.result) {
        DfuResult.badCommand => DfuFailure.badCommand,
        DfuResult.badState => DfuFailure.badState,
        DfuResult.unsupportedVersion => DfuFailure.unsupportedVersion,
        DfuResult.tooLarge => DfuFailure.tooLarge,
        DfuResult.lowBattery => DfuFailure.lowBattery,
        DfuResult.batteryUnknown => DfuFailure.batteryUnknown,
        DfuResult.hashMismatch => DfuFailure.hashMismatch,
        DfuResult.flashError => DfuFailure.flashError,
        DfuResult.badSignature => DfuFailure.badSignature,
        // OK in the wrong state, or BAD_OFFSET outside a page: the sole is not
        // where the protocol says it should be.
        DfuResult.ok || DfuResult.badOffset => DfuFailure.badState,
      }, '$status');
}

/// STATUS notifications in arrival order, so one that lands while a page is
/// still being sent is not lost before the transfer starts waiting for it.
class _StatusQueue {
  _StatusQueue(Stream<List<int>> raw) {
    _sub = raw.listen((bytes) {
      final status = DfuStatus.parse(bytes);
      if (status == null) return;
      final waiter = _waiter;
      if (waiter != null && !waiter.isCompleted) {
        _waiter = null;
        waiter.complete(status);
      } else {
        _buffer.add(status);
      }
    });
  }

  late final StreamSubscription<List<int>> _sub;
  final _buffer = <DfuStatus>[];
  Completer<DfuStatus?>? _waiter;

  /// The next status, or null when none arrives within [timeout].
  Future<DfuStatus?> next(Duration timeout) {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final waiter = Completer<DfuStatus?>();
    _waiter = waiter;
    final timer = Timer(timeout, () => _resolve(waiter));
    return waiter.future.whenComplete(timer.cancel);
  }

  /// Ends the current wait at once, with no status.
  void interrupt() {
    final waiter = _waiter;
    if (waiter != null) _resolve(waiter);
  }

  void _resolve(Completer<DfuStatus?> waiter) {
    if (identical(_waiter, waiter)) _waiter = null;
    if (!waiter.isCompleted) waiter.complete(null);
  }

  /// Drops statuses that arrived but are no longer the answer awaited.
  void clear() => _buffer.clear();

  Future<void> close() => _sub.cancel();
}
