import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/http_client.dart';
import 'login_page.dart';
import 'login_password_page.dart';
import 'reset_password_page.dart';
import 'pay_password_page.dart';

class InstallPage extends StatefulWidget {
  const InstallPage({super.key});

  @override
  State<InstallPage> createState() => _InstallPageState();
}

class _InstallPageState extends State<InstallPage> {
  bool _voiceOn = true;
  bool _loaded = false;

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
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString('lastname');
    if (mounted) {
      setState(() {
        _voiceOn = v == null ? true : v == '1';
        _loaded = true;
      });
    }
  }

  Future<void> _toggleVoice(bool v) async {
    setState(() => _voiceOn = v);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('lastname', v ? '1' : '0');
  }

  void _goLoginPassword() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPasswordPage()));
  }

  void _goResetPassword() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetPasswordPage()));
  }

  void _goPayPassword() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayPasswordPage()));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await HttpClient.instance.cookieJar.deleteAll();
    } catch (e) {
      debugPrint('❌ clear cookie: $e');
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('locastorage');
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle('系统设置'),
                            _card([
                              _buildSwitchRow('声音设置', _voiceOn, _toggleVoice),
                            ]),
                            const SizedBox(height: 12),
                            _sectionTitle('安全设置'),
                            _card([
                              _buildLinkRow('修改登录密码', _goLoginPassword),
                              _buildLinkRow('修改支付密码', _goResetPassword),
                              _buildLinkRow('设置支付密码', _goPayPassword, isLast: true),
                            ]),
                            const SizedBox(height: 24),
                            _buildLogoutBtn(),
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
              '设置',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(t,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5B48B8), fontWeight: FontWeight.w500)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(String label, VoidCallback onTap, {bool isLast = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutBtn() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text('退出当前账号',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE94848))),
      ),
    );
  }
}