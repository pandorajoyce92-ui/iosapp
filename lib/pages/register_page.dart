import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import 'webview_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _mobileCtrl   = TextEditingController();
  final _pwdCtrl      = TextEditingController();
  final _pwd2Ctrl     = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _inviterCtrl  = TextEditingController();

  bool _showPwd  = false;
  bool _showPwd2 = false;
  bool _submitting = false;
  bool _showDownloadSheet = false;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0x66FFFFFF);

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    _nicknameCtrl.dispose();
    _inviterCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  bool _isMobile(String v) => RegExp(r'^1[3-9]\d{9}$').hasMatch(v);

  Future<void> _doRegister() async {
    if (_submitting) return;

    final mobile     = _mobileCtrl.text.trim();
    final password   = _pwdCtrl.text;
    final password2  = _pwd2Ctrl.text;
    final nickname   = _nicknameCtrl.text.trim();
    final inviter    = _inviterCtrl.text.trim();

    if (!_isMobile(mobile)) { _toast('请输入正确的手机号码'); return; }
    if (password.length < 6) { _toast('密码不能少于6位'); return; }
    if (password.length > 20) { _toast('密码不能超过20位'); return; }
    if (password != password2) { _toast('两次密码不一致'); return; }
    if (nickname.isEmpty) { _toast('请输入昵称'); return; }
    if (inviter.isEmpty) { _toast('请输入推荐码'); return; }
    if (!RegExp(r'^\d+$').hasMatch(inviter)) { _toast('推荐码格式不正确（应为数字）'); return; }

    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.register,
        data: {
          'mobile': mobile,
          'password': password,
          'nickname': nickname,
          'inviter_code': inviter,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        _toast('注册成功');
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.of(context).pop(mobile);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '注册失败') : '注册失败');
      }
    } catch (e) {
      debugPrint('❌ [register] $e');
      _toast('网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openDownloadSheet() {
    setState(() => _showDownloadSheet = true);
  }

  void _closeDownloadSheet() {
    setState(() => _showDownloadSheet = false);
  }

  void _openDownloadPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewPage(url: ApiConfig.downloadPage, title: '下载简信App'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHero(),
                  _buildContent(),
                ],
              ),
            ),
            if (_showDownloadSheet) _buildDownloadOverlay(),
          ],
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
        clipBehavior: Clip.none,
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
              top: MediaQuery.of(context).padding.top + 56,
              left: 28, right: 28, bottom: 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_add_alt, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 20),
                const Text(
                  '创建账户',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white,
                    letterSpacing: -0.5, height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            bottom: -1, left: -50, right: -50,
            child: Container(
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(999)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 40),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white),
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
                  label: '手机号',
                  controller: _mobileCtrl,
                  hint: '请输入手机号码',
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  digitsOnly: true,
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.lock_outline,
                  label: '密码',
                  controller: _pwdCtrl,
                  hint: '6-20位密码',
                  obscureText: !_showPwd,
                  trailing: GestureDetector(
                    onTap: () => setState(() => _showPwd = !_showPwd),
                    child: Icon(
                      _showPwd ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: const Color(0xFF999999),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.lock_outline,
                  label: '确认密码',
                  controller: _pwd2Ctrl,
                  hint: '再次输入密码',
                  obscureText: !_showPwd2,
                  trailing: GestureDetector(
                    onTap: () => setState(() => _showPwd2 = !_showPwd2),
                    child: Icon(
                      _showPwd2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: const Color(0xFF999999),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.person_outline,
                  label: '昵称',
                  controller: _nicknameCtrl,
                  hint: '请输入昵称',
                ),
                const Divider(height: 1, color: Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.card_giftcard,
                  label: '推荐码',
                  controller: _inviterCtrl,
                  hint: '请输入推荐人的推荐码（必填）',
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildRegisterBtn(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.6))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('已有账号？',
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
                  label: '返回登录',
                  icon: Icons.login,
                  bg: const Color(0xFFE6F2FF),
                  border: const Color(0xFFB3D8FF),
                  textColor: const Color(0xFF007AFF),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  label: '下载APP',
                  icon: Icons.download_outlined,
                  bg: _cardBg,
                  border: const Color(0xFFF0F0F4),
                  textColor: const Color(0xFF555555),
                  onTap: _openDownloadSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool digitsOnly = false,
    int? maxLength,
    Widget? trailing,
    bool isLast = false,
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
            width: 60,
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
              maxLength: maxLength,
              inputFormatters: digitsOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
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

  Widget _buildRegisterBtn() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _submitting ? null : _doRegister,
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
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    '注 册',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 1),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOverlay() {
    return GestureDetector(
      onTap: _closeDownloadSheet,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              20, 24, 20, 20 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择下载平台',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                const SizedBox(height: 20),
                _buildDownloadBtn(
                  label: '下载 安卓 App',
                  icon: Icons.android,
                  bg: const Color(0xFFE6F2FF),
                  fg: const Color(0xFF007AFF),
                  borderColor: const Color(0xFFB3D8FF),
                ),
                const SizedBox(height: 12),
                _buildDownloadBtn(
                  label: '下载 iOS App',
                  icon: Icons.apple,
                  bg: const Color(0xFF1C1C1E),
                  fg: Colors.white,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _closeDownloadSheet,
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('取消',
                        style: TextStyle(fontSize: 15, color: Color(0xFF666666))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: _openDownloadPage,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
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