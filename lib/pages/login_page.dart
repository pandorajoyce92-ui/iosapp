import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import 'main_tab_page.dart';
import 'register_page.dart';
import 'forget_page.dart';
import 'webview_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _showPwd = false;
  bool _loading = false;
  final _storage = const FlutterSecureStorage();

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0x66FFFFFF);

  @override
  void initState() {
    super.initState();
    _fillSaved();
  }

  Future<void> _fillSaved() async {
    final m = await _storage.read(key: 'login_mobile');
    final p = await _storage.read(key: 'login_password');
    if (!mounted) return;
    if (m != null) _mobileCtrl.text = m;
    if (p != null) _pwdCtrl.text = p;
  }

  Future<void> _login(String mobile, String password, {bool silent = false}) async {
    if (mobile.length < 3) {
      if (!silent) _toast('请输入手机号或账号');
      return;
    }
    if (password.isEmpty) {
      if (!silent) _toast('请输入密码');
      return;
    }

    setState(() => _loading = true);
    try {
      try {
        await HttpClient.instance.cookieJar.deleteAll();
      } catch (e) {
        debugPrint('🧹 清空 Cookie 失败: $e');
      }

      final res = await HttpClient.instance.dio.post(
        ApiConfig.login,
        data: {'mobile': mobile, 'password': password, 'type': '0'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        await _storage.write(key: 'login_mobile', value: mobile);
        await _storage.write(key: 'login_password', value: password);
        if (!mounted) return;
        _toast('登录成功');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainTabPage()),
        );
      } else {
        final msg = (data is Map ? data['result'] : null)?.toString() ?? '登录失败';
        if (silent) {
          await _storage.delete(key: 'login_password');
        } else {
          _toast(msg);
        }
      }
    } catch (e) {
      if (!silent) _toast('网络异常：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007AFF), Color(0xFF07C160)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.18), Colors.transparent],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60, left: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.10), Colors.transparent],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 64,
              left: 28, right: 28, bottom: 52,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 20),
                const Text(
                  '欢迎使用~',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white,
                    letterSpacing: -0.5, height: 1.15,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '请先登录您的简信账户',
                  style: TextStyle(
                    fontSize: 13.5, color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 32, 26, 40),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12, offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _buildField(
                  icon: Icons.phone_android,
                  label: '账户',
                  controller: _mobileCtrl,
                  hint: '手机号 / 账号',
                  keyboardType: TextInputType.phone,
                ),
                Container(height: 1, color: const Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.lock_outline,
                  label: '密码',
                  controller: _pwdCtrl,
                  hint: '请输入密码',
                  obscureText: !_showPwd,
                  trailing: GestureDetector(
                    onTap: () => setState(() => _showPwd = !_showPwd),
                    child: Icon(
                      _showPwd ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: const Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _login(_mobileCtrl.text.trim(), _pwdCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.35),
                      blurRadius: 18, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '登 录',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.6))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('还没有账号？',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ),
              Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.6))),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  label: '立即注册',
                  bg: const Color(0xFFE6F2FF),
                  border: const Color(0xFFB3D8FF),
                  textColor: const Color(0xFF007AFF),
                  onTap: _goRegister,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  label: '找回密码',
                  bg: _cardBg,
                  border: const Color(0xFFF0F0F4),
                  textColor: const Color(0xFF555555),
                  onTap: _goForget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openWebView(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewPage(url: url, title: title)),
    );
  }

  Future<void> _goRegister() async {
    final mobile = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (mobile != null && mobile.isNotEmpty && mounted) {
      setState(() {
        _mobileCtrl.text = mobile;
        _pwdCtrl.clear();
      });
    }
  }

  Future<void> _goForget() async {
    final mobile = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ForgetPage()),
    );
    if (mobile != null && mobile.isNotEmpty && mounted) {
      setState(() {
        _mobileCtrl.text = mobile;
        _pwdCtrl.clear();
      });
    }
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Icon(icon, size: 16, color: const Color(0xFF999999)),
          ),
          SizedBox(
            width: 36,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF555555))),
          ),
          Container(width: 1, height: 16, color: const Color(0xFFF0F0F4)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: const TextStyle(
                    fontSize: 14, color: Color(0xFF999999), fontWeight: FontWeight.w300),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required Color bg,
    required Color border,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
      ),
    );
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.18);
    for (double x = 0; x < size.width; x += 22) {
      for (double y = 0; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}