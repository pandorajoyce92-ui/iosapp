import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../core/config.dart';
import '../core/http_client.dart';
import 'pay_password_dialog.dart';

class SendRedPacketSheet extends StatefulWidget {
  final int roomid;
  final double roomMin;
  final double roomMax;
  final bool noPayPwd;

  const SendRedPacketSheet({
    super.key,
    required this.roomid,
    required this.roomMin,
    required this.roomMax,
    required this.noPayPwd,
  });

  @override
  State<SendRedPacketSheet> createState() => _SendRedPacketSheetState();
}

class _SendRedPacketSheetState extends State<SendRedPacketSheet> {
  int _nums = 7;
  String _moneyStr = '';
  final Set<String> _boomSet = {};
  bool _showMoneyKeyboard = false;
  bool _submitting = false;

  static const _maxBooms = 4;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Stack(
          children: [
            Column(
              children: [
                Container(height: statusBarHeight, color: const Color(0xFFE6F2FF)),
                _buildHeader(),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_showMoneyKeyboard) {
                        setState(() => _showMoneyKeyboard = false);
                      }
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle('多雷玩法'),
                          _buildNumsTabs(),
                          const SizedBox(height: 12),
                          _sectionTitle('红包金额'),
                          _buildMoneyCard(),
                          const SizedBox(height: 12),
                          _sectionTitle('设置雷号'),
                          _buildBoomCard(),
                          const SizedBox(height: 20),
                          _buildSubmitBtn(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_showMoneyKeyboard)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _buildMoneyKeyboard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(
          t,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999), fontWeight: FontWeight.w500),
        ),
      );

    Widget _buildHeader() {
      return Container(
        height: 44,
        color: const Color(0xFFE6F2FF),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '发红包',
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );
    }

