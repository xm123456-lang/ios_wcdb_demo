import 'package:im_demo/config/im_config.dart';
import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/core/http/http_result.dart';

class LoginResult {
  const LoginResult({required this.token, this.wsUrl});

  final String token;
  final String? wsUrl;
}

/// IM 相关 HTTP 接口，基于 [HttpClient] Future 封装。
class ImApi {
  ImApi._();

  static final ImApi instance = ImApi._();

  /// 登录，成功返回 token 和可选 ws 地址。
  Future<HttpResult<LoginResult>> login({
    required String username,
    required String password,
  }) async {
    final result = await HttpClient.instance.post<Map<String, dynamic>>(
      ImConfig.loginPath,
      data: {
        'username': username,
        'password': password,
      },
      parser: (json) => Map<String, dynamic>.from(json as Map),
    );

    if (result.isFail || result.data == null) {
      return HttpResult.fail(
        result.message ?? '登录失败',
        statusCode: result.statusCode,
        raw: result.raw,
      );
    }

    final data = result.data!;
    final token = data['token'] as String? ?? data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      return HttpResult.fail('登录失败：未返回 token', raw: data);
    }

    return HttpResult.ok(
      LoginResult(
        token: token,
        wsUrl: data['wsUrl'] as String? ?? data['ws_url'] as String?,
      ),
      statusCode: result.statusCode,
      raw: result.raw,
    );
  }
}
