import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  bool _loadingMobile = true;
  String _mobile = '';

  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0xF2FFFFFF);

  @override
  void initState() {
    super.initState();
    _loadMobile();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMobile() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.resetPassword}&op=get_mobile',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final m = Map<String, dynamic>.from(data['result']);
        if (mounted) {
          setState(() {
            _mobile = m['mobile']?.toString() ?? '';
            _loadingMobile = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingMobile = false);
      }
    } catch (e) {
      debugPrint('❌ [resetPassword get_mobile] $e');
      if (mounted) setState(() => _loadingMobile = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  Future<void> _sendCode() async {
    if (_sending || _countdown > 0) return;
    if (_mobile.isEmpty) {
      _toast('手机号为空，无法发送');
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.sendCode,
        data: {'mobile': _mobile, 'op': 'forgetcode'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _toast('验证码发送成功');
        _startCountdown();
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '发送失败') : '发送失败');
      }
    } catch (e) {
      debugPrint('❌ [sendcode] $e');
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

  Future<void> _submit() async {
    if (_submitting) return;

    final code = _codeCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (code.isEmpty) { _toast('请输入验证码！'); return; }
    if (pwd.isEmpty) { _toast('请输入新支付密码！'); return; }
    if (confirm.isEmpty) { _toast('请再次确认支付密码！'); return; }
    if (pwd != confirm) { _toast('两次输入密码不一致！'); return; }
    if (pwd.length != 6) { _toast('请输入6位数的纯数字支付密码'); return; }

    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.resetPassword,
        data: {'password': pwd, 'code': code, 'confirm': confirm},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        _toast(data['result']?.toString() ?? '');
        if (data['status'] == 1) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [resetPassword] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              _buildTopBar(),
              Expanded(
                child: _loadingMobile
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Text('验证手机号: $_mobile',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B48B8))),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  _buildCodeRow(),
                                  _buildField('新密码', _pwdCtrl, '请输入6位新密码'),
                                  _buildField('确认密码', _confirmCtrl, '请确认6位新密码', isLast: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSubmit(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '修改支付密码',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeRow() {
    final disabled = _sending || _countdown > 0;
    final btnText = _countdown > 0
        ? '$_countdown s 后重发'
        : (_sending ? '发送中…' : '发送验证码');

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 85,
            child: Text('验证码',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111111))),
          ),
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: '请输入短信验证码',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: disabled ? null : _sendCode,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: disabled ? const Color(0xFFF5F5F7) : const Color(0xFFE6F2FF),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text(
                btnText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: disabled ? const Color(0xFFBBBBBB) : const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {bool isLast = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111111))),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmit() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Opacity(
        opacity: _submitting ? 0.6 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.28),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _submitting ? '提交中...' : '确认修改',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}