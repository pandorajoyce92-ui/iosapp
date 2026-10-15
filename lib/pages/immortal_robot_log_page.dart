import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class ImmortalRobotLogPage extends StatefulWidget {
  final int roomid;
  const ImmortalRobotLogPage({super.key, required this.roomid});

  @override
  State<ImmortalRobotLogPage> createState() => _ImmortalRobotLogPageState();
}

class _ImmortalRobotLogPageState extends State<ImmortalRobotLogPage> {
  bool _loading = true;

  double _total = 0;
  double _welfareTotal = 0;
  double _profit = 0;
  List<Map<String, dynamic>> _list = [];

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

  Future<void> _load() async {
    try {
      final url = '${ApiConfig.immortalRobotLog}&op=get_data&roomid=${widget.roomid}';
      debugPrint('📥 [immortal_robot_log] GET $url');
      final res = await HttpClient.instance.dio.get(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      debugPrint('📥 [immortal_robot_log] 响应: $data');

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['list'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (mounted) {
          setState(() {
            _total = _toDouble(r['total']);
            _welfareTotal = _toDouble(r['welfare_total']);
            _profit = _toDouble(r['profit']);
            _list = list;
            _loading = false;
          });
        }
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [immortal_robot_log] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
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
              '免死机器人流水',
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
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildFilterBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _list.isEmpty ? _buildEmpty() : _buildList(),
          ),
        ],
      ),
    );
  }

  // ---- 顶部统计卡片 ----
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 今日抢包总额',
                style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
              ),
              Text(
                _fmtMoney(_total),
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE94848),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎁 福利奖励支出',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
              Text(
                _fmtMoney(_welfareTotal),
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💰 今日盈利',
                  style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                ),
                Text(
                  '${_profit >= 0 ? '+' : ''}${_fmtMoney(_profit)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _profit >= 0 ? const Color(0xFF34C759) : const Color(0xFFE94848),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Text('🤖', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            '今日暂无免死机器人流水记录',
            style: TextStyle(fontSize: 15, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '共 ${_list.length} 条记录',
            style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF)),
          ),
        ),
        ..._list.map(_buildRecordItem),
      ],
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> log) {
    final isboom = int.tryParse(log['isboom']?.toString() ?? '0') ?? 0;
    final moneyDisplay = _fmtMoney(_toDouble(log['money_display'] ?? log['money']));
    final addtime = int.tryParse(log['addtime']?.toString() ?? '0') ?? 0;
    final timeStr = _fmtDateTime(addtime);
    final boomnums = log['boomnums']?.toString() ?? '';
    final remark = log['remark']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部：状态徽标 + 金额
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isboom == 1
                          ? const Color(0xFFFCE8E8)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isboom == 1 ? '💣 中雷' : '✅ 正常',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isboom == 1
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '+$moneyDisplay 元',
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE94848),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 时间 + 尾数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '时间：$timeStr',
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  children: [
                    const TextSpan(text: '尾数：'),
                    TextSpan(
                      text: boomnums,
                      style: const TextStyle(
                        color: Color(0xFF333333), fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 备注
          if (remark.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                remark,
                style: const TextStyle(
                  fontSize: 13, color: Color(0xFF666666), height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  String _fmtDateTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}