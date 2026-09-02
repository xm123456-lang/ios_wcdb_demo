import 'dart:convert';

/// WebSocket 连接配置：心跳保活 + 自动重连。
class WsConfig {
  const WsConfig({
    this.enableHeartbeat = true,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatTimeout = const Duration(seconds: 10),
    this.heartbeatPayload = '{"type":"ping"}',
    this.heartbeatResponseType = 'pong',
    this.enableReconnect = true,
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = -1,
    this.enableNetworkMonitor = true,
    this.networkDebounce = const Duration(milliseconds: 800),
  });
  
     /// 是否启用心跳。
  final bool enableHeartbeat;

  /// 心跳发送间隔。
  final Duration heartbeatInterval;

  /// 发出心跳后，多久内未收到任何数据则判定断线。
  final Duration heartbeatTimeout;

  /// 心跳包内容，默认 JSON ping。
  final String heartbeatPayload;

  /// 心跳响应 type 字段值，收到后不会透传到 [WsClient.messageStream]。
  final String heartbeatResponseType;

  /// 是否启用自动重连。
  final bool enableReconnect;

  /// 首次重连等待时间。
  final Duration initialReconnectDelay;

  /// 重连等待上限（指数退避）。
  final Duration maxReconnectDelay;

  /// 最大重连次数，-1 表示无限重连。
  final int maxReconnectAttempts;

  /// 是否监听系统网络变化。
  final bool enableNetworkMonitor;

  /// 恢复有网时的防抖时长；彻底断网会立即响应。
  final Duration networkDebounce;

  static const defaults = WsConfig();

  bool isHeartbeatResponse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map && json['type'] == heartbeatResponseType) {
        return true;
      }
    } catch (_) {}
    return raw == heartbeatResponseType;
  }
}
