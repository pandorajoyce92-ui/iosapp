import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_room_page.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class PersonDetailPage extends StatefulWidget {
  final int fuid;
  const PersonDetailPage({super.key, required this.fuid});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  final _remarkCtrl = TextEditingController();
  final _remarkFocus = FocusNode();

  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  int _uid = 0;
  String _nickname = '';
  String _avatarUrl = '';
  String _displayName = '';

  bool _deleted = false;

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
    _loadInfo();
    _remarkFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _remarkFocus.removeListener(_onFocusChange);
    _remarkFocus.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_remarkFocus.hasFocus) _saveRemark();
  }

  Future<void> _loadInfo() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=person_detail',
        data: {'op': 'get_info', 'fuid': widget.fuid},
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
            _uid = _toInt(r['id']);
            _nickname = r['nickname']?.toString() ?? '';
            _avatarUrl = _buildAvatarUrl(r['avatar']?.toString() ?? '');
            final remark = r['remark']?.toString() ?? '';
            _displayName = remark.isEmpty ? _nickname : remark;
            _remarkCtrl.text = remark;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = true;
            _errorMsg =
                (data is Map ? data['result']?.toString() : null) ?? '加载失败';
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 加载好友详情失败: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = '网络异常，请重试';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveRemark() async {
    final newRemark = _remarkCtrl.text.trim();
    if (newRemark.isEmpty) {
      _toast('备注不能为空');
      _remarkCtrl.text = _displayName;
      return;
    }
    if (newRemark == _displayName) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=person_detail',
        data: {'op': 'setremark', 'fuid': widget.fuid, 'remark': newRemark},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        if (mounted) setState(() => _displayName = newRemark);
        _toast('备注修改成功');
      } else {
        _toast('修改失败，请重试');
      }
    } catch (e) {
      debugPrint('❌ 保存备注失败: $e');
      _toast('网络异常，请重试');
    }
  }

  Future<void> _deleteFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('是否确定删除该好友？操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定',
                style: TextStyle(color: Color(0xFFE94848))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=person_detail',
        data: {'op': 'del', 'fuid': widget.fuid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _deleted = true;
        if (mounted) {
          _toast('删除成功');
          Navigator.of(context).pop(true);
        }
      } else {
        _toast((data is Map ? data['result']?.toString() : null) ?? '删除失败');
      }
    } catch (e) {
      debugPrint('❌ 删除好友失败: $e');
      _toast('网络异常，请重试');
    }
  }

  void _goToChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(fuid: widget.fuid)),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _dedupAttachment(String url) {
    return url.replaceAll(RegExp(r'/attachment(?:/attachment)+'), '/attachment');
  }

  String _buildAvatarUrl(String a) {
    final raw = a.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://')) {
      return _dedupAttachment(raw.replaceFirst('http://', 'https://'));
    }
    if (raw.startsWith('https://')) return _dedupAttachment(raw);
    if (raw.startsWith('/')) return _dedupAttachment('${ApiConfig.baseUrl}$raw');
    if (raw.startsWith('../')) {
      return _dedupAttachment('${ApiConfig.baseUrl}/${raw.substring(3)}');
    }
    if (raw.startsWith('attachment/')) {
      return _dedupAttachment('${ApiConfig.baseUrl}/$raw');
    }
    return _dedupAttachment('${ApiConfig.baseUrl}/attachment/$raw');
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
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.of(context).pop(_deleted);
        },
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
              onTap: () => Navigator.of(context).pop(_deleted),
              child: const SizedBox(
                width: 40, height: 40,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '详细信息',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 12),
            Text(_errorMsg, style: const TextStyle(color: Color(0xFF999999))),
            const SizedBox(height: 20),
            TextButton(onPressed: _loadInfo, child: const Text('重试')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 12),
          _buildRemarkCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 60, height: 60,
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.purple, size: 32),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _avatarUrl.isEmpty
                ? _defaultAvatar()
                : Image.network(
                    _avatarUrl,
                    width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text('昵称：$_nickname',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                const SizedBox(height: 2),
                Text('账号：$_uid',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 85,
              child: Text('设置备注',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87,
                  )),
            ),
            Expanded(
              child: TextField(
                controller: _remarkCtrl,
                focusNode: _remarkFocus,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                  hintText: '请输入需要修改的备注名',
                  hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                ),
                onSubmitted: (_) => _saveRemark(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _goToChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Ink(
              decoration: BoxDecoration(
                // ★ 蓝色渐变 #007AFF → #0060DF
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.28),
                    blurRadius: 16, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('发消息',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _deleteFriend,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shadowColor: Colors.black.withOpacity(0.02),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('删除好友',
                style: TextStyle(
                  color: Color(0xFFE94848), fontSize: 16, fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ],
    );
  }
}