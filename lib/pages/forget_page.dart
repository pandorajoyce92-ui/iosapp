import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class ForgetPage extends StatefulWidget {
  const ForgetPage({super.key});

  @override
  State<ForgetPage> createState() => _ForgetPageState();
}

class _ForgetPageState extends State<ForgetPage> {
  final _mobileCtrl  = TextEditingController();
  final _codeCtrl    = TextEditingController();
  final _pwdCtrl     = TextEditingController();
  final _pwd2Ctrl    = TextEditingController();

  bool _showPwd  = false;
  bool _showPwd2 = false;
  bool _submitting = false;

  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0x66FFFFFF);

  @override
  void dispose() {
    _timer?.cancel();
    _mobileCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  bool _isMobile(String v) => RegExp(r'^1[3-9]\d{9}$').hasMatch(v);

  Future<void> _sendCode() async {
    if (_sending || _countdown > 0) return;
    final mobile = _mobileCtrl.text.trim();
    if (!_isMobile(mobile)) {
      _toast('请输入正确的手机号码');
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.sendCode,
        data: {'mobile': mobile, 'op': 'forgetcode'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _toast('验证码已发送');
        _startCountdown();
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '发送失败') : '发送失败');
      }
    } catch (e) {
      debugPrint('❌ [forget sendcode] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _doSave() async {
    if (_submitting) return;

    final mobile   = _mobileCtrl.text.trim();
    final code     = _codeCtrl.text.trim();
    final password = _pwdCtrl.text;
    final password2 = _pwd2Ctrl.text;

    if (!_isMobile(mobile)) { _toast('请输入正确的手机号码'); return; }
    if (code.isEmpty) { _toast('请输入验证码'); return; }
    if (password.length < 6) { _toast('密码不能少于6位'); return; }
    if (password.length > 20) { _toast('密码不能超过20位'); return; }
    if (password != password2) { _toast('两次密码不一致'); return; }

    setState(() => _submitting = true);
    try {
      final checkRes = await HttpClient.instance.dio.post(
        ApiConfig.sendCode,
        data: {'code': code, 'op': 'checkcode'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic checkData = checkRes.data;
      if (checkData is String) {
        try { checkData = jsonDecode(checkData); } catch (_) {}
      }
      if (checkData is! Map || checkData['status'] == 0) {
        _toast(checkData is Map ? (checkData['result']?.toString() ?? '验证码错误') : '验证码错误');
        return;
      }

      final res = await HttpClient.instance.dio.post(
        ApiConfig.forget,
        data: {
          'memberdata[mobile]': mobile,
          'memberdata[password]': password,
          'code': code,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _toast('密码修改成功');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(mobile);
      } else {
        String msg = '修改失败';
        if (data is Map) {
          final r = data['result'];
          if (r is Map) {
            msg = r['msg']?.toString() ?? msg;
          } else if (r != null) {
            msg = r.toString();
          }
        }
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [forget] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                  child: const Icon(Icons.key_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 18),
                const Text(
                  '找回密码',
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
                _buildCodeRow(),
                const Divider(height: 1, color: Color(0xFFF0F0F4)),
                _buildField(
                  icon: Icons.lock_outline,
                  label: '新密码',
                  controller: _pwdCtrl,
                  hint: '6-20位新密码',
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
                  hint: '再次输入新密码',
                  obscureText: !_showPwd2,
                  trailing: GestureDetector(
                    onTap: () => setState(() => _showPwd2 = !_showPwd2),
                    child: Icon(
                      _showPwd2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: const Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSaveBtn(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.6))),
            ],
          ),
          const SizedBox(height: 22),
          _buildBackToLoginBtn(),
        ],
      ),
    );
  }

  Widget _buildCodeRow() {
    final disabled = _sending || _countdown > 0;
    final btnText = _countdown > 0
        ? '$_countdown 秒后重新获取'
        : (_sending ? '发送中…' : '获取验证码');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          const SizedBox(
            width: 30,
            child: Icon(Icons.shield_outlined, size: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(
            width: 60,
            child: Text('验证码',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF555555))),
          ),
          Container(width: 1, height: 16, color: const Color(0xFFF0F0F4)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                hintText: '输入短信验证码',
                hintStyle: TextStyle(
                    fontSize: 14, color: Color(0xFF999999), fontWeight: FontWeight.w300),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: disabled ? null : _sendCode,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: disabled
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                      ),
                color: disabled ? const Color(0xFFB0A8CC) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(btnText,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
            ),
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

  Widget _buildSaveBtn() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _submitting ? null : _doSave,
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
                    '保 存',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 1),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLoginBtn() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F2FF),
          border: Border.all(color: const Color(0xFFB3D8FF), width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.login, size: 16, color: Color(0xFF007AFF)),
            SizedBox(width: 6),
            Text('返回登录',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF007AFF))),
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