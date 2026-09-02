import 'package:flutter/widgets.dart';

import 'ws_client.dart';

/// 监听 App 前后台切换，回到前台时检查并重连 WS。
class WsLifecycle with WidgetsBindingObserver {
  WsLifecycle._();

  static final WsLifecycle instance = WsLifecycle._();

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WsClient.instance.onAppResumed();
    }
  }
}
