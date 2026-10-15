import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class BetSheet extends StatefulWidget {
  final int roomid;
  final String periodNum;
  final Map<String, dynamic> gameSettings;

  const BetSheet({
    super.key,
    required this.roomid,
    required this.periodNum,
    required this.gameSettings,
  });

  @override
  State<BetSheet> createState() => _BetSheetState();
}

class _BetSheetState extends State<BetSheet> {
  static const List<Map<String, String>> _betTypes = [
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

  String _currentType = 'te_ma';
  final Set<String> _selected = {};
  final TextEditingController _amountCtrl = TextEditingController();
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
    final first = _betTypes.firstWhere(
      (t) => _isTypeEnabled(t['key']!),
      orElse: () => _betTypes.first,
    );
    _currentType = first['key']!;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool _isTypeEnabled(String key) {
    final switches = widget.gameSettings['switches'];
    if (switches is! Map) return true;
    final v = switches[key];
    if (v == null) return true;
    return v == 1 || v == '1' || v == true;
  }

  bool get _anyEnabled => _betTypes.any((t) => _isTypeEnabled(t['key']!));

  List<String> _optionsOf(String type) {
    switch (type) {
      case 'te_ma':
        return List.generate(49, (i) => (i + 1).toString().padLeft(2, '0'));
      case 'da_xiao':
        return ['大', '小'];
      case 'dan_shuang':
        return ['单', '双'];
      case 'he_dan_shuang':
        return ['合单', '合双'];
      case 'xiao_dan':
        return ['小单'];
      case 'xiao_shuang':
        return ['小双'];
      case 'da_dan':
        return ['大单'];
      case 'da_shuang':
        return ['大双'];
      case 'shengxiao':
        return ['马', '羊', '猴', '鸡', '狗', '猪', '鼠', '牛', '虎', '兔', '龙', '蛇'];
      case 'bose':
        return ['红波', '绿波', '蓝波'];
      case 'weishu':
        return List.generate(10, (i) => '${i}尾');
      case 'toushu':
        return List.generate(5, (i) => '${i}头');
      case 'wuxing':
        return ['金', '木', '水', '火', '土'];
    }
    return [];
  }

  double get _minBet =>
      double.tryParse(widget.gameSettings['min_bet']?.toString() ?? '1') ?? 1;
  double get _maxBet =>
      double.tryParse(widget.gameSettings['max_bet']?.toString() ?? '1000') ??
      1000;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _switchType(String key) {
    if (!_isTypeEnabled(key)) {
      _toast('该玩法已关闭');
      return;
    }
    setState(() {
      _currentType = key;
      _selected.clear();
    });
  }

  void _toggleOption(String opt) {
    setState(() {
      if (_selected.contains(opt)) {
        _selected.remove(opt);
      } else {
        _selected.add(opt);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selected.isEmpty) {
      _toast('请选择下注内容');
      return;
    }
    final amountStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _toast('请输入有效金额');
      return;
    }

    final total = amount * _selected.length;
    if (total < _minBet || total > _maxBet) {
      _toast('下注金额需在 ${_fmt(_minBet)} 至 ${_fmt(_maxBet)} 元之间');
      return;
    }

    setState(() => _submitting = true);
    try {
      final contents = _selected.toList()..sort();
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
        data: {
          'op': 'usersetred',
          'bet_type': _currentType,
          'bet_content': contents.join(','),
          'money': amountStr,
          'period_id': widget.periodNum,
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
        if (data['status']?.toString() == '1') {
          _toast(data['msg']?.toString() ?? '下注成功');
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) Navigator.of(context).pop(true);
          return;
        } else {
          final msg = data['result']?.toString() ??
              data['msg']?.toString() ??
              '下注失败';
          _toast(msg);
        }
      } else {
        _toast('下注失败');
      }
    } catch (e) {
      debugPrint('❌ [usersetred] $e');
      _toast('网络错误，请重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  // ============ UI ============
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
                child: !_anyEnabled
                    ? const Center(
                        child: Text(
                          '当前房间暂无可用玩法，请联系群主或财务',
                          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                        ),
                      )
                    : _buildBody(),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 40,
              height: 44,
              child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '下注',
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

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('选择下注类型'),
          _buildTypeCard(),
          const SizedBox(height: 12),
          _sectionTitle('选择下注内容'),
          _buildContentCard(),
          const SizedBox(height: 12),
          _sectionTitle('下注金额'),
          _buildAmountCard(),
          const SizedBox(height: 16),
          _buildSubmitBtn(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF007AFF),
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  // ---- 玩法卡片：每行 4 个均匀铺满 ----
  Widget _buildTypeCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = 4;
          const spacing = 8.0;
          final itemWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;

          return Wrap(
            spacing: spacing,
            runSpacing: 8,
            children: _betTypes.map((t) {
              final key = t['key']!;
              final label = t['label']!;
              final active = key == _currentType;
              final enabled = _isTypeEnabled(key);
              return GestureDetector(
                onTap: () => _switchType(key),
                child: Container(
                  width: itemWidth,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFE6F2FF)
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: active
                        ? Border.all(color: const Color(0xFFB3D8FF))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: !enabled
                          ? const Color(0xFFCCCCCC)
                          : (active
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF666666)),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ---- 号码/选项：GridView 每行 5 个 ----
  Widget _buildContentCard() {
    final options = _optionsOf(_currentType);
    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '暂无可选项',
          style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = 5;
          const spacing = 10.0;
          final itemWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
          const itemHeight = 38.0;
          final aspect = itemWidth / itemHeight;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspect,
            children: options.map((opt) {
              final active = _selected.contains(opt);
              return GestureDetector(
                onTap: () => _toggleOption(opt),
                child: Container(
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFFEFEF)
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFE94848)
                          : const Color(0xFFEBEBF0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFFE94848)
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ---- 金额卡片 ----
  Widget _buildAmountCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
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
                '¥',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '金额',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '输入金额',
                  hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '元',
              style: TextStyle(fontSize: 14, color: Color(0xFF111111)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final total = amount * _selected.length;
    final totalStr = total > 0 ? '（合计 ${_fmt(total)} 元）' : '';

    return GestureDetector(
      onTap: _submitting ? null : _submit,
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
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _submitting ? '提交中…' : '确认下注$totalStr',
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