import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'network_utils.dart';

/// 网络状态单例。
///
/// - **断网**（none）：立即通知，快速停 WS
/// - **恢复有网**：防抖后再通知，避免抖动导致频繁重连
class NetworkMonitor {
  NetworkMonitor._();

  static final NetworkMonitor instance = NetworkMonitor._();

  final Connectivity _connectivity = Connectivity();

  final _onlineController = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  bool _isOnline = true;
  bool _pendingOnline = true;
  Duration _debounceDuration = const Duration(milliseconds: 800);

  Stream<bool> get onlineStream => _onlineController.stream;

  bool get isOnline => _isOnline;

  bool get isListening => _subscription != null;

  /// [debounce] 仅用于「恢复有网」时的防抖。
  Future<void> start({Duration debounce = const Duration(milliseconds: 800)}) async {
    _debounceDuration = debounce;
    if (_subscription != null) return;

    final initial = await _connectivity.checkConnectivity();
    _setOnline(networkIsOnline(initial), notify: false);

    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void stop() {
    if (_subscription == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> checkOnline() async {
    final results = await _connectivity.checkConnectivity();
    return networkIsOnline(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    _pendingOnline = networkIsOnline(results);

    _debounceTimer?.cancel();

    // 断网立即响应（飞行模式、拔卡等）
    if (!_pendingOnline) {
      if (_isOnline) {
        _setOnline(false);
      }
      return;
    }

    // 恢复有网：防抖，等网络稳定后再重连
    _debounceTimer = Timer(_debounceDuration, () {
      if (_pendingOnline && !_isOnline) {
        _setOnline(true);
      }
    });
  }

  void _setOnline(bool online, {bool notify = true}) {
    _isOnline = online;
    _pendingOnline = online;
    if (notify && !_onlineController.isClosed) {
      _onlineController.add(online);
    }
  }
}
