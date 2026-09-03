import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_demo/config/ws_app_config.dart';
import 'package:im_demo/im/im_service.dart';
import 'package:im_demo/ui/chat_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _red = Color(0xFFE53935);
  static const _linkBlue = Color(0xFF6BA8D9);
  static const _fieldBg = Color(0xFF2C2C2E);
  static const _fieldBorder = Color(0xFF3A3A3C);

  final _phoneController = TextEditingController(text: '82222222');
  final _passwordController = TextEditingController(text: '123456');
  final _im = ImService.instance;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _registerRecognizer;

  String _countryCode = '+62';
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        print("12");
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        print("122");
      };
    _registerRecognizer = TapGestureRecognizer()
      ..onTap = () {
        print("1222");
      };
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _registerRecognizer.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入手机号和密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _im.loginAndConnect(
        username: '$_countryCode$phone',
        wsUrl: WsAppConfig.wsUrl,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatPage()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCountryCode() async {
    final codes = const [
      ('🇮🇩', '+62', 'Indonesia'),
      ('🇨🇳', '+86', 'China'),
      ('🇺🇸', '+1', 'United States'),
      ('🇹🇭', '+66', 'Thailand'),
      ('🇻🇳', '+84', 'Vietnam'),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择国家/地区',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...codes.map(
                (c) => ListTile(
                  leading: Text(c.$1, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c.$3,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    c.$2,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () => Navigator.pop(context, c.$2),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) setState(() => _countryCode = selected);
  }

  String get _flagEmoji {
    switch (_countryCode) {
      case '+86':
        return '🇨🇳';
      case '+1':
        return '🇺🇸';
      case '+66':
        return '🇹🇭';
      case '+84':
        return '🇻🇳';
      default:
        return '🇮🇩';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/login_bg.jpg', fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/images/app_icon_t6.png',
                              width: 108,
                              height: 108,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '登录',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildPhoneField(),
                          const SizedBox(height: 14),
                          _buildPasswordField(),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _red, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: _red,
                                disabledBackgroundColor: _red.withValues(
                                  alpha: 0.5,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildTerms(),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              '忘记密码?',
                              style: TextStyle(color: _linkBlue, fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: '没有账号? '),
                                TextSpan(
                                  text: '立即注册',
                                  style: const TextStyle(color: _linkBlue),
                                  recognizer: _registerRecognizer,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'T6',
                style: TextStyle(
                  color: Color(0xFFFF8C1A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'SPORTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _fieldBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _pickCountryCode,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(_flagEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    _countryCode.replaceFirst('+', '+ '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 22, color: _fieldBorder),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: _red,
              decoration: const InputDecoration(
                hintText: '手机号',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _fieldBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: _red,
              decoration: const InputDecoration(
                hintText: '密码',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white70,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms() {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          height: 1.4,
        ),
        children: [
          const TextSpan(text: '同意并接受我们的'),
          TextSpan(
            text: '《服务使用条款》',
            style: const TextStyle(color: _linkBlue),
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: '和'),
          TextSpan(
            text: '《隐私政策》',
            style: const TextStyle(color: _linkBlue),
            recognizer: _privacyRecognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
