/// HTTP 请求结果封装。
class HttpResult<T> {
  const HttpResult._({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.raw,
  });

  factory HttpResult.ok(
    T data, {
    int? statusCode,
    dynamic raw,
  }) {
    return HttpResult._(
      success: true,
      data: data,
      statusCode: statusCode,
      raw: raw,
    );
  }

  factory HttpResult.fail(
    String message, {
    int? statusCode,
    dynamic raw,
  }) {
    return HttpResult._(
      success: false,
      message: message,
      statusCode: statusCode,
      raw: raw,
    );
  }

  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  final dynamic raw;

  bool get isFail => !success;
}
