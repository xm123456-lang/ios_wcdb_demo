import 'package:flutter_test/flutter_test.dart';
import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/core/http/http_config.dart';

void main() {
  test('HttpClient reports error when not initialized', () async {
    String? message;

    HttpClient.instance.get(
      '/test',
      onFail: (msg, {statusCode, raw}) => message = msg,
    );

    await Future<void>.delayed(Duration.zero);
    expect(message, 'HttpClient 未初始化，请先调用 init()');
  });

  test('HttpConfig accepts async tokenProvider', () {
    const config = HttpConfig(
      baseUrl: 'https://example.com',
      tokenProvider: _readToken,
    );
    expect(config.tokenProvider, isNotNull);
  });
}

Future<String?> _readToken() async => 'token';
