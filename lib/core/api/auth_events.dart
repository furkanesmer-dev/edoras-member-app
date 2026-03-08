import 'dart:async';

class AuthEvents {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _controller.stream;

  void emitUnauthorized() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}