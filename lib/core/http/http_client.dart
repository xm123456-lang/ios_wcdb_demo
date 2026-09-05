import 'dart:convert';

import 'package:dio/dio.dart';

import 'http_config.dart';
import 'http_result.dart';

void prettyPrint(dynamic obj) {
  final encoder = JsonEncoder.withIndent("  ");
  print(encoder.convert(obj));
}

/// 基于 Dio 的 HTTP 单例，方法返回 [HttpResult]。
///
/// ```dart
/// HttpClient.instance.init(HttpConfig(baseUrl: 'https://api.example.com'));
/// HttpClient.instance.setToken('xxx');
///
/// final result = await HttpClient.instance.get<Map<String, dynamic>>(
///   '/user/info',
///   parser: (json) => Map<String, dynamic>.from(json as Map),
/// );
/// if (result.success) {
///   print(result.data);
/// }
/// ```
class HttpClient {
  HttpClient._();

  static final HttpClient instance = HttpClient._();

  static const Map<String, String> _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Client-type': '5',
    'App-version': '1.0.3',
    'App-channel': 'official',
    'Lang': 'en',
    'timezone': 'UTC+8',
    'Siteid': '1',
  };

  Dio? _dio;
  HttpConfig? _config;
  String? _token;

  void init(HttpConfig config) {
    _config = config;
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: Map<String, String>.from(_defaultHeaders),
      ),
    );
  }

  /// 手动设置 Token，后续请求自动带 `Authorization: Bearer <token>`。
  void setToken(String? token) {
    _token = token;
  }

  void clearToken() => setToken(null);

  String? get token => _token;

  Future<HttpResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(path: path, method: 'GET', query: query, parser: parser);
  }

  Future<HttpResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(
      path: path,
      method: 'POST',
      data: data,
      query: query,
      parser: parser,
    );
  }

  Future<HttpResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(
      path: path,
      method: 'PUT',
      data: data,
      query: query,
      parser: parser,
    );
  }

  Future<HttpResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) {
    return _request<T>(
      path: path,
      method: 'DELETE',
      data: data,
      query: query,
      parser: parser,
    );
  }

  Future<HttpResult<T>> _request<T>({
    required String path,
    required String method,
    dynamic data,
    Map<String, dynamic>? query,
    T Function(dynamic json)? parser,
  }) async {
    final dio = _dio;
    if (dio == null || _config == null) {
      return HttpResult.fail('HttpClient 未初始化，请先调用 init()');
    }

    final headers = <String, dynamic>{
      ..._defaultHeaders,
      ...dio.options.headers,
      'Referer': _buildReferer(path),
    };

    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );

      final body = response.data;
      final parsed = parser != null ? parser(body) : body as T;
      return HttpResult.ok(parsed, statusCode: response.statusCode, raw: body);
    } on DioException catch (e) {
      return HttpResult.fail(
        _resolveErrorMessage(e),
        statusCode: e.response?.statusCode,
        raw: e.response?.data,
      );
    } catch (e) {
      return HttpResult.fail(e.toString(), raw: e);
    }
  }

  String _buildReferer(String path) {
    final base = _config!.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  String _resolveErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['msg'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message ?? '网络请求失败';
  }
}
