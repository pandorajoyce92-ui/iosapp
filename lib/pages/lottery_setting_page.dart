import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LotterySettingPage extends StatefulWidget {
  final int roomid;
  const LotterySettingPage({super.key, required this.roomid});

  @override
  State<LotterySettingPage> createState() => _LotterySettingPageState();
}

class _LotterySettingPageState extends State<LotterySettingPage> {
  bool _loading = true;
  bool _saving = false;

  final _thresholdCtrl = TextEditingController();
  final List<TextEditingController> _prizeCtrls = List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _weightCtrls = List.generate(6, (_) => TextEditingController());

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
    _thresholdCtrl.dispose();
    for (final c in _prizeCtrls) {
      c.dispose();
    }
    for (final c in _weightCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final url = '${ApiConfig.baseUrl}/app/index.php'
          '?i=1&c=entry&do=member&m=sz_yi'
          '&p=sailei_room_info'
          '&act=lottery_setting'
          '&op=get_data'
          '&roomid=${widget.roomid}';
      debugPrint('📥 [lottery_setting] GET $url');
      final res = await HttpClient.instance.dio.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      debugPrint('📥 [lottery_setting] 响应: ${res.data}');
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final threshold = r['threshold']?.toString() ?? '1000';
        final prizes = (r['prizes'] as List? ?? []).map((e) => _numStr(e)).toList();
        final weights = (r['weights'] as List? ?? []).map((e) => _intStr(e)).toList();

        if (mounted) {
          setState(() {
            _thresholdCtrl.text = threshold;
            for (int i = 0; i < 6; i++) {
              _prizeCtrls[i].text = i < prizes.length ? prizes[i] : '';
              _weightCtrls[i].text = i < weights.length ? weights[i] : '';
            }
            _loading = false;
          });
        }
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [lottery_setting get_data] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
  }

  String _numStr(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  String _intStr(dynamic v) {
    if (v == null) return '';
    final i = int.tryParse(v.toString());
    return i?.toString() ?? v.toString();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final thresholdStr = _thresholdCtrl.text.trim();
    if (thresholdStr.isEmpty) {
      _toast('请填写流水门槛');
      return;
    }
    final threshold = int.tryParse(thresholdStr);
    if (threshold == null || threshold <= 0) {
      _toast('流水门槛必须大于0');
      return;
    }

    for (int i = 0; i < 6; i++) {
      final prizeStr = _prizeCtrls[i].text.trim();
      final weightStr = _weightCtrls[i].text.trim();

      if (prizeStr.isEmpty || weightStr.isEmpty) {
        _toast('请填写完整所有奖项');
        return;
      }
      final prize = double.tryParse(prizeStr);
      if (prize == null || prize <= 0) {
        _toast('奖项 ${i + 1} 金额必须大于0');
        return;
      }
      final weight = int.tryParse(weightStr);
      if (weight == null || weight <= 0) {
        _toast('奖项 ${i + 1} 权重必须大于0');
        return;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确定保存幸运抽奖设置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'threshold': thresholdStr,
        'roomid': widget.roomid,
        'act': 'lottery_setting',
      };
      for (int i = 0; i < 6; i++) {
        data['prize[$i]'] = _prizeCtrls[i].text.trim();
        data['weight[$i]'] = _weightCtrls[i].text.trim();
      }

      final url = '${ApiConfig.baseUrl}/app/index.php'
          '?i=1&c=entry&do=member&m=sz_yi'
          '&p=sailei_room_info'
          '&act=lottery_setting'
          '&roomid=${widget.roomid}';
      debugPrint('📤 [lottery_setting] POST $url');
      final res = await HttpClient.instance.dio.post(
        url,
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
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _toast(r is Map ? (r['result']?.toString() ?? '保存失败') : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [lottery_setting save] $e');
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
              '幸运抽奖设置',
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildThresholdCard(),
          const SizedBox(height: 16),
          _buildPrizesCard(),
          const SizedBox(height: 16),
          _buildSaveBtn(),
        ],
      ),
    );
  }

  // ---- 卡片 1：流水门槛 ----
  Widget _buildThresholdCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '抽奖流水门槛',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _thresholdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '请输入流水门槛',
                      hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB), fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
                const Text(
                  '元',
                  style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '* 用户发包+抢包总流水达到此金额，即可获1次抽奖机会',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---- 卡片 2：奖品金额 & 权重 ----
  Widget _buildPrizesCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                const Text(
                  '奖品金额 & 概率权重',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
                ),
                const SizedBox(width: 6),
                Text(
                  '(数值越大概率越高)',
                  style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          for (int i = 0; i < 6; i++) _buildPrizeRow(i),
        ],
      ),
    );
  }

  Widget _buildPrizeRow(int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: index < 5
            ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F2FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '奖项 ${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSmallField(
                  prefix: '金额',
                  controller: _prizeCtrls[index],
                  suffix: '元',
                  isDecimal: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallField(
                  prefix: '权重',
                  controller: _weightCtrls[index],
                  suffix: null,
                  isDecimal: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField({
    required String prefix,
    required TextEditingController controller,
    required String? suffix,
    required bool isDecimal,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Text(
            prefix,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                isDecimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    : FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '',
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(
              suffix,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Opacity(
        opacity: _saving ? 0.6 : 1,
        child: Container(
          height: 50,
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
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _saving ? '保存中...' : '保存设置',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}