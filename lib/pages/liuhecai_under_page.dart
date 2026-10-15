import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiUnderPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiUnderPage({super.key, required this.roomid});

  @override
  State<LiuhecaiUnderPage> createState() => _LiuhecaiUnderPageState();
}

class _LiuhecaiUnderPageState extends State<LiuhecaiUnderPage> {
  bool _loading = true;
  List<List<_UnderMember>> _levels = [];
  List<int> _totals = [];
  int _activeIndex = 0;

  final ScrollController _tabScrollCtrl = ScrollController();

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
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiUnder}&op=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final result = Map<String, dynamic>.from(data['result']);
        final totalArr = (result['total'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toList();
        final resArr = (result['result'] as List? ?? []);

        final levels = <List<_UnderMember>>[];
        for (final lv in resArr) {
          final rowList = (lv as List? ?? [])
              .map((e) => _UnderMember.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          levels.add(rowList);
        }

        if (mounted) {
          setState(() {
            _totals = totalArr;
            _levels = levels;
            _loading = false;
          });
        }
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_under get_data] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
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

  void _onTabTap(int index) {
    setState(() => _activeIndex = index);
    if (_tabScrollCtrl.hasClients) {
      const approxItemWidth = 90.0;
      final target = (index * approxItemWidth) -
          (MediaQuery.of(context).size.width / 2) +
          (approxItemWidth / 2);
      _tabScrollCtrl.animateTo(
        target.clamp(0.0, _tabScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
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
                    : Column(
                        children: [
                          _buildTabs(),
                          Expanded(child: _buildPanel()),
                        ],
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
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '下线列表',
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

  // ---- 横向 Tab ----
  Widget _buildTabs() {
    return Container(
      height: 52,
      color: Colors.transparent,
      child: ListView.separated(
        controller: _tabScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _totals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final active = i == _activeIndex;
          return GestureDetector(
            onTap: () => _onTabTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF007AFF) : _cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}级 (${_totals[i]})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? Colors.white : const Color(0xFF666666),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- 面板 ----
  Widget _buildPanel() {
    if (_levels.isEmpty || _activeIndex >= _levels.length) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        child: _emptyCard(),
      );
    }
    final list = _levels[_activeIndex];
    if (list.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        child: _emptyCard(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (_, i) => _buildMemberRow(
        list[i],
        isFirst: i == 0,
        isLast: i == list.length - 1,
      ),
    );
  }

  Widget _buildMemberRow(_UnderMember m,
      {required bool isFirst, required bool isLast}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: m.avatar.isEmpty
                ? Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFFE6F2FF),
                    alignment: Alignment.center,
                    child: const Icon(Icons.person, color: Color(0xFF007AFF), size: 24),
                  )
                : Image.network(
                    m.avatar.startsWith('http')
                        ? m.avatar
                        : 'https://jianxinchat.top/attachment/${m.avatar}',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xFFE6F2FF),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: Color(0xFF007AFF), size: 24),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nickname.isEmpty ? '未命名' : m.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtTime(m.createtime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              'ID: ${m.jid}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: const Text(
        '该层级暂无成员信息',
        style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
      ),
    );
  }

  String _fmtTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _UnderMember {
  final int jid;
  final String nickname;
  final String avatar;
  final int createtime;

  _UnderMember({
    required this.jid,
    required this.nickname,
    required this.avatar,
    required this.createtime,
  });

  factory _UnderMember.fromJson(Map<String, dynamic> j) => _UnderMember(
        jid: int.tryParse(j['jid']?.toString() ?? '0') ?? 0,
        nickname: j['nickname']?.toString() ?? '',
        avatar: j['avatar']?.toString() ?? '',
        createtime: int.tryParse(j['createtime']?.toString() ?? '0') ?? 0,
      );
}