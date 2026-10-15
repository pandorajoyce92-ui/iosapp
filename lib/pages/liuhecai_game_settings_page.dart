import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiGameSettingsPage extends StatefulWidget {
  final int roomid;
  final Map<String, dynamic> gameSettings;

  const LiuhecaiGameSettingsPage({
    super.key,
    required this.roomid,
    required this.gameSettings,
  });

  @override
  State<LiuhecaiGameSettingsPage> createState() =>
      _LiuhecaiGameSettingsPageState();
}

class _LiuhecaiGameSettingsPageState
    extends State<LiuhecaiGameSettingsPage> {
  static const List<Map<String, String>> _gameList = [
    {'key': 'te_ma', 'label': '特码'},
    {'key': 'da_xiao', 'label': '大小'},
    {'key': 'dan_shuang', 'label': '单双'},
    {'key': 'he_dan_shuang', 'label': '合单双'},
    {'key': 'xiao_dan', 'label': '小单'},
    {'key': 'xiao_shuang', 'label': '小双'},
    {'key': 'da_dan', 'label': '大单'},
    {'key': 'da_shuang', 'label': '大双'},
    {'key': 'shengxiao', 'label': '生肖'},
    {'key': 'bose', 'label': '波色'},
    {'key': 'weishu', 'label': '尾数'},
    {'key': 'toushu', 'label': '头数'},
    {'key': 'wuxing', 'label': '五行'},
  ];

  final Map<String, bool> _switches = {};

  final _minBetCtrl = TextEditingController();
  final _maxBetCtrl = TextEditingController();

  bool _saving = false;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0xF2FFFFFF);
  static const Color _inputBg = Colors.white;
  static const Color _borderColor = Color(0xFFD0E4FF);

  @override
  void initState() {
    super.initState();

    final rawSwitches = widget.gameSettings['switches'];
    if (rawSwitches is Map) {
      for (final g in _gameList) {
        final v = rawSwitches[g['key']];
        _switches[g['key']!] =
            (v == null) || v == 1 || v == '1' || v == true;
      }
    } else {
      for (final g in _gameList) {
        _switches[g['key']!] = true;
      }
    }

    _minBetCtrl.text =
        _fmt(widget.gameSettings['min_bet']?.toString() ?? '1');
    _maxBetCtrl.text =
        _fmt(widget.gameSettings['max_bet']?.toString() ?? '1000');
  }

  String _fmt(String s) {
    if (s.isEmpty) return '';
    final d = double.tryParse(s);
    if (d == null) return s;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  @override
  void dispose() {
    _minBetCtrl.dispose();
    _maxBetCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final minBet = double.tryParse(_minBetCtrl.text.trim());
    final maxBet = double.tryParse(_maxBetCtrl.text.trim());
    if (minBet == null ||
        maxBet == null ||
        minBet < 0 ||
        maxBet < 0 ||
        minBet > maxBet) {
      _toast('请正确填写投注区间（最小 ≤ 最大）');
      return;
    }

    setState(() => _saving = true);

    try {
      final map = <String, int>{};
      _switches.forEach((k, v) {
        map[k] = v ? 1 : 0;
      });
      final switchesJson = jsonEncode(map);

      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&act=save_game_settings&roomid=${widget.roomid}',
        data: {
          'switches': switchesJson,
          'min_bet': minBet,
          'max_bet': maxBet,
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
      if (data is Map && data['status']?.toString() == '1') {
        _toast(data['result']?.toString() ?? '保存成功');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '保存失败')
            : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [save_game_settings] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _saving = false);
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
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSwitchCard(),
                      const SizedBox(height: 16),
                      _buildBetRangeCard(),
                      const SizedBox(height: 16),
                      _buildSaveBtn(),
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

  Widget _buildHeader() {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 40,
                height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '玩法设置',
              style: TextStyle(
                color: Color(0xFF000000),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 玩法开关卡片 ----
  Widget _buildSwitchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎲 玩法开关',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('启用/停用',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF007AFF),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: _gameList.map((g) {
              final key = g['key']!;
              final label = g['label']!;
              final enabled = _switches[key] ?? true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        )),
                    Switch(
                      value: enabled,
                      onChanged: (v) => setState(() => _switches[key] = v),
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF34C759),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _buildInfoBox(
            '💡 关闭后，该玩法将无法下注，玩家输入相关口令将提示"玩法已关闭"。',
          ),
        ],
      ),
    );
  }

  // ---- 下注区间卡片 ----
  Widget _buildBetRangeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💰 下注区间',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('全局限制',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF007AFF),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildBetRow('最小下注金额', _minBetCtrl),
          _buildBetRow('最大下注金额', _maxBetCtrl, isLast: true),
          const SizedBox(height: 14),
          _buildInfoBox(
            '💡 玩家单笔下注总金额不得超过最大下注金额，且不得低于最小下注金额。',
          ),
        ],
      ),
    );
  }

  Widget _buildBetRow(String label, TextEditingController ctrl,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                )),
          ),
          Container(
            width: 100,
            height: 38,
            decoration: BoxDecoration(
              color: _inputBg,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('元',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Opacity(
        opacity: _saving ? 0.7 : 1,
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
                color: const Color(0xFF007AFF).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _saving ? '⏳ 保存中...' : '💾 保存设置',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}