import 'package:dio/dio.dart';

import 'http_config.dart';

typedef HttpSuccess<T> = void Function(T data);
typedef HttpFail = void Function(String message, {int? statusCode, dynamic raw});

/// 基于 Dio 的 HTTP 单例，通过回调处理成功/失败。
///
/// ```dart
/// HttpClient.instance.init(HttpConfig(baseUrl: 'https://api.example.com'));
///
/// HttpClient.instance.get<Map<String, dynamic>>(
///   '/user/info',
///   parser: (json) => Map<String, dynamic>.from(json as Map),
///   onSuccess: (data) => print(data),
///   onFail: (msg, {statusCode, raw}) => print(msg),
/// );
/// ```
class HttpClient {
  HttpClient._();

  static final HttpClient instance = HttpClient._();

  Dio? _dio;
  HttpConfig? _config;

  void init(HttpConfig config) {
    _config = config;
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: Map<String, String>.from(config.headers),
      ),
    );
  }

  void get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? parser,
    HttpSuccess<T>? onSuccess,
    HttpFail? onFail,
  }) {
    _request<T>(
      path: path,
      method: 'GET',
      query: query,
      headers: headers,
      parser: parser,
      onSuccess: onSuccess,
      onFail: onFail,
    );
  }

  void post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? parser,
    HttpSuccess<T>? onSuccess,
    HttpFail? onFail,
  }) {
    _request<T>(
      path: path,
      method: 'POST',
      data: data,
      query: query,
      headers: headers,
      parser: parser,
      onSuccess: onSuccess,
      onFail: onFail,
    );
  }

  void put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? parser,
    HttpSuccess<T>? onSuccess,
    HttpFail? onFail,
  }) {
    _request<T>(
      path: path,
      method: 'PUT',
      data: data,
      query: query,
      headers: headers,
      parser: parser,
      onSuccess: onSuccess,
      onFail: onFail,
    );
  }

  void delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? parser,
    HttpSuccess<T>? onSuccess,
    HttpFail? onFail,
  }) {
    _request<T>(
      path: path,
      method: 'DELETE',
      data: data,
      query: query,
      headers: headers,
      parser: parser,
      onSuccess: onSuccess,
      onFail: onFail,
    );
  }

  Future<void> _request<T>({
    required String path,
    required String method,
    dynamic data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(dynamic json)? parser,
    HttpSuccess<T>? onSuccess,
    HttpFail? onFail,
  }) async {
    final dio = _dio;
    if (dio == null || _config == null) {
      onFail?.call('HttpClient 未初始化，请先调用 init()', statusCode: null, raw: null);
      return;
    }

    final mergedHeaders = <String, dynamic>{
      ...dio.options.headers,
      ...?headers,
    };

    final token = await _config!.tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      mergedHeaders['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, headers: mergedHeaders),
      );

      final body = response.data;
      if (onSuccess == null) return;

      if (parser != null) {
        onSuccess(parser(body));
      } else {
        onSuccess(body as T);
      }
    } on DioException catch (e) {
      onFail?.call(
        _resolveErrorMessage(e),
        statusCode: e.response?.statusCode,
        raw: e.response?.data,
      );
    } catch (e) {
      onFail?.call(e.toString(), statusCode: null, raw: e);
    }
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
