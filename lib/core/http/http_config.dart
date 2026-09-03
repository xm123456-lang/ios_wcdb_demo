/// HTTP 全局配置。
class HttpConfig {
  const HttpConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
}
