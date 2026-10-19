import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'; // ★ 必须引入，为了使用 CupertinoPageRoute
import '../core/app_cache_manager.dart'; // ★ 引入全局缓存

import 'add_friend_page.dart';
import 'new_friend_page.dart';
import 'my_groups_page.dart';
import 'person_detail_page.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../models/friend_item.dart';
import '../core/data_cache.dart';

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  List<FriendItem> _friends = [];
  bool _loading = false;
  bool _showPlusMenu = false;

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

  static const Color _itemBg = Color(0x26FFFFFF);

  @override
  void initState() {
    super.initState();
    // 进页面直接拉起请求，绝不等
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    // ① 读缓存
    if (_friends.isEmpty) {
      final cached = DataCache.get('address_book_friends');
      if (cached is List) {
        try {
          final list = cached
              .map((e) => FriendItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (mounted) {
            setState(() {
              _friends = list;
              _loading = false;
            });
          }
        } catch (_) {}
      }
    }

    // ② 后台静默请求网络
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=address_book',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List)
            .map((e) => FriendItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _friends = list;
            _loading = false;
          });
        }
        await DataCache.set('address_book_friends', data['result']);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ 加载好友列表失败: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFriendDetail(int fuid) async {
    final result = await Navigator.of(context).push<bool>(
      // ★ 换成了 CupertinoPageRoute
      CupertinoPageRoute(builder: (_) => PersonDetailPage(fuid: fuid)),
    );
    if (result == true) _loadFriends();
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
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadFriends,
                      color: const Color(0xFF007AFF),
                      // ★ 关键修改：去掉了全屏 loading 的三元判断
                      child: ListView(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _itemBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _buildActionRow(
                                  icon: Icons.person_add_alt_1,
                                  iconBg: const Color(0xFF007AFF),
                                  title: '新的朋友',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      // ★ 换成了 CupertinoPageRoute
                                      CupertinoPageRoute(
                                          builder: (_) => const NewFriendPage()),
                                    );
                                  },
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 68,
                                  color: Color(0xFFF0F0F4),
                                ),
                                _buildActionRow(
                                  icon: Icons.group,
                                  iconBg: const Color(0xFF07C160),
                                  title: '群聊',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      // ★ 换成了 CupertinoPageRoute
                                      CupertinoPageRoute(
                                          builder: (_) => const MyGroupsPage()),
                                    );
                                  },
                                ),
                                // ★ 好友列表逻辑
                                if (_friends.isNotEmpty) ...[
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 68,
                                    color: Color(0xFFF0F0F4),
                                  ),
                                  ..._friends.map(_buildFriendItem),
                                ] else ...[
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF0F0F4),
                                  ),
                                  _loading
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 40),
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : _buildEmpty(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showPlusMenu)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => setState(() => _showPlusMenu = false),
                        ),
                      ),
                    if (_showPlusMenu) _buildPlusMenu(),
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
          const Center(
            child: Text(
              '通讯录',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => setState(() => _showPlusMenu = !_showPlusMenu),
              child: const SizedBox(
                width: 40, height: 40,
                child: Icon(Icons.add, color: Colors.black, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB), size: 20),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(FriendItem friend) {
    return GestureDetector(
      onTap: () => _openFriendDetail(friend.fuid),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: friend.avatarUrl.isEmpty
                  ? _defaultAvatar()
                  : Image(
                      image: CachedNetworkImageProvider(
                        friend.avatarUrl,
                        cacheManager: AppCacheManager.instance,
                      ),
                      width: 44, height: 44, fit: BoxFit.cover,
                      gaplessPlayback: true, // ★★★ 新增 ★★★
                      frameBuilder: (_, child, __, ___) => child,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _defaultAvatar();
                      },
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    ),
            ),
            const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded( // ★ 修改：把 Flexible 改成 Expanded，让名字占满剩余空间，把红点推到最右边
                                child: Text(
                                  friend.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              if (friend.unread > 0) ...[
                                const SizedBox(width: 8),
                                _buildBadge(friend.unread), // 现在它会被推到最右侧了
                              ],
                            ],
                          ),
                        ),
            const SizedBox(width: 16),
          ],
        ),
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

    Widget _buildBadge(int count) {
      return Container(
        height: 18, // ★ 关键修改：强制固定高度为 18
        constraints: const BoxConstraints(minWidth: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE94848),
          borderRadius: BorderRadius.circular(9), // ★ 圆角改为高度的一半，变成完美圆形/胶囊
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, height: 1),
        ),
      );
    }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text('未添加联系人~',
            style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
      ),
    );
  }

  Widget _buildPlusMenu() {
    return Positioned(
      top: 4, right: 10,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuItem('添加朋友', () {
                setState(() => _showPlusMenu = false);
                Navigator.of(context).push(
                  // ★ 换成了 CupertinoPageRoute
                  CupertinoPageRoute(builder: (_) => const AddFriendPage()),
                );
              }),
              _menuItem('扫一扫', () {
                setState(() => _showPlusMenu = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('扫一扫功能暂未开放')),
                );
              }, isLast: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(String label, VoidCallback onTap, {bool isLast = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140, height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
        ),
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF111111))),
      ),
    );
  }
}