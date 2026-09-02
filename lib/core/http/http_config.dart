/// 每次请求前异步获取 Token（如 SecureStorage、刷新 token）。
typedef TokenProvider = Future<String?> Function();

/// HTTP 全局配置。
class HttpConfig {
  const HttpConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.headers = const {},
    this.tokenProvider,
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Map<String, String> headers;

  /// 动态 Token，每次请求前 await 调用。
  ///
  /// ```dart
  /// tokenProvider: () async {
  ///   return await SecureStorage.read('token');
  /// },
  /// ```
  final TokenProvider? tokenProvider;
}
