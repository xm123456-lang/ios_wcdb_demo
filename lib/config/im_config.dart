import '../core/http/http_config.dart';

/// IM / HTTP 相关配置。
class ImConfig {
  ImConfig._();

  static const String baseUrl = 'https://api.example.com';

  static const String loginPath = '/auth/login';

  static const HttpConfig httpConfig = HttpConfig(baseUrl: baseUrl);
}
