import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

/// 佣金列表
class ServantPage extends StatefulWidget {
  const ServantPage({super.key});

  @override
  State<ServantPage> createState() => _ServantPageState();
}

class _ServantPageState extends State<ServantPage> {
  bool _loadingSummary = true;
  String _weekProfit = '0.00';
  String _dayProfit = '0.00';

  final List<_ServantLog> _logs = [];
  int _page = 1;
  static const _pageSize = 20;
  bool _loadingMore = false;
  bool _hasMore = true;

  final ScrollController _scrollCtrl = ScrollController();

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _itemBg = Color(0xF2FFFFFF);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadSummary();
    _loadLogs(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_loadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadLogs();
    }
  }

  Future<void> _loadSummary() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.servant}&op=summary',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        if (mounted) {
          setState(() {
            _weekProfit = result['weekProfit']?.toString() ?? '0.00';
            _dayProfit = result['dayProfit']?.toString() ?? '0.00';
            _loadingSummary = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingSummary = false);
      }
    } catch (e) {
      debugPrint('❌ [servant summary] $e');
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (_loadingMore || (!reset && !_hasMore)) return;

    setState(() => _loadingMore = true);
    final targetPage = reset ? 1 : _page + 1;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.servant}&op=display&page=$targetPage',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final list = (result['list'] as List? ?? [])
            .map((e) => _ServantLog.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final pagesize = int.tryParse(result['pagesize']?.toString() ?? '20') ?? 20;

        if (mounted) {
          setState(() {
            if (reset) _logs.clear();
            _logs.addAll(list);
            _page = targetPage;
            _hasMore = list.length >= pagesize;
            _loadingMore = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingMore = false);
      }
    } catch (e) {
      debugPrint('❌ [servant display] $e');
      if (mounted) setState(() => _loadingMore = false);
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
              _buildTopBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadSummary();
                    await _loadLogs(reset: true);
                  },
                  color: const Color(0xFF007AFF),
                  child: ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                    children: [
                      _sectionTitle('收益概览'),
                      _buildProfitCard(),
                      const SizedBox(height: 16),
                      _sectionTitle('明细记录'),
                      _buildLogCard(),
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

  Widget _buildTopBar() {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '佣金列表',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 12, color: Color(0xFF5B48B8), fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _buildProfitCard() {
    return Container(
      decoration: BoxDecoration(
        color: _itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: _loadingSummary
          ? const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Row(
              children: [
                _profitItem('本周收益(元)', _weekProfit),
                _profitItem('今日收益(元)', _dayProfit, isLast: true),
              ],
            ),
    );
  }

  Widget _profitItem(String label, String value, {bool isLast = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(right: BorderSide(color: Color(0xFFF0F0F4))),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFE94848),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Container(
      decoration: BoxDecoration(
        color: _itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildLogHeader(),
          if (_logs.isEmpty && !_loadingMore)
            _buildEmpty()
          else
            ...List.generate(_logs.length, (i) {
              return _buildLogRow(_logs[i], isLast: i == _logs.length - 1 && !_hasMore);
            }),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (!_hasMore && _logs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  '已经加载完全部记录',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogHeader() {
    return Container(
      color: const Color(0xFFEFEFF4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: const [
          Expanded(child: Text('ID', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(child: Text('佣金', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(child: Text('详情', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(child: Text('时间', textAlign: TextAlign.center, style: _headerStyle)),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666),
  );

  Widget _buildLogRow(_ServantLog log, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text('${log.setuid}', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111111))),
          ),
          Expanded(
            child: Text(log.gold, textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w600,
                )),
          ),
          Expanded(
            child: Text(
              log.type == '0' ? '抢包返佣' : '发包返佣',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF111111)),
            ),
          ),
          Expanded(
            child: Text(log.addtime, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999), height: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.description_outlined, size: 48, color: Color(0xFFE0E0E0)),
          SizedBox(height: 12),
          Text('暂时没有任何记录',
              style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB))),
        ],
      ),
    );
  }
}

class _ServantLog {
  final String setuid;
  final String gold;
  final String type;
  final String addtime;

  _ServantLog({
    required this.setuid,
    required this.gold,
    required this.type,
    required this.addtime,
  });

  factory _ServantLog.fromJson(Map<String, dynamic> j) => _ServantLog(
        setuid: j['setuid']?.toString() ?? '',
        gold: j['gold']?.toString() ?? '0',
        type: j['type']?.toString() ?? '0',
        addtime: j['addtime']?.toString() ?? '',
      );
}