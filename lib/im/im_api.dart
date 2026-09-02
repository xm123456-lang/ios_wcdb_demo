import 'package:im_demo/config/im_config.dart';
import 'package:im_demo/core/http/http_client.dart';

typedef LoginSuccess = void Function({
  required String token,
  String? wsUrl,
});

/// IM 相关 HTTP 接口，基于 [HttpClient] 回调封装。
class ImApi {
  ImApi._();

  static final ImApi instance = ImApi._();

  /// 登录，成功后回调 token 和可选 ws 地址。
  void login({
    required String username,
    required String password,
    required LoginSuccess onSuccess,
    HttpFail? onFail,
  }) {
    HttpClient.instance.post<Map<String, dynamic>>(
      ImConfig.loginPath,
      data: {
        'username': username,
        'password': password,
      },
      parser: (json) => Map<String, dynamic>.from(json as Map),
      onSuccess: (data) {
        final token = data['token'] as String? ?? data['accessToken'] as String?;
        if (token == null || token.isEmpty) {
          onFail?.call('登录失败：未返回 token', raw: data);
          return;
        }
        onSuccess(
          token: token,
          wsUrl: data['wsUrl'] as String? ?? data['ws_url'] as String?,
        );
      },
      onFail: onFail,
    );
  }
}
