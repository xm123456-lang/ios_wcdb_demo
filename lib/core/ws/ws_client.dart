import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/network_monitor.dart';
import 'ws_config.dart';
import 'ws_status.dart';

// ========== 全局日志开关，发布改为 false 即可关闭全部日志 ==========
bool wsDebugLog = true;

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
    if (wsDebugLog) print('[WS] connect() called, url:$url');
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
    if (wsDebugLog) print('[WS] send raw: $data');
    _ensureConnected();
    _channel!.sink.add(data);
  }

  void sendJson(Map<String, dynamic> data) {
    final payload = jsonEncode(data);
    if (wsDebugLog) print('[WS] send json: $payload');
    send(payload);
  }

  Future<void> disconnect() async {
    if (wsDebugLog) print('[WS] manual disconnect start');
    _manualDisconnect = true;
    _cancelReconnectTimer();
    _stopHeartbeat();
    _stopNetworkMonitor();
    await _closeChannel();
    _url = null;
    _protocols = null;
    _reconnectAttempt = 0;
    _setStatus(WsStatus.disconnected);
    if (wsDebugLog) print('[WS] manual disconnect finished');
  }

  /// App 回到前台时调用，断线则重连，已连接则立即发心跳检测。
  void onAppResumed() {
    if (wsDebugLog) print('[WS] onAppResumed');
    if (_manualDisconnect || _url == null) {
      if (wsDebugLog)
        print('[WS] onAppResumed skip, manualDisconnect or url null');
      return;
    }

    if (!isConnected) {
      if (wsDebugLog) print('[WS] onAppResumed not connected, try reconnect');
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      unawaited(_openConnection(isReconnect: true));
      return;
    }

    if (wsDebugLog) print('[WS] onAppResumed connected, send heartbeat');
    _sendHeartbeat();
  }

  Future<void> _openConnection({required bool isReconnect}) async {
    final url = _url;
    if (url == null || _manualDisconnect) {
      if (wsDebugLog)
        print('[WS] _openConnection skip url null or manualDisconnect');
      return;
    }

    if (_config.enableNetworkMonitor && !_networkOnline) {
      if (wsDebugLog)
        print('[WS] _openConnection no network, switch to waitingNetwork');
      _setStatus(WsStatus.waitingNetwork);
      return;
    }

    if (wsDebugLog)
      print('[WS] _openConnection start, isReconnect:$isReconnect, url:$url');
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
      if (wsDebugLog) print('[WS] ✅ WebSocket connected success');
      _startHeartbeat();

      if (isReconnect) {
        if (wsDebugLog) print('[WS] ✅ Re‑connected, fire reconnectedStream');
        _reconnectedController.add(null);
      }

      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e, s) {
      if (wsDebugLog) print('[WS] ❌ connect exception $e\n$s');
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
    if (text == null) {
      if (wsDebugLog)
        print('[WS] _onData decode null, raw data type:${data.runtimeType}');
      return;
    }

    _waitingHeartbeatResponse = false;
    _heartbeatTimeoutTimer?.cancel();

    if (_config.isHeartbeatResponse(text)) {
      if (wsDebugLog) print('[WS] ← heartbeat response received');
      return;
    }

    if (wsDebugLog) print('[WS] ← receive message: $text');
    _messageController.add(text);
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (wsDebugLog) print('[WS] ❌ stream onError: $error\n$stackTrace');
    _messageController.addError(error, stackTrace);
    _handleConnectionLost();
  }

  void _onDone() {
    if (wsDebugLog) print('[WS] stream onDone, server closed connection');
    _handleConnectionLost();
  }

  void _handleConnectionLost() {
    if (wsDebugLog) print('[WS] _handleConnectionLost');
    if (_manualDisconnect) {
      if (wsDebugLog)
        print('[WS] _handleConnectionLost skip: manual disconnect');
      _setStatus(WsStatus.disconnected);
      return;
    }

    _stopHeartbeat();
    unawaited(_closeChannel());

    if (_config.enableReconnect && _url != null) {
      if (wsDebugLog) print('[WS] connection lost, schedule reconnect');
      _scheduleReconnect();
    } else {
      if (wsDebugLog) print('[WS] connection lost, no‑reconnect, disconnected');
      _setStatus(WsStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || !_config.enableReconnect || _url == null) {
      if (wsDebugLog) print('[WS] _scheduleReconnect skip');
      return;
    }

    final maxAttempts = _config.maxReconnectAttempts;
    if (maxAttempts >= 0 && _reconnectAttempt >= maxAttempts) {
      if (wsDebugLog)
        print(
          '[WS] max reconnect attempts reached $_reconnectAttempt / $maxAttempts, stop',
        );
      _setStatus(WsStatus.disconnected);
      return;
    }

    if (_config.enableNetworkMonitor && !_networkOnline) {
      _cancelReconnectTimer();
      if (wsDebugLog) print('[WS] no network, switch waitingNetwork');
      _setStatus(WsStatus.waitingNetwork);
      return;
    }

    _cancelReconnectTimer();
    _setStatus(WsStatus.reconnecting);

    final delay = _nextReconnectDelay();
    if (wsDebugLog)
      print(
        '[WS] schedule reconnect after ${delay.inMilliseconds}ms, current attempt:$_reconnectAttempt',
      );
    _reconnectTimer = Timer(delay, () {
      if (_manualDisconnect || _url == null) {
        if (wsDebugLog) print('[WS] reconnect timer fired but cancelled');
        return;
      }
      _reconnectAttempt++;
      if (wsDebugLog) print('[WS] start reconnect attempt #$_reconnectAttempt');
      unawaited(_openConnection(isReconnect: true));
    });
  }

  void _onNetworkChanged(bool online) {
    if (wsDebugLog) print('[WS] network changed online:$online');
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
      if (wsDebugLog) print('[WS] network offline, close ws and wait');
      return;
    }

    // 网络恢复：重置退避，立即尝试重连。
    if (!isConnected) {
      if (wsDebugLog) print('[WS] network back online, trigger reconnect');
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      unawaited(_openConnection(isReconnect: true));
    }
  }

  void _startNetworkMonitor() {
    if (!_config.enableNetworkMonitor) {
      if (wsDebugLog) print('[WS] network monitor disabled by config');
      return;
    }

    final monitor = NetworkMonitor.instance;
    unawaited(
      monitor.start(debounce: _config.networkDebounce).then((_) {
        _networkOnline = monitor.isOnline;
        if (wsDebugLog)
          print('[WS] network monitor started, initial online:$_networkOnline');
        if (!_networkController.isClosed) {
          _networkController.add(_networkOnline);
        }
      }),
    );

    _networkSub?.cancel();
    _networkSub = monitor.onlineStream.listen(_onNetworkChanged);
  }

  void _stopNetworkMonitor() {
    if (wsDebugLog) print('[WS] stop network monitor');
    _networkSub?.cancel();
    _networkSub = null;
    NetworkMonitor.instance.stop();
  }

  Duration _nextReconnectDelay() {
    final initialMs = _config.initialReconnectDelay.inMilliseconds;
    final maxMs = _config.maxReconnectDelay.inMilliseconds;
    final multiplier = 1 << _reconnectAttempt.clamp(0, 10);
    final delayMs = (initialMs * multiplier).clamp(initialMs, maxMs);
    final dur = Duration(milliseconds: delayMs);
    if (wsDebugLog)
      print(
        '[WS] calc reconnect delay attempt $_reconnectAttempt → ${dur.inMilliseconds}ms',
      );
    return dur;
  }

  void _startHeartbeat() {
    if (!_config.enableHeartbeat) {
      if (wsDebugLog) print('[WS] heartbeat disabled');
      return;
    }
    if (wsDebugLog)
      print(
        '[WS] start heartbeat periodic timer, interval:${_config.heartbeatInterval}',
      );
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _config.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  void _sendHeartbeat() {
    if (!isConnected || _channel == null) {
      if (wsDebugLog) print('[WS] skip send heartbeat: not connected');
      return;
    }

    try {
      if (wsDebugLog)
        print('[WS] → send heartbeat payload:${_config.heartbeatPayload}');
      _channel!.sink.add(_config.heartbeatPayload);
      _waitingHeartbeatResponse = true;

      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = Timer(_config.heartbeatTimeout, () {
        if (_waitingHeartbeatResponse) {
          if (wsDebugLog) print('[WS] ❌ heartbeat timeout, no pong received');
          _waitingHeartbeatResponse = false;
          _handleConnectionLost();
        }
      });
    } catch (_) {
      if (wsDebugLog) print('[WS] send heartbeat failed with exception');
      _handleConnectionLost();
    }
  }

  void _stopHeartbeat() {
    if (wsDebugLog) print('[WS] stop heartbeat timers');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _waitingHeartbeatResponse = false;
  }

  void _cancelReconnectTimer() {
    if (wsDebugLog) print('[WS] cancel reconnect timer');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _closeChannel() async {
    if (wsDebugLog) print('[WS] _closeChannel');
    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    if (channel != null) {
      await channel.sink.close();
      if (wsDebugLog) print('[WS] channel sink closed');
    }
  }

  String? _decodeData(dynamic data) {
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    return null;
  }

  void _ensureConnected() {
    if (!isConnected) {
      if (wsDebugLog) print('[WS] send failed: WebSocket not connected');
      throw StateError('WebSocket not connected');
    }
  }

  void _setStatus(WsStatus status) {
    if (_status == status) return;
    if (wsDebugLog) print('[WS] status change: $_status → $status');
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
