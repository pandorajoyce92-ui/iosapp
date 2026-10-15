import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class RoomTransactionsPage extends StatefulWidget {
  final int roomid;
  const RoomTransactionsPage({super.key, required this.roomid});

  @override
  State<RoomTransactionsPage> createState() => _RoomTransactionsPageState();
}

class _RoomTransactionsPageState extends State<RoomTransactionsPage> {
  bool _loading = true;

  String _timeFilter = '';
  String _typeFilter = '';
  final _playerIdCtrl = TextEditingController();

  List<Map<String, dynamic>> _list = [];

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
    _playerIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qp = <String, String>{
        'act': 'transactions',
        'op': 'get_data',
        'roomid': widget.roomid.toString(),
      };
      if (_timeFilter.isNotEmpty) qp['time_filter'] = _timeFilter;
      if (_typeFilter.isNotEmpty) qp['type'] = _typeFilter;
      final pid = _playerIdCtrl.text.trim();
      if (pid.isNotEmpty) qp['player_id'] = pid;

      final query = qp.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = '${ApiConfig.saileiRoomInfo}&$query';
      debugPrint('📥 [transactions] GET $url');

      final res = await HttpClient.instance.dio.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      debugPrint('📥 [transactions] 响应: $data');

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['list'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) {
          setState(() {
            _list = list;
            _loading = false;
          });
        }
      } else {
        final msg = data is Map
            ? (data['result']?.toString() ?? '加载失败')
            : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [transactions] $e');
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
              '充值/提现详情',
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
          _buildSearchBox(),
          const SizedBox(height: 12),
          _buildRecordList(),
        ],
      ),
    );
  }

  // ---- 搜索栏 ----
  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _timeFilter,
                  items: const [
                    MapEntry('', '全部时间'),
                    MapEntry('today', '今天'),
                    MapEntry('week', '本周'),
                    MapEntry('month', '本月'),
                  ],
                  onChanged: (v) => setState(() => _timeFilter = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  value: _typeFilter,
                  items: const [
                    MapEntry('', '全部类型'),
                    MapEntry('recharge', '充值记录'),
                    MapEntry('withdraw', '提现记录'),
                  ],
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _inputBg,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _playerIdCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '搜索玩家ID',
                hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 检索按钮（蓝渐变）
          GestureDetector(
            onTap: _load,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '检索',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<MapEntry<String, String>> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _inputBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF999999), size: 18),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  // ---- 记录列表 ----
  Widget _buildRecordList() {
    if (_list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: _cardDecoration(),
        alignment: Alignment.center,
        child: const Text(
          '暂无相关充值 / 提现记录',
          style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_list.length, (i) {
          return _buildRecordItem(_list[i], isLast: i == _list.length - 1);
        }),
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> item, {required bool isLast}) {
    final type = item['type']?.toString() ?? '';
    final statusText = item['status_text']?.toString() ?? '';
    final amount = _numStr(item['amount']);
    final applyTime = item['apply_time_formatted']?.toString() ?? '';
    final playerNick = item['player_nick']?.toString() ?? '';
    final uid = item['uid']?.toString() ?? '';
    final operatorNick = item['operator_nick']?.toString() ?? '';

    final isRecharge = type == '充值';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
              ),
              _buildStatusBadge(statusText),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isRecharge ? '+' : '-'}$amount 元',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isRecharge ? const Color(0xFF28A745) : const Color(0xFFDC3545),
                ),
              ),
              Text(
                applyTime,
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    children: [
                      const TextSpan(text: '玩家：'),
                      TextSpan(
                        text: playerNick,
                        style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: ' (ID:$uid)'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    children: [
                      const TextSpan(text: '操作者：'),
                      TextSpan(
                        text: operatorNick,
                        style: const TextStyle(color: Color(0xFF007AFF)),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String statusText) {
    Color bg;
    Color fg;
    if (statusText == '待处理') {
      bg = const Color(0xFFFFF3CD);
      fg = const Color(0xFF856404);
    } else if (statusText == '已同意') {
      bg = const Color(0xFFD4EDDA);
      fg = const Color(0xFF155724);
    } else if (statusText == '已拒绝') {
      bg = const Color(0xFFF8D7DA);
      fg = const Color(0xFF721C24);
    } else {
      bg = const Color(0xFFEEEEEE);
      fg = const Color(0xFF666666);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(12),
    );
  }

  String _numStr(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d.toStringAsFixed(2);
  }
}