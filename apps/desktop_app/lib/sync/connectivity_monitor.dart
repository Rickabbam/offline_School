import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

/// Watches network connectivity and exposes a stream of online/offline state.
class ConnectivityMonitor {
  final _logger = Logger();
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(initial);

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final online = _hasConnection(results);
        if (online != _isOnline) {
          _isOnline = online;
          _logger.i('Connectivity changed: ${_isOnline ? "online" : "offline"}');
          _controller.add(_isOnline);
        }
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
