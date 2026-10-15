import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  bool _added = false;

  int _resultId = 0;
  String _resultNickname = '';
  String _resultAvatar = '';

  int _state = 0;
  String _notFoundKeyword = '';

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDBEAFE),
      Color(0xFFDCF5E8),
      Color(0xFFDCFCE7),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _itemBg = Color(0xF2FFFFFF);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      _toast('请输入 ID 或手机号');
      return;
    }

    setState(() {
      _searching = true;
      _added = false;
    });

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=addfriends',
        data: {'op': 'find', 'findid': keyword},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        if (mounted) {
          setState(() {
            _resultId = _toInt(r['id']);
            _resultNickname = r['nickname']?.toString() ?? '';
            _resultAvatar = _buildAvatarUrl(r['avatar']?.toString() ?? '');
            _state = 1;
            _searching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _state = 2;
            _notFoundKeyword = keyword;
            _searching = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 搜索失败: $e');
      if (mounted) {
        setState(() => _searching = false);
        _toast('网络异常，请重试');
      }
    }
  }

  Future<void> _doAdd() async {
    if (_added || _resultId <= 0) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=addfriends',
        data: {'op': 'add', 'findid': _resultId},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        if (mounted) setState(() => _added = true);
        _toast(data['result']?.toString() ?? '已发送好友请求');
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '添加失败')
            : '添加失败');
      }
    } catch (e) {
      debugPrint('❌ 添加失败: $e');
      _toast('网络异常，请重试');
    }
  }

  String _buildAvatarUrl(String a) {
    a = a.trim();
    if (a.isEmpty) return '';
    if (a.startsWith('http://')) return a.replaceFirst('http://', 'https://');
    if (a.startsWith('https://')) return a;
    if (a.startsWith('/')) return 'https://jianxinchat.top$a';
    if (a.startsWith('images/') || a.startsWith('attachment/')) {
      return 'https://jianxinchat.top/attachment/$a';
    }
    return 'https://jianxinchat.top/attachment/$a';
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
              _buildSearchRow(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildBody(),
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
                width: 40, height: 40,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '添加好友',
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

  Widget _buildSearchRow() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: '搜索 ID / 手机号',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                      ),
                      onSubmitted: (_) => _doSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _searching ? null : _doSearch,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                _searching ? '搜索中' : '搜索',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_state == 0) return _buildGuide();
    if (_state == 2) return _buildEmpty();
    return _buildResult();
  }

  Widget _buildGuide() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          const Text('👥', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            '输入对方的 ID 或手机号\n即可找到并添加好友',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            '未找到「$_notFoundKeyword」\n请检查 ID 或手机号是否正确',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _itemBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _resultAvatar.isEmpty
                        ? Container(
                            width: 44, height: 44,
                            color: const Color(0xFFF0ECFF),
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, color: AppColors.purple, size: 24),
                          )
                        : Image.network(
                            _resultAvatar,
                            width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44, height: 44,
                              color: const Color(0xFFF0ECFF),
                              alignment: Alignment.center,
                              child: const Icon(Icons.person, color: AppColors.purple, size: 24),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resultNickname.isEmpty ? '用户$_resultId' : _resultNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('ID: $_resultId',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _added ? null : _doAdd,
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: _added
                            ? const Color(0xFFF0F0F4)
                            : const Color(0xFF07C160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _added ? '已添加' : '添加',
                        style: TextStyle(
                          color: _added ? const Color(0xFF999999) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}