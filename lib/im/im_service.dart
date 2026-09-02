import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:im_demo/config/im_config.dart';
import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/core/ws/ws_client.dart';
import 'package:im_demo/core/ws/ws_lifecycle.dart';
import 'package:im_demo/core/ws/ws_status.dart';
import 'package:im_demo/im/im_api.dart';
import 'package:im_demo/im/models/im_message.dart';

/// IM 业务单例，HTTP 登录 + WebSocket 通信。
class ImService extends ChangeNotifier {
  ImService._();

  static final ImService instance = ImService._();

  final List<ImMessage> _messages = [];
  StreamSubscription<String>? _messageSub;
  StreamSubscription<WsStatus>? _statusSub;
  StreamSubscription<bool>? _networkSub;

  String? _userId;
  String? _token;
  String? _wsUrl;
  bool _networkOnline = true;

  List<ImMessage> get messages => List.unmodifiable(_messages);

  String? get userId => _userId;

  String? get token => _token;

  String? get wsUrl => _wsUrl;

  WsStatus get status => WsClient.instance.status;

  bool get isConnected => WsClient.instance.isConnected;

  bool get networkOnline => _networkOnline;

  /// 在 [main] 中调用一次。
  void init() {
    ImConfig.bindTokenProvider(() async => _token);
    HttpClient.instance.init(ImConfig.httpConfig);
    WsLifecycle.instance.start();
  }

  /// 有密码：先 HTTP 登录拿 token，再连 WS；无密码：直接连 WS。
  Future<void> loginAndConnect({
    required String username,
    required String wsUrl,
    String? password,
  }) {
    if (password != null && password.isNotEmpty) {
      return _loginThenConnect(
        username: username,
        password: password,
        fallbackWsUrl: wsUrl,
      );
    }
    return connect(url: wsUrl, userId: username);
  }

  Future<void> _loginThenConnect({
    required String username,
    required String password,
    required String fallbackWsUrl,
  }) {
    final completer = Completer<void>();

    ImApi.instance.login(
      username: username,
      password: password,
      onSuccess: ({required token, wsUrl}) async {
        _token = token;
        _userId = username;
        try {
          await connect(
            url: _buildWsUrl(wsUrl ?? fallbackWsUrl),
            userId: username,
          );
          completer.complete();
        } catch (e, s) {
          completer.completeError(e, s);
        }
      },
      onFail: (message, {statusCode, raw}) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(message));
        }
      },
    );

    return completer.future;
  }

  Future<void> connect({
    required String url,
    required String userId,
  }) async {
    _wsUrl = _buildWsUrl(url);
    _userId = userId;

    await _bindWs();
    await WsClient.instance.connect(_wsUrl!, config: ImConfig.wsConfig);
    notifyListeners();
  }

  Future<void> disconnect() async {
    _token = null;
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

  String _buildWsUrl(String url) {
    if (_token == null || _token!.isEmpty) return url;
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'token': _token!,
          },
        )
        .toString();
  }

  Future<void> _bindWs() async {
    await _messageSub?.cancel();
    await _statusSub?.cancel();
    await _networkSub?.cancel();

    _networkOnline = WsClient.instance.networkOnline;

    _messageSub = WsClient.instance.messageStream.listen(handleRawMessage);
    _statusSub = WsClient.instance.statusStream.listen((status) {
      if (status == WsStatus.connected && _userId != null) {
        sendJoin();
      }
      notifyListeners();
    });
    _networkSub = WsClient.instance.networkOnlineStream.listen((online) {
      _networkOnline = online;
      notifyListeners();
    });
  }

  void sendJoin() {
    if (_userId == null) return;
    WsClient.instance.sendJson({
      'type': 'join',
      'username': _userId,
      'from': _userId,
      if (_token != null) 'token': _token,
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
    _networkSub?.cancel();
    super.dispose();
  }
}
