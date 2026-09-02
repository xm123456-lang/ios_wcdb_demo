import '../core/http/http_config.dart';
import '../core/ws/ws_config.dart';

/// IM 全局配置，修改 API / WebSocket 地址。
class ImConfig {
  ImConfig._();

  static const String baseUrl = 'https://api.example.com';

  static const String loginPath = '/auth/login';

  static const String wsUrl = 'wss://your-server/ws';

  static HttpConfig get httpConfig => HttpConfig(
        baseUrl: baseUrl,
        tokenProvider: _tokenProvider,
      );

  /// 由 [ImService] 注入，供 HttpClient 自动带 Token。
  static TokenProvider? _tokenProvider;

  static void bindTokenProvider(TokenProvider provider) {
    _tokenProvider = provider;
  }

  /// WebSocket 连接参数（心跳、重连、网络防抖等）。
  static const wsConfig = WsConfig(
    heartbeatInterval: Duration(seconds: 30),
    heartbeatTimeout: Duration(seconds: 10),
    networkDebounce: Duration(milliseconds: 800),
    enableReconnect: true,
    enableNetworkMonitor: true,
  );
}
