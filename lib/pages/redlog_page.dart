import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';
import '../models/summary_card_data.dart';
import '../widgets/summary_card_widget.dart';
import '../pages/member_summary_page.dart';

// ===================== 数据模型 =====================
class _Roles {
  final bool isOwner;
  final bool isShareholder;
  final bool isAgent;
  final bool isFinance;

  const _Roles({
    this.isOwner = false,
    this.isShareholder = false,
    this.isAgent = false,
    this.isFinance = false,
  });

  factory _Roles.fromJson(Map<String, dynamic> j) => _Roles(
        isOwner: _truthy(j['is_owner']),
        isShareholder: _truthy(j['is_shareholder']),
        isAgent: _truthy(j['is_agent']),
        isFinance: _truthy(j['is_finance']),
      );

  static bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true';
  }
}

class _BillType {
  final String key;
  final String label;
  const _BillType(this.key, this.label);
}

// ===================== 页面 =====================

class RedlogPage extends StatefulWidget {
  final int roomid;
  const RedlogPage({super.key, this.roomid = 0});

  @override
  State<RedlogPage> createState() => _RedlogPageState();
}

class _RedlogPageState extends State<RedlogPage> {
  bool _loading = true;

  String _asset = '0.00';
  String _todayWin = '0.00';

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // ★★★ 默认显示“汇总卡片” ★★★
  String _currentType = 'card_summary';
  String _currentTypeLabel = '汇总卡片';

  // ===== 明细视图的变量（保留原有逻辑） =====
  final List<Map<String, dynamic>> _records = [];
  double _typeTotal = 0;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isRefreshing = false;

  // ===== 卡片视图的变量 =====
  List<SummaryCardData> _cards = [];
  SummaryCardData? _myCard;

  _Roles _roles = const _Roles();
  List<_BillType> _availableTypes = const [];

