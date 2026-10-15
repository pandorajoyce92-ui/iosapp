import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class GonggaoPage extends StatefulWidget {
  const GonggaoPage({super.key});

  @override
  State<GonggaoPage> createState() => _GonggaoPageState();
}

class _GonggaoPageState extends State<GonggaoPage> {
  final List<_Msg> _list = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

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
    _load(reset: true);
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
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore) return;
    final targetPage = reset ? 1 : _page + 1;

    setState(() => _loadingMore = true);

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.gonggao}&op=display&page=$targetPage',
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
            .map((e) => _Msg.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final pagesize = int.tryParse(result['pagesize']?.toString() ?? '10') ?? 10;

        if (mounted) {
          setState(() {
            if (reset) _list.clear();
            _list.addAll(list);
            _page = targetPage;
            _hasMore = list.length >= pagesize;
            _loadingMore = false;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingMore = false;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [gonggao] $e');
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _loading = false;
        });
      }
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        color: const Color(0xFF007AFF),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                          itemCount: _list.length + _buildFooterCount(),
                          itemBuilder: (_, i) {
                            if (i < _list.length) {
                              return _buildCard(_list[i]);
                            }
                            return _buildFooter();
                          },
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
              '消息中心',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
            ),
          ),
        ],
      ),
    );
  }

  int _buildFooterCount() {
    if (_list.isEmpty) return 1;
    if (_loadingMore || !_hasMore) return 1;
    return 0;
  }

  Widget _buildCard(_Msg m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE94848),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('系统通知',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                  ],
                ),
                Text(m.createtime,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(m.content,
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('暂无消息', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
        ),
      );
    }
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('没有更多消息了', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Msg {
  final int id;
  final String content;
  final String createtime;

  _Msg({required this.id, required this.content, required this.createtime});

  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        content: j['content']?.toString() ?? '',
        createtime: j['createtime']?.toString() ?? '',
      );
}