import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class WelfareNumbersPage extends StatefulWidget {
  final int roomid;
  const WelfareNumbersPage({super.key, required this.roomid});

  @override
  State<WelfareNumbersPage> createState() => _WelfareNumbersPageState();
}

class _WelfareNumbersPageState extends State<WelfareNumbersPage> {
  bool _loading = true;
  final List<_Rule> _rules = [];

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
    _load();
  }

  @override
  void dispose() {
    for (final r in _rules) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.welfareNumbers}&roomid=${widget.roomid}&action=get_data',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List)
            .map((e) => _Rule.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        for (final r in _rules) {
          r.dispose();
        }
        _rules.clear();
        _rules.addAll(list);

        if (mounted) setState(() => _loading = false);
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [welfare_numbers get_data] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  void _addRow() {
    setState(() {
      _rules.add(_Rule.empty());
    });
  }

  Future<void> _saveRow(_Rule rule) async {
    if (rule.saving) return;

    final name = rule.nameCtrl.text.trim();
    final numberStr = rule.numberCtrl.text.trim();
    final rewardStr = rule.rewardCtrl.text.trim();

    if (name.isEmpty) { _toast('请填写福利名称'); return; }
    final number = double.tryParse(numberStr);
    if (number == null || number <= 0) { _toast('福利数字必须大于0'); return; }
    final reward = double.tryParse(rewardStr);
    if (reward == null || reward <= 0) { _toast('奖励金额必须大于0'); return; }

    setState(() => rule.saving = true);

    final action = rule.id > 0 ? 'edit' : 'add';
    final Map<String, dynamic> data = {
      'name': name,
      'welfare_number': numberStr,
      'reward_amount': rewardStr,
      'sort_order': 0,
    };
    if (action == 'edit') data['id'] = rule.id;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.welfareNumbers}&roomid=${widget.roomid}&action=$action',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic r = res.data;
      if (r is String) {
        try { r = jsonDecode(r); } catch (_) {}
      }
      if (r is Map && r['status']?.toString() == '1') {
        _toast(r['result']?.toString() ?? '保存成功');
        if (action == 'add' && r['id'] != null) {
          setState(() {
            rule.id = int.tryParse(r['id'].toString()) ?? 0;
          });
        }
      } else {
        _toast(r is Map ? (r['result']?.toString() ?? '保存失败') : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [welfare_numbers save] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => rule.saving = false);
    }
  }

  Future<void> _deleteRow(_Rule rule) async {
    if (rule.id <= 0) {
      final ok = await _confirm('确定要删除该规则吗？');
      if (ok != true) return;
      setState(() {
        _rules.remove(rule);
        rule.dispose();
      });
      return;
    }

    final ok = await _confirm('确定要删除该规则吗？');
    if (ok != true) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.welfareNumbers}&roomid=${widget.roomid}&action=delete',
        data: {'id': rule.id},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic r = res.data;
      if (r is String) {
        try { r = jsonDecode(r); } catch (_) {}
      }
      if (r is Map && r['status']?.toString() == '1') {
        _toast('删除成功');
        setState(() {
          _rules.remove(rule);
          rule.dispose();
        });
      } else {
        _toast(r is Map ? (r['result']?.toString() ?? '删除失败') : '删除失败');
      }
    } catch (e) {
      debugPrint('❌ [welfare_numbers delete] $e');
      _toast('网络错误，请重试');
    }
  }

  Future<bool?> _confirm(String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
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
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
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
              '奖励规则',
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

  Widget _buildBody() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        80 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        if (_rules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Text(
                '暂无规则，请点击下方添加',
                style: TextStyle(fontSize: 15, color: Color(0xFF999999)),
              ),
            ),
          )
        else
          ..._rules.map(_buildRuleItem),
        const SizedBox(height: 8),
        _buildAddBtn(),
      ],
    );
  }

  Widget _buildRuleItem(_Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: _buildInput(rule.nameCtrl, '名称', isNumber: false),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 8,
            child: _buildInput(rule.numberCtrl, '0.00', isNumber: true),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 8,
            child: _buildInput(rule.rewardCtrl, '0.00', isNumber: true),
          ),
          const SizedBox(width: 8),
          _buildIconBtn(
            text: rule.saving ? '…' : '✓',
            bg: const Color(0xFF007AFF),
            fg: Colors.white,
            onTap: rule.saving ? null : () => _saveRow(rule),
          ),
          const SizedBox(width: 6),
          _buildIconBtn(
            text: '✕',
            bg: const Color(0xFFFCE8E8),
            fg: const Color(0xFFE94848),
            border: const Color(0xFFF5C8C8),
            onTap: () => _deleteRow(rule),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {required bool isNumber}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _inputBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
            : null,
        style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
        ),
      ),
    );
  }

  Widget _buildIconBtn({
    required String text,
    required Color bg,
    required Color fg,
    Color? border,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border != null ? Border.all(color: border) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }

  Widget _buildAddBtn() {
    return GestureDetector(
      onTap: _addRow,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF007AFF), width: 2),
        ),
        alignment: Alignment.center,
        child: const Text(
          '+ 添加新规则',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
        ),
      ),
    );
  }
}

// ================= 规则模型 =================
class _Rule {
  int id;
  final TextEditingController nameCtrl;
  final TextEditingController numberCtrl;
  final TextEditingController rewardCtrl;
  bool saving;

  _Rule({
    required this.id,
    required String name,
    required String number,
    required String reward,
    this.saving = false,
  })  : nameCtrl = TextEditingController(text: name),
        numberCtrl = TextEditingController(text: number),
        rewardCtrl = TextEditingController(text: reward);

  factory _Rule.fromJson(Map<String, dynamic> j) {
    return _Rule(
      id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      name: j['name']?.toString() ?? '',
      number: _numStr(j['welfare_number']),
      reward: _numStr(j['reward_amount']),
    );
  }

  factory _Rule.empty() {
    return _Rule(id: 0, name: '', number: '', reward: '');
  }

  static String _numStr(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  void dispose() {
    nameCtrl.dispose();
    numberCtrl.dispose();
    rewardCtrl.dispose();
  }
}