import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';

final fallEventBusProvider = Provider<FallEventBus>((ref) {
  final bus = FallEventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

class FallEventBus {
  final _controller = StreamController<FallDetectEvent>.broadcast();

  Stream<FallDetectEvent> get stream => _controller.stream;

  void emit(FallDetectEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

final fallEventStreamProvider = StreamProvider<FallDetectEvent>((ref) {
  return ref.watch(fallEventBusProvider).stream;
});