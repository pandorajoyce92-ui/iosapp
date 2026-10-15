import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../models/new_friend_item.dart';

class NewFriendPage extends StatefulWidget {
  const NewFriendPage({super.key});

  @override
  State<NewFriendPage> createState() => _NewFriendPageState();
}

class _NewFriendPageState extends State<NewFriendPage> {
  final ScrollController _scrollCtrl = ScrollController();

  List<NewFriendItem> _list = [];
  int _page = 1;
  final int _pageSize = 10;
  bool _loading = true;
  bool _loadingMore = false;
  bool _noMore = false;

  final Set<int> _agreedUids = {};

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
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _noMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100) {
      _loadPage(_page + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (page == 1) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=new_friend',
        data: {'page': page},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final rawList = (r['list'] as List? ?? []);
        final list = rawList
            .map((e) => NewFriendItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final pageSize =
            _toInt(r['pagesize']) > 0 ? _toInt(r['pagesize']) : _pageSize;

        if (mounted) {
          setState(() {
            if (page == 1) {
              _list = list;
            } else {
              _list.addAll(list);
            }
            _page = page;
            _loading = false;
            _loadingMore = false;
            if (list.length < pageSize) _noMore = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _noMore = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 加载新的朋友失败: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// ★ 修复：先判定 status 成功才标记"已同意"
  Future<void> _agree(NewFriendItem item) async {
    if (_agreedUids.contains(item.fuid)) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=new_friend',
        data: {'op': 'new_add', 'findid': item.fuid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      final ok = (data is Map && data['status'] == 1);
      final msg = (data is Map ? data['result']?.toString() : null) ??
          (ok ? '已同意' : '操作失败');

      if (ok && mounted) {
        setState(() => _agreedUids.add(item.fuid));
      }
      _toast(msg);
    } catch (e) {
      debugPrint('❌ 同意失败: $e');
      _toast('网络异常，请重试');
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
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
              _buildTopBar(),
              Expanded(child: _buildBody()),
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
                width: 40, height: 40,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '新的朋友',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('暂无新的好友申请',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _noMore = false;
        await _loadPage(1);
      },
      color: const Color(0xFF007AFF),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: _list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _list.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _itemBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildItem(_list[index]),
          );
        },
      ),
    );
  }

  Widget _buildItem(NewFriendItem item) {
    final agreed = _agreedUids.contains(item.fuid);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.avatarUrl.isEmpty
                ? _defaultAvatar()
                : Image.network(
                    item.avatarUrl,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.nickname.isEmpty ? '用户${item.fuid}' : item.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: agreed ? null : () => _agree(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: agreed ? const Color(0xFFF0F0F4) : const Color(0xFF07C160),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                agreed ? '已同意' : '同意',
                style: TextStyle(
                  color: agreed ? const Color(0xFF999999) : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 44, height: 44,
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.purple, size: 24),
    );
  }
}