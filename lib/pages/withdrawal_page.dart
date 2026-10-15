import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';
import 'webview_page.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  bool _loading = true;
  bool _savingInfo = false;
  bool _submitting = false;

  String _balance = '0.00';
  String _feeRate = '0';

  final _realnameCtrl = TextEditingController();
  final _cardnoCtrl   = TextEditingController();
  final _cardnameCtrl = TextEditingController();
  final _mobileCtrl   = TextEditingController();
  final _moneyCtrl    = TextEditingController();

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

  @override
  void dispose() {
    _realnameCtrl.dispose();
    _cardnoCtrl.dispose();
    _cardnameCtrl.dispose();
    _mobileCtrl.dispose();
    _moneyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.withdrawal}&op=get_info',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final account = (r['account'] is Map)
            ? Map<String, dynamic>.from(r['account'])
            : <String, dynamic>{};

        if (mounted) {
          setState(() {
            _balance = r['balance']?.toString() ?? '0.00';
            final rawFee = r['feeRate']?.toString() ?? '0';
            _feeRate = _trimZero(rawFee);
            _realnameCtrl.text = account['realname']?.toString() ?? '';
            _cardnoCtrl.text   = account['cardno']?.toString() ?? '';
            _cardnameCtrl.text = account['cardname']?.toString() ?? '';
            _mobileCtrl.text   = account['mobile']?.toString() ?? '';
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [withdrawal get_info] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _trimZero(String s) {
    if (s.isEmpty) return '0';
    if (!s.contains('.')) return s;
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  Future<void> _saveInfo() async {
    if (_savingInfo) return;

    final realname = _realnameCtrl.text.trim();
    final cardno   = _cardnoCtrl.text.trim();
    final cardname = _cardnameCtrl.text.trim();
    final mobile   = _mobileCtrl.text.trim();

    if (realname.isEmpty) { _toast('真实姓名不能为空'); return; }
    if (cardno.isEmpty)   { _toast('银行卡号不能为空'); return; }
    if (cardname.isEmpty) { _toast('开户银行不能为空'); return; }
    if (mobile.isEmpty)   { _toast('手机号码不能为空'); return; }

    setState(() => _savingInfo = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.withdrawal}&op=saveinfo',
        data: {
          'realname': realname,
          'cardno': cardno,
          'cardname': cardname,
          'mobile': mobile,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _toast('账户保存成功');
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '保存失败') : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ 保存账户异常: $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final moneyStr = _moneyCtrl.text.trim();
    if (moneyStr.isEmpty) { _toast('请输入提现金额'); return; }

    final money = double.tryParse(moneyStr);
    if (money == null || money <= 0) { _toast('请输入有效的提现金额'); return; }

    final balance = double.tryParse(_balance) ?? 0;
    if (money > balance) { _toast('兑换金额不足'); return; }
    if (money < 100) { _toast('100起提现'); return; }
    if ((money * 100).round() % 1000 != 0) { _toast('只能兑换10倍数'); return; }

    if (_realnameCtrl.text.trim().isEmpty ||
        _cardnoCtrl.text.trim().isEmpty ||
        _cardnameCtrl.text.trim().isEmpty ||
        _mobileCtrl.text.trim().isEmpty) {
      _toast('请先保存完整提现信息');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.withdrawal}&op=recharge',
        data: {'goldmoney': moneyStr},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _toast(data['result']?.toString() ?? '提现成功，请等待审核！');
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WebViewPage(url: ApiConfig.withdrawalReport, title: '提现记录'),
          ),
        );
        return;
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '提现失败') : '提现失败');
      }
    } catch (e) {
      debugPrint('❌ 提现异常: $e');
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
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle('收款账户信息'),
                            _card([
                              _buildInputRow('真实姓名', _realnameCtrl, '开户人姓名'),
                              _buildInputRow('银行卡号', _cardnoCtrl, '请输入卡号', number: true),
                              _buildInputRow('开户银行', _cardnameCtrl, '如：工商银行'),
                              _buildInputRow('手机号码', _mobileCtrl, '银行预留手机号', number: true, isLast: true),
                            ]),
                            const SizedBox(height: 12),
                            _buildSaveInfoBtn(),
                            const SizedBox(height: 20),
                            _sectionTitle('提现金额'),
                            _buildAmountCard(),
                            const SizedBox(height: 20),
                            _buildSubmitBtn(),
                            const SizedBox(height: 12),
                            _buildReportBtn(),
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
              '银行卡提现',
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

  Widget _buildInputRow(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool number = false,
    bool isLast = false,
  }) {
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
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveInfoBtn() {
    return GestureDetector(
      onTap: _savingInfo ? null : _saveInfo,
      child: Opacity(
        opacity: _savingInfo ? 0.6 : 1,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCDCE6)),
          ),
          alignment: Alignment.center,
          child: Text(
            _savingInfo ? '保存中…' : '保存账户信息',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('兑换数额',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('¥',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _moneyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '请输入提现金额',
                      hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFFCCCCCC)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _tipLine('可用余额：', '$_balance 元'),
          _tipLine('最低限制：', '100起提，且须为10的倍数'),
          _tipLine('提现时间：', '每日 9:30 — 19:00'),
          _tipLine('提现手续费：', '$_feeRate%'),
        ],
      ),
    );
  }

  Widget _tipLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999), height: 1.6),
          children: [
            TextSpan(text: label),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Opacity(
        opacity: _submitting ? 0.6 : 1,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
            _submitting ? '提交中…' : '确认提现',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildReportBtn() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WebViewPage(url: ApiConfig.withdrawalReport, title: '提现记录'),
          ),
        );
      },
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCDCE6)),
        ),
        alignment: Alignment.center,
        child: const Text('查看提现记录',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
      ),
    );
  }
}