  Widget _buildNumsTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [7, 8, 9].map((n) {
          final active = _nums == n;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onChangeNums(n),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 34,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF4F1FF) : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                  border: active ? Border.all(color: const Color(0xFFD5C8FF)) : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n包',
                  style: TextStyle(
                    fontSize: 14,
                    color: active ? const Color(0xFF5B48B8) : const Color(0xFF666666),
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onChangeNums(int n) {
    setState(() {
      _nums = n;
      _boomSet.clear();
    });
  }

  Widget _buildMoneyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '拼',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '总金额',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showMoneyKeyboard = true),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 80),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _moneyStr.isEmpty ? '0.00' : _moneyStr,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        color: _moneyStr.isEmpty ? const Color(0xFFBBBBBB) : const Color(0xFF111111),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('元', style: TextStyle(fontSize: 14, color: Color(0xFF111111))),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  '红包发布范围：${_fmt(widget.roomMin)}-${_fmt(widget.roomMax)}元',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  Widget _buildBoomCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            alignment: Alignment.centerLeft,
            child: Text(
              '点击下方选择雷号(最多$_maxBooms个)',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: List.generate(10, (i) {
                final digit = i.toString();
                final active = _boomSet.contains(digit);
                return GestureDetector(
                  onTap: () => _toggleBoom(digit),
                  child: Container(
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFFFEFEF) : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? const Color(0xFFE94848) : const Color(0xFFEBEBF0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? const Color(0xFFE94848) : const Color(0xFF333333),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBoom(String digit) {
    if (_boomSet.contains(digit)) {
      setState(() => _boomSet.remove(digit));
    } else {
      if (_boomSet.length >= _maxBooms) {
        _toast('最多选择$_maxBooms个雷号');
        return;
      }
      setState(() => _boomSet.add(digit));
    }
  }

  Widget _buildSubmitBtn() {
    final moneyText = _moneyStr.isEmpty ? '0.00' : _moneyStr;
    return GestureDetector(
      onTap: _submitting ? null : _onSubmit,
      child: Opacity(
        opacity: _submitting ? 0.6 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF76B1C), Color(0xFFE94848)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94848).withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _submitting ? '提交中…' : '塞钱进红包 ($moneyText元)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ============ 金额键盘 ============
  void _onMoneyKey(String key) {
    String cur = _moneyStr;
    if (key == 'del') {
      cur = cur.isEmpty ? '' : cur.substring(0, cur.length - 1);
    } else if (key == '.') {
      if (cur.contains('.')) return;
      cur = cur.isEmpty ? '0.' : '$cur.';
    } else {
      if (cur == '0') cur = '';
      if (cur.contains('.')) {
        final parts = cur.split('.');
        if (parts.length > 1 && parts[1].length >= 2) return;
      }
      cur = '$cur$key';
      final numCheck = double.tryParse(cur) ?? 0;
      if (numCheck > widget.roomMax) {
        cur = _fmt(widget.roomMax);
        _toast('已自动调整为最大金额 ${_fmt(widget.roomMax)} 元');
      }
    }
    setState(() => _moneyStr = cur);
  }

  Widget _buildMoneyKeyboard() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F7),
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _kbRow(['1', '2', '3']),
          _kbDivider(),
          _kbRow(['4', '5', '6']),
          _kbDivider(),
          _kbRow(['7', '8', '9']),
          _kbDivider(),
          _kbRow(['.', '0', 'del']),
        ],
      ),
    );
  }

  Widget _kbDivider() => Container(height: 1, color: const Color(0xFFE5E5EA));

  Widget _kbRow(List<String> keys) =>
      Row(children: keys.map((k) => Expanded(child: _kbKey(k))).toList());

  Widget _kbKey(String key) {
    final isDel = key == 'del';
    return GestureDetector(
      onTap: () => _onMoneyKey(key),
      child: Container(
        height: 56,
        color: isDel ? const Color(0xFFF5F5F7) : Colors.white,
        alignment: Alignment.center,
        child: isDel
            ? const Text('⌫', style: TextStyle(fontSize: 22, color: Color(0xFF666666)))
            : Text(
                key,
                style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF111111),
                ),
              ),
      ),
    );
  }

  // ============ 提交 ============
  Future<void> _onSubmit() async {
    if (_submitting) return;

    final money = double.tryParse(_moneyStr);
    if (money == null || money <= 0) {
      _toast('请输入正确的金额');
      return;
    }
    if (money < widget.roomMin || money > widget.roomMax) {
      _toast('发包金额需在 ${_fmt(widget.roomMin)} 至 ${_fmt(widget.roomMax)} 元之间');
      return;
    }
    if (_boomSet.isEmpty) {
      _toast('请选择雷号');
      return;
    }

    setState(() => _showMoneyKeyboard = false);

    String passpwd = '';
    if (!widget.noPayPwd) {
      final pwd = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) => PayPasswordDialog(amount: money),
      );
      if (pwd == null || pwd.length != 6) return;
      passpwd = pwd;
    }

    setState(() => _submitting = true);
    await _doSend(passpwd);
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _doSend(String passpwd) async {
    try {
      final boomStr = _boomSet.toList()..sort();
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {
          'op': 'usersetred',
          'roomid': widget.roomid,
          'nums': _nums,
          'money': _moneyStr,
          'boom': boomStr.join(','),
          'boomtype': 1,
          'passpwd': passpwd,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        String msg = '操作完成';
        if (data['msg'] != null) {
          msg = data['msg'].toString();
        } else if (data['result'] is Map && (data['result'] as Map)['msg'] != null) {
          msg = (data['result'] as Map)['msg'].toString();
        } else if (data['result'] != null) {
          msg = data['result'].toString();
        }
        _toast(msg);

        if (data['status']?.toString() == '1') {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        if (msg.contains('未设置支付密码')) {
          _toast('请先前往【我的-设置】设置支付密码');
        }
      } else {
        _toast('发送失败');
      }
    } catch (e) {
      debugPrint('❌ [usersetred] $e');
      _toast('网络错误，请重试');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }
}