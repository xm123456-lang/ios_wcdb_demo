import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/network_monitor.dart';
import 'ws_config.dart';
import 'ws_status.dart';

/// WebSocket 单例，支持心跳保活、网络抖动感知与自动重连。
///
/// ```dart
/// await WsClient.instance.connect('wss://your-server/ws');
/// WsClient.instance.messageStream.listen((msg) { ... });
/// WsClient.instance.send('hello');
/// ```
class WsClient {
  WsClient._();

  static final WsClient instance = WsClient._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<bool>? _networkSub;

  final _messageController = StreamController<String>.broadcast();
  final _statusController = StreamController<WsStatus>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();
  final _networkController = StreamController<bool>.broadcast();

  WsStatus _status = WsStatus.disconnected;
  WsConfig _config = WsConfig.defaults;

  String? _url;
  Iterable<String>? _protocols;

  bool _manualDisconnect = false;
  bool _networkOnline = true;
  int _reconnectAttempt = 0;

  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  bool _waitingHeartbeatResponse = false;

  Stream<String> get messageStream => _messageController.stream;

  Stream<WsStatus> get statusStream => _statusController.stream;

  /// 网络是否可用（防抖后）。
  Stream<bool> get networkOnlineStream => _networkController.stream;

  bool get networkOnline => _networkOnline;

  /// 重连成功时触发（不含首次连接）。
  Stream<void> get reconnectedStream => _reconnectedController.stream;

  WsStatus get status => _status;

  bool get isConnected => _status == WsStatus.connected;

  String? get url => _url;

  int get reconnectAttempt => _reconnectAttempt;

  WsConfig get config => _config;

  Future<void> connect(
    String url, {
    Iterable<String>? protocols,
    WsConfig? config,
  }) async {
    _manualDisconnect = false;
    _reconnectAttempt = 0;
    _config = config ?? WsConfig.defaults;
    _url = url;
    _protocols = protocols;

    _cancelReconnectTimer();
    _startNetworkMonitor();
    await _openConnection(isReconnect: false);
  }

  void send(String data) {
    _ensureConnected();
    _channel!.sink.add(data);
  }

  void sendJson(Map<String, dynamic> data) {
    send(jsonEncode(data));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _cancelReconnectTimer();
    _stopHeartbeat();
    _stopNetworkMonitor();
    await _closeChannel();
    _url = null;
    _protocols = null;
    _reconnectAttempt = 0;
    _setStatus(WsStatus.disconnected);
  }

  /// App 回到前台时调用，断线则重连，已连接则立即发心跳检测。
  void onAppResumed() {
    if (_manualDisconnect || _url == null) return;

    if (!isConnected) {
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      unawaited(_openConnection(isReconnect: true));
      return;
    }

    _sendHeartbeat();
  }

  Future<void> _openConnection({required bool isReconnect}) async {
    final url = _url;
    if (url == null || _manualDisconnect) return;

    if (_config.enableNetworkMonitor && !_networkOnline) {
      _setStatus(WsStatus.waitingNetwork);
      return;
    }

    _setStatus(isReconnect ? WsStatus.reconnecting : WsStatus.connecting);
    _stopHeartbeat();
    await _closeChannel();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: _protocols,
      );
      await _channel!.ready;

      _reconnectAttempt = 0;
      _waitingHeartbeatResponse = false;
      _setStatus(WsStatus.connected);
      _startHeartbeat();

      if (isReconnect) {
        _reconnectedController.add(null);
      }

      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e, s) {
      if (_manualDisconnect) return;

      if (!isReconnect && !_config.enableReconnect) {
        _setStatus(WsStatus.disconnected);
        Error.throwWithStackTrace(e, s);
      }

      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    final text = _decodeData(data);
    if (text == null) return;

    _waitingHeartbeatResponse = false;
    _heartbeatTimeoutTimer?.cancel();

    if (_config.isHeartbeatResponse(text)) return;

    _messageController.add(text);
  }

  void _onError(Object error, StackTrace stackTrace) {
    _messageController.addError(error, stackTrace);
    _handleConnectionLost();
  }

  void _onDone() {
    _handleConnectionLost();
  }

  void _handleConnectionLost() {
    if (_manualDisconnect) {
      _setStatus(WsStatus.disconnected);
      return;
    }

    _stopHeartbeat();
    unawaited(_closeChannel());

    if (_config.enableReconnect && _url != null) {
      _scheduleReconnect();
    } else {
      _setStatus(WsStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || !_config.enableReconnect || _url == null) return;

    final maxAttempts = _config.maxReconnectAttempts;
    if (maxAttempts >= 0 && _reconnectAttempt >= maxAttempts) {
      _setStatus(WsStatus.disconnected);
      return;
    }

    if (_config.enableNetworkMonitor && !_networkOnline) {
      _cancelReconnectTimer();
      _setStatus(WsStatus.waitingNetwork);
      return;
    }

    _cancelReconnectTimer();
    _setStatus(WsStatus.reconnecting);

    final delay = _nextReconnectDelay();
    _reconnectTimer = Timer(delay, () {
      if (_manualDisconnect || _url == null) return;
      _reconnectAttempt++;
      unawaited(_openConnection(isReconnect: true));
    });
  }

  void _onNetworkChanged(bool online) {
    _networkOnline = online;
    if (!_networkController.isClosed) {
      _networkController.add(online);
    }

    if (_manualDisconnect || _url == null) return;

    if (!online) {
      _cancelReconnectTimer();
      _stopHeartbeat();
      unawaited(_closeChannel());
      _setStatus(WsStatus.waitingNetwork);
      return;
    }

    // 网络恢复：重置退避，立即尝试重连。
    if (!isConnected) {
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      unawaited(_openConnection(isReconnect: true));
    }
  }

  void _startNetworkMonitor() {
    if (!_config.enableNetworkMonitor) return;

    final monitor = NetworkMonitor.instance;
    unawaited(
      monitor.start(debounce: _config.networkDebounce).then((_) {
        _networkOnline = monitor.isOnline;
        if (!_networkController.isClosed) {
          _networkController.add(_networkOnline);
        }
      }),
    );

    _networkSub?.cancel();
    _networkSub = monitor.onlineStream.listen(_onNetworkChanged);
  }

  void _stopNetworkMonitor() {
    _networkSub?.cancel();
    _networkSub = null;
    NetworkMonitor.instance.stop();
  }

  Duration _nextReconnectDelay() {
    final initialMs = _config.initialReconnectDelay.inMilliseconds;
    final maxMs = _config.maxReconnectDelay.inMilliseconds;
    final multiplier = 1 << _reconnectAttempt.clamp(0, 10);
    final delayMs = (initialMs * multiplier).clamp(initialMs, maxMs);
    return Duration(milliseconds: delayMs);
  }

  void _startHeartbeat() {
    if (!_config.enableHeartbeat) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _config.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  void _sendHeartbeat() {
    if (!isConnected || _channel == null) return;

    try {
      _channel!.sink.add(_config.heartbeatPayload);
      _waitingHeartbeatResponse = true;

      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = Timer(_config.heartbeatTimeout, () {
        if (_waitingHeartbeatResponse) {
          _waitingHeartbeatResponse = false;
          _handleConnectionLost();
        }
      });
    } catch (_) {
      _handleConnectionLost();
    }
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _waitingHeartbeatResponse = false;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    if (channel != null) {
      await channel.sink.close();
    }
  }

  String? _decodeData(dynamic data) {
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    return null;
  }

  void _ensureConnected() {
    if (!isConnected) {
      throw StateError('WebSocket not connected');
    }
  }

  void _setStatus(WsStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
