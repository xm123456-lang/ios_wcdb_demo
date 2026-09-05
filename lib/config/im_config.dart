import '../core/http/http_config.dart';

/// IM / HTTP 相关配置。
class ImConfig {
  ImConfig._();

  static const String baseUrl = 'https://dev-api.baseversion.xyz';

  static const String loginPath = '/app/v1/users/login';

  static const HttpConfig httpConfig = HttpConfig(baseUrl: baseUrl);
}
