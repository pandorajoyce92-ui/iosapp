import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiRedlogPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiRedlogPage({super.key, required this.roomid});

  @override
  State<LiuhecaiRedlogPage> createState() => _LiuhecaiRedlogPageState();
}

class _LiuhecaiRedlogPageState extends State<LiuhecaiRedlogPage> {
  bool _loading = true;

  String _asset = '0.00';
  String _todayWin = '0.00';

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  String _currentType = '';
  String _currentTypeLabel = '';

  List<Map<String, dynamic>> _records = [];
  double _typeTotal = 0;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<Map<String, String>> _availableTypes = [];

  final ScrollController _scrollCtrl = ScrollController();

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
  static const Color _textSecondary = Color(0xFF666666);
  static const Color _textTertiary = Color(0xFF999999);
  static const Color _amountRed = Color(0xFFE94848);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadAvailableTypes();
    await Future.wait([
      _loadAsset(),
      _loadTodayWin(),
    ]);
    if (_currentType.isNotEmpty) {
      await _loadRecords(reset: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ============ 获取可选类型 ============
  Future<void> _loadAvailableTypes() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRedlog}&op=get_available_types&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List).map((e) {
          final m = Map<String, dynamic>.from(e);
          return {
            'key': m['key']?.toString() ?? '',
            'name': m['name']?.toString() ?? '',
          };
        }).toList();
        if (mounted) {
          setState(() {
            _availableTypes = list;
            if (list.isNotEmpty) {
              _currentType = list.first['key']!;
              _currentTypeLabel = list.first['name']!;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_redlog get_available_types] $e');
    }
  }

  // ============ 资产 ============
  Future<void> _loadAsset() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRedlog}&op=get_asset&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        if (mounted) {
          setState(() => _asset = data['result']?.toString() ?? '0.00');
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_redlog get_asset] $e');
    }
  }

  // ============ 今日输赢 ============
  Future<void> _loadTodayWin() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRedlog}&op=today_win&date=${_fmtDate(_startDate)}&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        if (mounted) {
          setState(() => _todayWin = data['result']?.toString() ?? '0.00');
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_redlog today_win] $e');
    }
  }

  // ============ 明细列表 ============
  Future<void> _loadRecords({bool reset = false}) async {
    if (_isLoadingMore) return;
    if (_currentType.isEmpty) return;
    final targetPage = reset ? 1 : _currentPage + 1;

    setState(() => _isLoadingMore = true);

    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRedlog}'
        '&op=get_list'
        '&type=$_currentType'
        '&start_date=${_fmtDate(_startDate)}'
        '&end_date=${_fmtDate(_endDate)}'
        '&page=$targetPage'
        '&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final rawList = (result['list'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final pagesize = _toInt(result['pagesize'], 20);
        final total = _toDouble(result['total']);

        if (mounted) {
          setState(() {
            if (reset) _records.clear();
            _records.addAll(rawList);
            _currentPage = targetPage;
            _typeTotal = total;
            _hasMore = rawList.length >= pagesize;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_redlog get_list] $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_isLoadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100) {
      _loadRecords();
    }
  }

  // ============ 工具 ============
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _toInt(dynamic v, int def) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? def;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
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

  // ============ 日期选择 ============
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(picked)) _startDate = picked;
      }
    });
    await Future.wait([
      _loadTodayWin(),
      _loadRecords(reset: true),
    ]);
  }

  // ============ 切换类型 ============
  Future<void> _openTypeSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TypeSheet(
        types: _availableTypes,
        currentKey: _currentType,
        onPick: (t) {
          Navigator.of(context).pop();
          if (t['key'] == _currentType) return;
          setState(() {
            _currentType = t['key']!;
            _currentTypeLabel = t['name']!;
          });
          _loadRecords(reset: true);
        },
      ),
    );
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
              '账单明细',
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
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        _buildAssetPanel(),
        const SizedBox(height: 12),
        _buildFilterCard(),
        const SizedBox(height: 12),
        _buildSummaryRow(),
        const SizedBox(height: 8),
        _buildRecordCard(),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (!_hasMore && _records.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '已经加载完全部记录',
                style: TextStyle(fontSize: 12, color: _textTertiary),
              ),
            ),
          ),
      ],
    );
  }

  // ---- 资产面板（蓝色渐变，呼应主色）----
  Widget _buildAssetPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryBlue, _primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '账户总资产 (元)',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            _asset,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 筛选卡片 ----
  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    _buildDateBtn(_startDate, () => _pickDate(isStart: true)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('至',
                    style: TextStyle(fontSize: 13, color: _textTertiary)),
              ),
              Expanded(
                child:
                    _buildDateBtn(_endDate, () => _pickDate(isStart: false)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      '今日输赢',
                      style: TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _todayWin,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _amountRed,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _openTypeSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '切换类型 ▾',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBtn(DateTime d, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDBEAFE)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          _fmtDate(d),
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
      ),
    );
  }

  // ---- 摘要行 ----
  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _currentTypeLabel,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              children: [
                const TextSpan(text: '区间累积: '),
                TextSpan(
                  text: _typeTotal.toStringAsFixed(2),
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 记录列表 ----
  Widget _buildRecordCard() {
    if (_records.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: const Text(
          '暂无明细记录',
          style: TextStyle(fontSize: 13, color: _textTertiary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_records.length, (i) {
          final item = _records[i];
          final isLast = i == _records.length - 1;
          return _buildRecordItem(item, isLast: isLast);
        }),
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> item, {required bool isLast}) {
    final isSummary = _toInt(item['is_summary'], 0) == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: _divider)),
            ),
      child: isSummary ? _buildSummaryItem(item) : _buildNormalItem(item),
    );
  }

  Widget _buildSummaryItem(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final recharge = _toDouble(item['recharge']);
    final withdraw = _toDouble(item['withdraw']);
    final time = item['time']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '充值合计 ${recharge.toStringAsFixed(2)} 元',
          style: const TextStyle(
            fontSize: 13,
            color: _amountRed,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '提现合计 ${withdraw.toStringAsFixed(2)} 元',
          style: const TextStyle(fontSize: 12, color: _textTertiary),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
        ),
      ],
    );
  }

  Widget _buildNormalItem(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final time = item['time']?.toString() ?? '';
    final amount = _toDouble(item['amount']);
    final noSign = _toInt(item['no_sign'], 0) == 1;
    final isNeg = amount < 0;

    final sign = noSign ? '' : (isNeg ? '-' : '+');
    final display = amount.abs().toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: _textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$sign$display',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _amountRed,
          ),
        ),
      ],
    );
  }
}

// ===================== 切换类型弹窗 =====================
class _TypeSheet extends StatelessWidget {
  final List<Map<String, String>> types;
  final String currentKey;
  final ValueChanged<Map<String, String>> onPick;

  const _TypeSheet({
    required this.types,
    required this.currentKey,
    required this.onPick,
  });

  static const Color _primaryBlue = Color(0xFF007AFF);
  static const Color _chipBg = Color(0x66DBEAFE);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
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
          const Text(
            '选择交易类型',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: types.map((t) {
              final active = t['key'] == currentKey;
              return GestureDetector(
                onTap: () => onPick(t),
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? _chipBg : const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t['name'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? _primaryBlue
                          : const Color(0xFF333333),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              height: 46,
              width: double.infinity,
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
        ],
      ),
    );
  }
}