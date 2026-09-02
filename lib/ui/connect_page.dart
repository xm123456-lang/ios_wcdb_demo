import 'package:flutter/material.dart';
import 'package:im_demo/config/im_config.dart';
import 'package:im_demo/im/im_service.dart';
import 'package:im_demo/ui/chat_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _urlController = TextEditingController(text: ImConfig.wsUrl);
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _im = ImService.instance;

  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final userId = _userController.text.trim();
    final password = _passwordController.text;

    if (url.isEmpty || userId.isEmpty) {
      setState(() => _error = '请填写 WebSocket 地址和用户名');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _im.loginAndConnect(
        username: userId,
        wsUrl: url,
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatPage()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接 IM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WebSocket 地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码（可选，填写则先 HTTP 登录）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API: ${ImConfig.baseUrl}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }
}
