import 'package:flutter_test/flutter_test.dart';
import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/core/http/http_config.dart';

void main() {
  test('HttpClient returns fail when not initialized', () async {
    final result = await HttpClient.instance.get('/test');
    expect(result.success, isFalse);
    expect(result.message, 'HttpClient 未初始化，请先调用 init()');
  });

  test('HttpClient setToken stores token', () {
    HttpClient.instance.init(const HttpConfig(baseUrl: 'https://example.com'));
    HttpClient.instance.setToken('abc');
    expect(HttpClient.instance.token, 'abc');
    HttpClient.instance.clearToken();
    expect(HttpClient.instance.token, isNull);
  });
}
