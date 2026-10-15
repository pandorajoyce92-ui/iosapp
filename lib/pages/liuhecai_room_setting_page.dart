import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiRoomSettingPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiRoomSettingPage({super.key, required this.roomid});

  @override
  State<LiuhecaiRoomSettingPage> createState() =>
      _LiuhecaiRoomSettingPageState();
}

class _LiuhecaiRoomSettingPageState
    extends State<LiuhecaiRoomSettingPage> {
  bool _loading = true;
  bool _saving = false;

  // 包数：5 / 7 / 9
  int _packetNums = 7;

  // 开奖红包金额
  final _redMoneyCtrl = TextEditingController();

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
    _redMoneyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRoomSetting}&act=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final nums = int.tryParse(r['minnums']?.toString() ?? '7') ?? 7;
        // 只接受 5/7/9，其它值兜底为 7
        final valid = [5, 7, 9];
        if (mounted) {
          setState(() {
            _packetNums = valid.contains(nums) ? nums : 7;
            _redMoneyCtrl.text = _fmtNum(r['min']);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_room_setting get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '';
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
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final moneyStr = _redMoneyCtrl.text.trim();
    final money = double.tryParse(moneyStr);
    if (money == null || money <= 0) {
      _toast('请正确填写开奖红包金额（正数）');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiRoomSetting}&act=save&roomid=${widget.roomid}',
        data: {
          'act': 'save',
          'red_money': moneyStr,
          'packet_nums': _packetNums,
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
        final msg = data is Map
            ? (data['result']?.toString() ?? '保存失败')
            : '保存失败';
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_room_setting save] $e');
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
              '群设置',
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
          _buildCard(),
          const SizedBox(height: 12),
          _buildSaveBtn(),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildPacketNumsRow(),
          _buildRedMoneyRow(),
        ],
      ),
    );
  }

  // ---- 发包包数（下拉） ----
  Widget _buildPacketNumsRow() {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              '发包包数',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _packetNums,
                isExpanded: true,
                alignment: Alignment.centerRight,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF999999),
                  size: 18,
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5包', textAlign: TextAlign.right)),
                  DropdownMenuItem(value: 7, child: Text('7包', textAlign: TextAlign.right)),
                  DropdownMenuItem(value: 9, child: Text('9包', textAlign: TextAlign.right)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _packetNums = v);
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '固定',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  // ---- 开奖红包金额 ----
  Widget _buildRedMoneyRow() {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              '开奖红包金额',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _redMoneyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '请输入固定金额',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '元',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
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
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _saving ? '保存中...' : '保存设置',
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