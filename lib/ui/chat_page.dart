import 'package:flutter/material.dart';
import 'package:im_demo/core/ws/ws_status.dart';
import 'package:im_demo/im/im_service.dart';
import 'package:im_demo/im/models/im_message.dart';
import 'package:im_demo/ui/login_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _im = ImService.instance;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _im.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _im.removeListener(_scrollToBottom);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;

    _im.sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _logout() async {
    await _im.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _im,
      builder: (context, _) {
        final messages = _im.messages;

        return Scaffold(
          appBar: AppBar(
            title: Text(_im.userId ?? '聊天'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: _StatusBadge(status: _im.status)),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                tooltip: '断开',
              ),
            ],
          ),
          body: Column(
            children: [
              if (_im.status != WsStatus.connected)
                _ConnectionBanner(
                  status: _im.status,
                  networkOnline: _im.networkOnline,
                ),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('暂无消息'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(message: messages[index]);
                        },
                      ),
              ),
              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: const InputDecoration(
                            hintText: '输入消息...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _im.isConnected ? _send : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.status,
    required this.networkOnline,
  });

  final WsStatus status;
  final bool networkOnline;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      WsStatus.waitingNetwork => ('网络不可用，等待恢复...', Colors.red.shade700),
      WsStatus.reconnecting => ('连接断开，正在重连...', Colors.orange.shade800),
      WsStatus.connecting => ('正在连接...', Colors.orange.shade800),
      WsStatus.disconnected => ('已断开连接', Colors.grey.shade700),
      WsStatus.connected => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              networkOnline ? Icons.sync : Icons.wifi_off,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final WsStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      WsStatus.connected => ('已连接', Colors.green),
      WsStatus.connecting => ('连接中', Colors.orange),
      WsStatus.reconnecting => ('重连中', Colors.orange),
      WsStatus.waitingNetwork => ('无网络', Colors.red),
      WsStatus.disconnected => ('已断开', Colors.grey),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ImMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    final alignment = message.isSelf ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isSelf
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isSelf)
              Text(
                message.senderId,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            Text(message.text),
          ],
        ),
      ),
    );
  }
}