  final ScrollController _scrollCtrl = ScrollController();

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
    await _loadRoles();
    await Future.wait([
      _loadAsset(),
      _loadTodayWin(),
      _loadCards(), // 默认加载卡片
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRoles() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}&op=get_roles&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
            dynamic data = res.data;
            if (data is String) {
              // ★★★ 找到第一个 { 或 [ 的位置，截断前面的垃圾字符（如 PHP Warning）★★★
              final idxBrace = data.indexOf('{');
              final idxBracket = data.indexOf('[');
              int cutFrom = -1;
              if (idxBrace >= 0 && idxBracket >= 0) {
                cutFrom = idxBrace < idxBracket ? idxBrace : idxBracket;
              } else if (idxBrace >= 0) {
                cutFrom = idxBrace;
              } else if (idxBracket >= 0) {
                cutFrom = idxBracket;
              }
              if (cutFrom > 0) {
                data = data.substring(cutFrom);
              }
              try {
                data = jsonDecode(data);
              } catch (e) {
                debugPrint('❌ [redlog get_card_summary] jsonDecode 失败: $e');
              }
            }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        _roles = _Roles.fromJson(Map<String, dynamic>.from(data['result']));
      }
    } catch (e) {
      debugPrint('❌ [redlog get_roles] $e');
    }
    if (mounted) {
      setState(() => _availableTypes = _buildAvailableTypes(_roles));
    }
  }

  List<_BillType> _buildAvailableTypes(_Roles r) {
    final list = <_BillType>[
      // ★★★ 新增：汇总卡片类型放在最前面，作为默认 ★★★
      const _BillType('card_summary', '汇总卡片'),
      const _BillType('recharge', '充值明细'),
      const _BillType('withdraw', '提现明细'),
      const _BillType('daily_fee', '当日包费'),
      const _BillType('hongbao_reward', '红包奖励'),
      const _BillType('hongbao_receive', '红包领取'),
      const _BillType('recommend_rebate', '推荐返点'),
      const _BillType('zhonglei_deduct', '中雷扣除'),
      const _BillType('zhonglei_return', '中雷返'),
      const _BillType('recommend_award', '推荐奖励'),
      const _BillType('player_rebate', '玩家返点'),
      const _BillType('system_rebate', '系统返利'),
    ];
    if (r.isAgent || r.isOwner) {
      list.add(const _BillType('agent_rebate', '代理流水'));
    }
    if (r.isShareholder || r.isOwner) {
      list.add(const _BillType('shareholder_dividend', '股东流水'));
    }
    if (r.isShareholder || r.isOwner || r.isFinance) {
      list.add(const _BillType('downline_recharge', '玩家充值'));
      list.add(const _BillType('downline_withdraw', '玩家提现'));
    }
    if (r.isOwner || r.isFinance) {
      list.add(const _BillType('shareholder_summary', '股东明细'));
    }
    return list;
  }

  Future<void> _loadAsset() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}&op=get_asset&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        if (mounted) setState(() => _asset = data['result']?.toString() ?? '0.00');
      }
    } catch (e) {
      debugPrint('❌ [redlog get_asset] $e');
    }
  }

  Future<void> _loadTodayWin() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}&op=today_win&date=${_fmtDate(_startDate)}&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        if (mounted) setState(() => _todayWin = data['result']?.toString() ?? '0.00');
      }
    } catch (e) {
      debugPrint('❌ [redlog today_win] $e');
    }
  }

  // ★★★ 新增：加载卡片数据 ★★★
  Future<void> _loadCards() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}&op=get_card_summary&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final myCard = result['my_card'] != null
            ? SummaryCardData.fromJson(Map<String, dynamic>.from(result['my_card']))
            : null;
        final List rawList = result['child_cards'] ?? [];
        final cards = rawList
            .map((e) => SummaryCardData.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _myCard = myCard;
            _cards = cards;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [redlog get_card_summary] $e');
    }
  }

  // ★★★ 保留原有：加载明细列表 ★★★
  Future<void> _loadRecords({bool reset = false}) async {
    if (_isLoadingMore) return;
    final targetPage = reset ? 1 : _currentPage + 1;

    setState(() => _isLoadingMore = true);

    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.redlog}'
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
        try { data = jsonDecode(data); } catch (_) {}
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
      debugPrint('❌ [redlog get_list] $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _isRefreshing = true);
    if (_currentType == 'card_summary') {
      await Future.wait([
        _loadTodayWin(),
        _loadCards(),
      ]);
    } else {
      await Future.wait([
        _loadTodayWin(),
        _loadRecords(reset: true),
      ]);
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    // 卡片视图无需分页加载
    if (_currentType == 'card_summary') return;
    if (_isLoadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100) {
      _loadRecords();
    }
  }

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

  Future<void> _openTypeSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => _TypeSheet(
        types: _availableTypes,
        currentKey: _currentType,
        onPick: (t) {
          Navigator.of(context).pop();
          if (t.key == _currentType) return;
          setState(() {
            _currentType = t.key;
            _currentTypeLabel = t.label;
            if (t.key != 'card_summary') {
              // 切换到明细视图，清空记录
              _records.clear();
              _currentPage = 1;
              _hasMore = true;
              _typeTotal = 0;
            }
          });
          if (t.key == 'card_summary') {
            _loadCards();
          } else {
            _loadRecords(reset: true);
          }
        },
      ),
    );
  }

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
    await _reload();
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        children: [
                          _buildAssetPanel(),
                          const SizedBox(height: 12),
                          _buildFilterCard(),
                          const SizedBox(height: 12),
                          // ★★★ 根据类型决定显示卡片视图还是明细视图 ★★★
                          if (_currentType == 'card_summary') ...[
                            _buildCardList(),
                          ] else ...[
                            _buildSummaryRow(),
                            const SizedBox(height: 8),
                            _buildRecordCard(),
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              )
                            else if (!_hasMore && _records.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text('已经加载完全部记录',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                                ),
                              ),
                          ],
                        ],
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
              '账单详情',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 资产面板（蓝 → 绿渐变） ----
  Widget _buildAssetPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF07C160)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账户总资产 (元)',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
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
              Expanded(child: _buildDateBtn(_startDate, () => _pickDate(isStart: true))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('至', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
              ),
              Expanded(child: _buildDateBtn(_endDate, () => _pickDate(isStart: false))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('今日输赢',
                        style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                    const SizedBox(width: 4),
                    Text(_todayWin,
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE94848),
                        )),
                  ],
                ),
                GestureDetector(
                  onTap: _openTypeSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_currentTypeLabel ▾',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
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
          color: Colors.white.withOpacity(0.6),
          border: Border.all(color: const Color(0xFFEBEBF0)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(_fmtDate(d),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
      ),
    );
  }

  // ★★★ 新增：卡片列表渲染 ★★★
  Widget _buildCardList() {
    List<Widget> cards = [];

    if (_myCard != null) {
      cards.add(SummaryCardWidget(
        data: _myCard!,
        isCurrentUser: true,
      ));
    }

    for (var card in _cards) {
      cards.add(SummaryCardWidget(
        data: card,
        isCurrentUser: false,
        onViewSubordinate: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberSummaryPage(
                roomid: widget.roomid,
                targetUid: card.uid,
                targetNickname: card.nickname,
              ),
            ),
          );
        },
      ));
    }

    if (cards.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: const Text('暂无汇总数据', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
      );
    }

    return Column(children: cards);
  }

  // ★★★ 保留原有：明细汇总行 ★★★
  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_currentTypeLabel,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B48B8))),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B48B8)),
              children: [
                const TextSpan(text: '区间累积: '),
                TextSpan(
                  text: _typeTotal.toStringAsFixed(2),
                  style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ★★★ 保留原有：明细卡片 ★★★
  Widget _buildRecordCard() {
    if (_records.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: const Text('暂无明细记录',
            style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
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
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
            ),
      child: isSummary ? _buildSummaryItem(item) : _buildNormalItem(item),
    );
  }

  Widget _buildSummaryItem(Map<String, dynamic> item) {
    final title    = item['title']?.toString() ?? '';
    final recharge = _toDouble(item['recharge']);
    final withdraw = _toDouble(item['withdraw']);
    final time     = item['time']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
        const SizedBox(height: 4),
        Text('充值合计 ${recharge.toStringAsFixed(2)} 元',
            style: const TextStyle(fontSize: 13, color: Color(0xFFE94848), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('提现合计 ${withdraw.toStringAsFixed(2)} 元',
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 2),
        Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
      ],
    );
  }

  Widget _buildNormalItem(Map<String, dynamic> item) {
    final title  = item['title']?.toString() ?? '';
    final time   = item['time']?.toString() ?? '';
    final amount = _toDouble(item['amount']);
    final noSign = _toInt(item['no_sign'], 0) == 1;
    final isNeg  = amount < 0;

    final sign = noSign ? '' : (isNeg ? '-' : '+');
    final display = amount.abs().toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111111), height: 1.5)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text('$sign$display',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE94848))),
      ],
    );
  }
}

// ===================== 切换类型弹窗 =====================
class _TypeSheet extends StatelessWidget {
  final List<_BillType> types;
  final String currentKey;
  final ValueChanged<_BillType> onPick;

  const _TypeSheet({
    required this.types,
    required this.currentKey,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0E4FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('选择交易类型',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111111))),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: types.map((t) {
                final active = t.key == currentKey;
                return GestureDetector(
                  onTap: () => onPick(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFE6F2FF) : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? const Color(0xFF007AFF) : const Color(0xFF333333),
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
                  color: const Color(0xFFE6F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('取消',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}