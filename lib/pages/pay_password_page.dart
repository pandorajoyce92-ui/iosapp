import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class PayPasswordPage extends StatefulWidget {
  const PayPasswordPage({super.key});

  @override
  State<PayPasswordPage> createState() => _PayPasswordPageState();
}

class _PayPasswordPageState extends State<PayPasswordPage> {
  bool _loading = true;
  bool _hasPwd = false;
  bool _submitting = false;

  final List<String> _digits = ['', '', '', '', '', ''];
  int _cursor = 0;

  int _stage = 0;
  String _pay1 = '';
  String _pay2 = '';

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.payPassword}&op=get_status',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final hp = r['has_pwd'];
        final has = (hp is bool) ? hp : (hp?.toString() == '1' || hp?.toString() == 'true');
        if (mounted) {
          setState(() {
            _hasPwd = has;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [pay_password get_status] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  String get _title {
    if (!_hasPwd) {
      return _stage == 0 ? '请设置支付密码' : '请确认支付密码';
    } else {
      if (_stage == 0) return '请输入原始支付密码';
      if (_stage == 1) return '请输入新支付密码';
      return '请确认新支付密码';
    }
  }

  void _input(String digit) {
    if (_submitting) return;
    if (_cursor >= 6) return;
    setState(() {
      _digits[_cursor] = digit;
      _cursor++;
    });
  }

  void _delete() {
    if (_submitting) return;
    if (_cursor <= 0) return;
    setState(() {
      _cursor--;
      _digits[_cursor] = '';
    });
  }

  void _clear() {
    setState(() {
      for (int i = 0; i < 6; i++) _digits[i] = '';
      _cursor = 0;
    });
  }

  String get _current => _digits.take(_cursor).join();

  Future<void> _submit() async {
    if (_submitting) return;
    if (_cursor != 6) {
      _toast('请输入完整6位密码');
      return;
    }

    final cur = _current;

    if (!_hasPwd) {
      if (_stage == 0) {
        _pay1 = cur;
        _clear();
        setState(() => _stage = 1);
        return;
      } else {
        _pay2 = cur;
        await _doSubmitFirst();
      }
    } else {
      if (_stage == 0) {
        _pay1 = cur;
        _clear();
        setState(() => _stage = 1);
        return;
      }
      if (_stage == 1) {
        _pay2 = cur;
        _clear();
        setState(() => _stage = 2);
        return;
      }
      final pay3 = cur;
      await _doSubmitChange(pay3);
    }
  }

  Future<void> _doSubmitFirst() async {
    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.payPassword,
        data: {'pay1': _pay1, 'pay2': _pay2},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        _toast(data['result']?.toString() ?? '');
        if (data['status'] == 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop(true);
          return;
        } else {
          _clear();
          _pay1 = '';
          _pay2 = '';
          setState(() => _stage = 0);
        }
      }
    } catch (e) {
      debugPrint('❌ [pay_password first] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _doSubmitChange(String pay3) async {
    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.payPassword,
        data: {'pay1': _pay1, 'pay2': _pay2, 'pay3': pay3},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        _toast(data['result']?.toString() ?? '');
        if (data['status'] == 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop(true);
          return;
        } else {
          _clear();
          _pay1 = '';
          _pay2 = '';
          setState(() => _stage = 0);
        }
      }
    } catch (e) {
      debugPrint('❌ [pay_password change] $e');
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                              child: Column(
                                children: [
                                  Text(
                                    _title,
                                    style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111111),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '为保障资金安全，请验证身份信息',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                                  ),
                                  const SizedBox(height: 30),
                                  _buildDots(),
                                  const SizedBox(height: 30),
                                  _buildSubmitBtn(),
                                ],
                              ),
                            ),
                          ),
                          _buildNumpad(),
                        ],
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
              '设置支付密码',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _cursor;
        return Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB3D8FF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6, offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: filled
              ? Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Opacity(
        opacity: _submitting ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          height: 46,
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
            _submitting ? '提交中...' : '确定提交',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      color: const Color(0xFFD0E4FF),
      padding: const EdgeInsets.only(top: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _numpadRow(['1', '2', '3']),
          _divider(),
          _numpadRow(['4', '5', '6']),
          _divider(),
          _numpadRow(['7', '8', '9']),
          _divider(),
          _numpadRow(['clear', '0', 'del']),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: const Color(0xFFD0E4FF));

  Widget _numpadRow(List<String> keys) {
    return Row(
      children: keys.map((k) => Expanded(child: _numpadKey(k))).toList(),
    );
  }

  Widget _numpadKey(String key) {
    String label;
    bool grey = false;
    VoidCallback onTap;

    if (key == 'clear') {
      label = '清空';
      grey = true;
      onTap = _clear;
    } else if (key == 'del') {
      label = '删除';
      grey = true;
      onTap = _delete;
    } else {
      label = key;
      onTap = () => _input(key);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        color: grey ? const Color(0xFFF0F5FF) : Colors.white,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: grey ? 16 : 24,
            fontWeight: grey ? FontWeight.w400 : FontWeight.w500,
            color: grey ? const Color(0xFF666666) : const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}