import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiRebateSettingPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiRebateSettingPage({super.key, required this.roomid});

  @override
  State<LiuhecaiRebateSettingPage> createState() =>
      _LiuhecaiRebateSettingPageState();
}

class _LiuhecaiRebateSettingPageState
    extends State<LiuhecaiRebateSettingPage> {
  bool _loading = true;
  bool _saving = false;

  final _sendCtrl = TextEditingController();
  final _getCtrl = TextEditingController();

  String _lastSettleDate = '尚未结算';

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
  static const Color _saveGreen = Color(0xFF07C160);
  static const Color _textPrimary = Color(0xFF222222);
  static const Color _textSecondary = Color(0xFF888888);
  static const Color _textTertiary = Color(0xFF999999);
  static const Color _divider = Color(0xFFF4F4F5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sendCtrl.dispose();
    _getCtrl.dispose();
    super.dispose();
  }

  // ==================== 逻辑区（保持不变）====================

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRebateSetting}&op=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        if (mounted) {
          setState(() {
            _sendCtrl.text = _fmt(r['send_rebate']);
            _getCtrl.text = _fmt(r['get_rebate']);
            _lastSettleDate =
                r['last_settle_date']?.toString() ?? '尚未结算';
            _loading = false;
          });
        }
      } else {
        final msg =
            data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_rebate_setting get_data] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  bool get _isEnabled {
    final s = double.tryParse(_sendCtrl.text) ?? 0;
    final g = double.tryParse(_getCtrl.text) ?? 0;
    return s > 0 || g > 0;
  }

  Future<void> _save() async {
    if (_saving) return;

    final send = double.tryParse(_sendCtrl.text) ?? 0;
    final get = double.tryParse(_getCtrl.text) ?? 0;

    if (send < 0 || send > 100) {
      _toast('发包返利比例必须在 0-100 之间');
      return;
    }
    if (get < 0 || get > 100) {
      _toast('抢包返利比例必须在 0-100 之间');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiRebateSetting}&act=save&roomid=${widget.roomid}',
        data: {
          'act': 'save',
          'roomid': widget.roomid,
          'send_rebate': send,
          'get_rebate': get,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast(data['result']?.toString() ?? '保存成功');
      } else {
        _toast(data is Map
            ? (data['msg']?.toString() ??
                data['result']?.toString() ??
                '保存失败')
            : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_rebate_setting save] $e');
      _toast('网络错误，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ==================== UI 区（重写）====================

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
                child:
                    Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '返点设置',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigCard(),
          const SizedBox(height: 12),
          _buildInfoBox(),
          const SizedBox(height: 16),
          _buildSaveBtn(),
        ],
      ),
    );
  }

  // ---- 配置卡片 ----
  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题 + 当前房间标签
          Row(
            children: [
              const Text(
                '返利比例配置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '当前房间',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInputRow(label: '📤 发包流水返利', controller: _sendCtrl),
          _buildInputRow(
            label: '📥 抢包流水返利',
            controller: _getCtrl,
            isLast: true,
          ),

          // 状态区
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📅 上次结算日期',
                      style:
                          TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    Text(
                      _lastSettleDate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚙️ 当前状态',
                      style:
                          TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    Text(
                      _isEnabled ? '✅ 已启用' : '❌ 未启用（比例均为0%）',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isEnabled ? _saveGreen : _textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Container(
            width: 80,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDBEAFE)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
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
          const Text(
            '%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 说明卡片 ----
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.8,
              ),
              children: [
                TextSpan(text: '💡 '),
                TextSpan(
                  text: '说明：',
                  style: TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _line('• 返利基于玩家', '当日', '的发包/抢包', '总流水', '计算'),
          _line3('• 每日 ', '00:00', ' 系统自动结算并发放到玩家余额',
              isRed: true),
          _line2('• 设置为 ', '0%', ' 表示不返利', isHighlight: true),
          _line3('• 返利金额 = 当日流水 × 返利比例（', '向下取整到分', '）',
              isHighlight: true),
        ],
      ),
    );
  }

  Widget _line(String a, String b, String c, String d, String e) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          height: 1.8,
        ),
        children: [
          TextSpan(text: a),
          TextSpan(
            text: b,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          TextSpan(text: c),
          TextSpan(
            text: d,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          TextSpan(text: e),
        ],
      ),
    );
  }

  Widget _line2(String a, String b, String c, {bool isHighlight = false}) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          height: 1.8,
        ),
        children: [
          TextSpan(text: a),
          TextSpan(
            text: b,
            style: TextStyle(
              color: isHighlight ? _primaryBlue : const Color(0xFF333333),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: c),
        ],
      ),
    );
  }

  Widget _line3(String a, String b, String c,
      {bool isRed = false, bool isHighlight = false}) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          height: 1.8,
        ),
        children: [
          TextSpan(text: a),
          TextSpan(
            text: b,
            style: TextStyle(
              color: isRed
                  ? const Color(0xFFE94848)
                  : (isHighlight ? _primaryBlue : const Color(0xFF333333)),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: c),
        ],
      ),
    );
  }

  // ---- 保存按钮（蓝色渐变，与参考页主操作风格一致）----
  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Opacity(
        opacity: _saving ? 0.6 : 1,
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
          child: Text(
            _saving ? '保存中...' : '💾 保存设置',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}