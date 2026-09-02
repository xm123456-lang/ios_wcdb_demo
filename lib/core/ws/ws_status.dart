enum WsStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  /// 无网络，等待网络恢复后自动重连。
  waitingNetwork,
}
