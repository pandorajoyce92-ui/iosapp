import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class WelfareSettingPage extends StatefulWidget {
  final int roomid;
  const WelfareSettingPage({super.key, required this.roomid});

  @override
  State<WelfareSettingPage> createState() => _WelfareSettingPageState();
}

class _WelfareSettingPageState extends State<WelfareSettingPage> {
  bool _loading = true;
  bool _saving = false;
  final List<_WelfareRule> _rules = [];

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
        '${ApiConfig.welfareSetting}&op=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['rules'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        for (final old in _rules) {
          old.dispose();
        }
        _rules.clear();
        for (final item in list) {
          _rules.add(_WelfareRule.fromJson(item));
        }

        if (mounted) setState(() => _loading = false);
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [welfare get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  void _addRule() {
    setState(() {
      _rules.add(_WelfareRule.empty());
    });
  }

  Future<void> _removeRule(_WelfareRule rule) async {
    if (rule.id == 0) {
      final ok = await _confirm('确认删除该规则吗？');
      if (ok != true) return;
      setState(() {
        _rules.remove(rule);
        rule.dispose();
      });
      return;
    }

    final ok = await _confirm('确认删除该规则吗？');
    if (ok != true) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.welfareSetting}&op=delete&roomid=${widget.roomid}',
        data: {'id': rule.id},
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
        setState(() {
          _rules.remove(rule);
          rule.dispose();
        });
        _toast('删除成功');
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '删除失败') : '删除失败');
      }
    } catch (e) {
      debugPrint('❌ [welfare delete] $e');
      _toast('网络错误');
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
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_rules.isEmpty) {
      _toast('请至少添加一个规则');
      return;
    }

    final rulesJson = <Map<String, dynamic>>[];
    for (int i = 0; i < _rules.length; i++) {
      final r = _rules[i];
      final target = r.targetCtrl.text.trim();
      final hour = r.hourCtrl.text.trim();
      final minute = r.minuteCtrl.text.trim();
      final bonus = r.bonusCtrl.text.trim();
      final nums = r.numsCtrl.text.trim();

      if (target.isEmpty || hour.isEmpty || minute.isEmpty || bonus.isEmpty) {
        _toast('第 ${i + 1} 条规则未完整填写');
        return;
      }
      final targetV = double.tryParse(target) ?? 0;
      final bonusV = double.tryParse(bonus) ?? 0;
      if (targetV <= 0 || bonusV <= 0) {
        _toast('第 ${i + 1} 条规则金额必须大于0');
        return;
      }
      final hourV = int.tryParse(hour) ?? -1;
      final minuteV = int.tryParse(minute) ?? -1;
      if (hourV < 0 || hourV > 23 || minuteV < 0 || minuteV > 59) {
        _toast('第 ${i + 1} 条规则时间格式错误');
        return;
      }
      final numsV = int.tryParse(nums.isEmpty ? '1' : nums) ?? 1;
      if (numsV < 1) {
        _toast('第 ${i + 1} 条规则红包个数至少为1');
        return;
      }

      rulesJson.add({
        'condition_type': 1,
        'target_amount': targetV,
        'hour': hourV,
        'minute': minuteV,
        'bonus_amount': bonusV,
        'total_nums': numsV,
        'status': r.status,
      });
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.welfareSetting}&op=save&roomid=${widget.roomid}',
        data: {
          'rules': rulesJson,
          'roomid': widget.roomid,
          'op': 'save',
        },
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('保存成功');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '保存失败') : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [welfare save] $e');
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
              '重磅福利设置',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTip(),
            if (_rules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '暂无福利规则，点击下方添加',
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                  ),
                ),
              )
            else
              ..._rules.map(_buildRuleCard),
            const SizedBox(height: 8),
            _buildAddBtn(),
            const SizedBox(height: 12),
            _buildSaveBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: const Text(
        '📌 设置福利规则，每天到达设定时间，系统将自动发送福利红包。\n'
        '只有满足流水条件的玩家才能抢红包。\n'
        '💡 红包个数：设置可抢人数，每人抢到的金额随机分配。',
        style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.6),
      ),
    );
  }

  Widget _buildRuleCard(_WelfareRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 条件类型
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      '条件类型',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F2FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '当日流水（发包+抢包）',
                      style: TextStyle(fontSize: 13, color: Color(0xFF007AFF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInputRow(
                label: '达成金额',
                controller: rule.targetCtrl,
                placeholder: '例如 688',
                suffix: '元',
                isDecimal: true,
              ),
              const SizedBox(height: 10),
              _buildTimeRow(rule),
              const SizedBox(height: 10),
              _buildInputRow(
                label: '红包金额',
                controller: rule.bonusCtrl,
                placeholder: '例如 888',
                suffix: '元',
                isDecimal: true,
              ),
              const SizedBox(height: 10),
              _buildInputRow(
                label: '红包个数',
                controller: rule.numsCtrl,
                placeholder: '可抢人数',
                suffix: '个',
                width: 80,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      '状态',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _inputBg,
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: rule.status,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('启用')),
                            DropdownMenuItem(value: 0, child: Text('禁用')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => rule.status = v);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => _removeRule(rule),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: const Text(
                  '×',
                  style: TextStyle(
                    fontSize: 26,
                    color: Color(0xFFE02020),
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required String suffix,
    bool isDecimal = false,
    double? width,
  }) {
    final field = TextField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        isDecimal
            ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF007AFF)),
        ),
        hintText: placeholder,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
      ),
    );

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
          ),
        ),
        width != null
            ? SizedBox(width: width, child: field)
            : Expanded(child: field),
        const SizedBox(width: 8),
        Text(suffix, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ],
    );
  }

  Widget _buildExpandedInputRow({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required String suffix,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF007AFF)),
              ),
              hintText: placeholder,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(suffix, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
      ],
    );
  }

  Widget _buildTimeRow(_WelfareRule rule) {
    return Row(
      children: [
        const SizedBox(
          width: 60,
          child: Text(
            '触发时间',
            style: TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          width: 50,
          child: TextField(
            controller: rule.hourCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF007AFF)),
              ),
              hintText: '时',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
        ),
        SizedBox(
          width: 50,
          child: TextField(
            controller: rule.minuteCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF007AFF)),
              ),
              hintText: '分',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddBtn() {
    return GestureDetector(
      onTap: _addRule,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        alignment: Alignment.center,
        child: const Text(
          '＋ 新增福利',
          style: TextStyle(fontSize: 15, color: Color(0xFF007AFF), fontWeight: FontWeight.w600),
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
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _saving ? '保存中...' : '💾 保存所有规则',
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ================= 数据模型 =================
class _WelfareRule {
  final int id;
  final TextEditingController targetCtrl;
  final TextEditingController hourCtrl;
  final TextEditingController minuteCtrl;
  final TextEditingController bonusCtrl;
  final TextEditingController numsCtrl;
  int status;

  _WelfareRule({
    required this.id,
    required String targetAmount,
    required String hour,
    required String minute,
    required String bonusAmount,
    required String totalNums,
    required this.status,
  })  : targetCtrl = TextEditingController(text: targetAmount),
        hourCtrl = TextEditingController(text: hour),
        minuteCtrl = TextEditingController(text: minute),
        bonusCtrl = TextEditingController(text: bonusAmount),
        numsCtrl = TextEditingController(text: totalNums);

  factory _WelfareRule.fromJson(Map<String, dynamic> j) {
    return _WelfareRule(
      id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      targetAmount: _numStr(j['target_amount']),
      hour: _intStr(j['hour']),
      minute: _intStr(j['minute']),
      bonusAmount: _numStr(j['bonus_amount']),
      totalNums: _intStr(j['total_nums'], fallback: '1'),
      status: int.tryParse(j['status']?.toString() ?? '1') ?? 1,
    );
  }

  factory _WelfareRule.empty() {
    return _WelfareRule(
      id: 0,
      targetAmount: '',
      hour: '',
      minute: '',
      bonusAmount: '',
      totalNums: '1',
      status: 1,
    );
  }

  static String _numStr(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  static String _intStr(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final i = int.tryParse(v.toString());
    return i?.toString() ?? fallback;
  }

  void dispose() {
    targetCtrl.dispose();
    hourCtrl.dispose();
    minuteCtrl.dispose();
    bonusCtrl.dispose();
    numsCtrl.dispose();
  }
}