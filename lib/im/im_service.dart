import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:im_demo/core/ws/ws_client.dart';
import 'package:im_demo/core/ws/ws_status.dart';
import 'package:im_demo/im/models/im_message.dart';

/// IM 业务单例，基于 [WsClient] 封装连接、收发消息。
class ImService extends ChangeNotifier {
  ImService._();

  static final ImService instance = ImService._();

  final List<ImMessage> _messages = [];
  StreamSubscription<String>? _messageSub;
  StreamSubscription<WsStatus>? _statusSub;

  String? _userId;
  String? _wsUrl;

  List<ImMessage> get messages => List.unmodifiable(_messages);

  String? get userId => _userId;

  String? get wsUrl => _wsUrl;

  WsStatus get status => WsClient.instance.status;

  bool get isConnected => WsClient.instance.isConnected;

  /// 连接 IM，成功后发送 join 包（可按你的协议调整）。
  Future<void> connect({
    required String url,
    required String userId,
  }) async {
    _wsUrl = url;
    _userId = userId;

    await _bindWs();
    await WsClient.instance.connect(url);

    notifyListeners();
  }

  Future<void> disconnect() async {
    await WsClient.instance.disconnect();
    notifyListeners();
  }

  void sendMessage(String text, {String? to}) {
    final content = text.trim();
    if (content.isEmpty || _userId == null) return;

    final message = ImMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      text: content,
      senderId: _userId!,
      receiverId: to,
      timestamp: DateTime.now(),
      isSelf: true,
    );

    WsClient.instance.sendJson(message.toJson());
    _appendMessage(message);
  }

  /// 收到原始 ws 文本后的解析入口，可按你的协议改写。
  void handleRawMessage(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;

      final type = json['type'] as String? ?? 'message';
      switch (type) {
        case 'pong':
          return;
        case 'message':
        case 'chat':
          _appendMessage(ImMessage.fromJson(json, selfId: _userId));
        case 'system':
          _appendMessage(
            ImMessage(
              id: '${DateTime.now().millisecondsSinceEpoch}',
              text: json['message'] as String? ?? json['text'] as String? ?? '',
              senderId: 'system',
              timestamp: DateTime.now(),
              isSelf: false,
              isSystem: true,
            ),
          );
      }
    } catch (_) {
      _appendMessage(
        ImMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          text: raw,
          senderId: 'unknown',
          timestamp: DateTime.now(),
          isSelf: false,
        ),
      );
    }
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  Future<void> _bindWs() async {
    await _messageSub?.cancel();
    await _statusSub?.cancel();

    _messageSub = WsClient.instance.messageStream.listen(handleRawMessage);
    _statusSub = WsClient.instance.statusStream.listen((status) {
      if (status == WsStatus.connected && _userId != null) {
        sendJoin();
      }
      notifyListeners();
    });
  }

  void sendJoin() {
    if (_userId == null) return;
    WsClient.instance.sendJson({
      'type': 'join',
      'username': _userId,
      'from': _userId,
    });
  }

  void _appendMessage(ImMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
