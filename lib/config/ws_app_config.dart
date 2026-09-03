import '../core/ws/ws_config.dart';

/// WebSocket 相关配置，与 [ImConfig] 分离。
class WsAppConfig {
  WsAppConfig._();

  static const String wsUrl = 'wss://your-server/ws';

  /// 心跳、重连、网络防抖等连接参数。
  static const WsConfig config = WsConfig(
    heartbeatInterval: Duration(seconds: 30),
    heartbeatTimeout: Duration(seconds: 10),
    networkDebounce: Duration(milliseconds: 800),
    enableReconnect: true,
    enableNetworkMonitor: true,
  );
}
