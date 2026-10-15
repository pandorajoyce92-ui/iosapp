import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 扫雷规则模型（原样保留）
class RoomRule {
  int nums;         // 7 / 8 / 9
  int boom;         // 1 / 2 / 3 / 4
  double multiplier; // 1.2 ~ 2.5

  RoomRule({required this.nums, required this.boom, required this.multiplier});

  factory RoomRule.fromJson(Map<String, dynamic> j) => RoomRule(
        nums: int.tryParse(j['nums'].toString()) ?? 7,
        boom: int.tryParse(j['boom'].toString()) ?? 1,
        multiplier: double.tryParse(j['multiplier'].toString()) ?? 1.2,
      );

  Map<String, dynamic> toJson() => {
        'nums': nums,
        'boom': boom,
        'multiplier': multiplier,
      };

  static const _boomLabels = ['', '单雷', '双雷', '三雷', '四雷'];
  String get boomLabel => (boom >= 1 && boom <= 4) ? _boomLabels[boom] : '';

  String get display => '$nums 包 · $boomLabel · ${_fmt(multiplier)} 倍';

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class RoomRulesPage extends StatefulWidget {
  final List<RoomRule> initial;
  const RoomRulesPage({super.key, this.initial = const []});

  @override
  State<RoomRulesPage> createState() => _RoomRulesPageState();
}

class _RoomRulesPageState extends State<RoomRulesPage> {
  late List<RoomRule> _rules;

  // ---- 统一风格常量（与 liuhecai_rule_page 保持一致）----
  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );
  static const Color _cardBg = Color(0xF2FFFFFF);
  static const Color _primaryBlue = Color(0xFF007AFF);
  static const Color _primaryBlueDark = Color(0xFF0060DF);
  static const Color _chipBg = Color(0x66DBEAFE); // #DBEAFE @ 40%
  static const Color _divider = Color(0xFFF0F0F4);
  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textTertiary = Color(0xFF999999);
  static const Color _danger = Color(0xFFE94848);
  static const Color _dangerBg = Color(0xFFFFF0F0);

  @override
  void initState() {
    super.initState();
    _rules = List<RoomRule>.from(widget.initial);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)),
    );
  }

  void _openEditor([int? index]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleEditorSheet(
        initial: index != null ? _rules[index] : null,
        onSave: (rule) {
          setState(() {
            if (index != null) {
              _rules[index] = rule;
            } else {
              _rules.add(rule);
            }
          });
          _toast(index != null ? '规则已更新' : '规则已添加');
        },
      ),
    );
  }

  void _remove(int index) {
    setState(() => _rules.removeAt(index));
    _toast('规则已删除');
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          '已添加玩法 ${_rules.length} 条',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_rules.isEmpty) _buildEmpty() else _buildList(),
                      const SizedBox(height: 12),
                      _buildAddBtn(),
                      const SizedBox(height: 12),
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
                child:
                    Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '扫雷玩法设置',
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

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text('🎯', style: TextStyle(fontSize: 36)),
          SizedBox(height: 10),
          Text(
            '暂无玩法规则\n点击下方「新增玩法」开始添加',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFBBBBBB),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_rules.length, (i) {
          final r = _rules[i];
          return Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: i < _rules.length - 1
                  ? const Border(bottom: BorderSide(color: _divider))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.display,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
                _btn('编辑', _chipBg, _primaryBlue, () => _openEditor(i)),
                const SizedBox(width: 6),
                _btn('删除', _dangerBg, _danger, () => _remove(i)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  // ---- 新增玩法按钮（蓝描边）----
  Widget _buildAddBtn() {
    return GestureDetector(
      onTap: () => _openEditor(),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          border: Border.all(color: _primaryBlue, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('＋',
                style: TextStyle(
                    fontSize: 20, color: _primaryBlue, height: 1)),
            SizedBox(width: 6),
            Text(
              '新增玩法',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 保存按钮（蓝渐变）----
  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(_rules),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryBlue, _primaryBlueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          '保存并返回',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ===== 底部弹窗：新增 / 编辑规则 =====
class _RuleEditorSheet extends StatefulWidget {
  final RoomRule? initial;
  final ValueChanged<RoomRule> onSave;

  const _RuleEditorSheet({this.initial, required this.onSave});

  @override
  State<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<_RuleEditorSheet> {
  late int _nums;
  late int _boom;
  late TextEditingController _multiplierCtrl;

  static const Color _primaryBlue = Color(0xFF007AFF);
  static const Color _primaryBlueDark = Color(0xFF0060DF);
  static const Color _chipBg = Color(0x66DBEAFE);
  static const Color _divider = Color(0xFFF0F0F4);
  static const Color _textPrimary = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _nums = r?.nums ?? 7;
    _boom = r?.boom ?? 1;
    _multiplierCtrl = TextEditingController(
      text: r != null ? RoomRule._fmt(r.multiplier) : '',
    );
  }

  @override
  void dispose() {
    _multiplierCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final m = double.tryParse(_multiplierCtrl.text.trim());
    if (m == null || m < 1.2 || m > 2.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('倍数必须在 1.2 到 2.5 之间'),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }
    final rule = RoomRule(
      nums: _nums,
      boom: _boom,
      multiplier: double.parse(m.toStringAsFixed(2)),
    );
    widget.onSave(rule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initial == null ? '新增玩法' : '编辑玩法',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _row(
              '包数',
              DropdownButton<int>(
                value: _nums,
                underline: const SizedBox.shrink(),
                isExpanded: true,
                alignment: Alignment.centerRight,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                items: const [7, 8, 9]
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child:
                            Text('$v 包', textAlign: TextAlign.right)))
                    .toList(),
                onChanged: (v) => setState(() => _nums = v ?? 7),
              ),
            ),
            _row(
              '雷数',
              DropdownButton<int>(
                value: _boom,
                underline: const SizedBox.shrink(),
                isExpanded: true,
                alignment: Alignment.centerRight,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                items: const [1, 2, 3, 4]
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(RoomRule._boomLabels[v],
                              textAlign: TextAlign.right),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _boom = v ?? 1),
              ),
            ),
            _row(
              '倍数',
              TextField(
                controller: _multiplierCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '1.2 ~ 2.5',
                  hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _confirm,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryBlue, _primaryBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withOpacity(0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Widget child) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}