import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_room_page.dart';
import 'create_group_page.dart';
import 'liuhecai_create_group_page.dart';
import 'red_packet_room_page.dart';
import 'liuhecai_room_page.dart';
import 'gonggao_page.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../core/sound_player.dart';
import '../core/data_cache.dart';
import '../models/room.dart';
import '../models/friend.dart';
import '../models/apply.dart';
import '../widgets/swipeable_item.dart';
import '../widgets/marquee_text.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  List<Room> _rooms = [];
  List<Friend> _friends = [];
  List<GroupApply> _groupApplies = [];
  List<ShareholderApply> _shareholderApplies = [];
  final Map<int, int> _roomMessageCount = {};

  Timer? _friendTimer;
  Timer? _roomTimer;
  Timer? _applyTimer;
  bool _showPlusMenu = false;
  int _prevUnreadTotal = -1;
  String _notice = '';

  /// 蓝绿渐变背景
  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDBEAFE),  // 顶：淡蓝
      Color(0xFFDCF5E8),  // 中：蓝绿
      Color(0xFFDCFCE7),  // 底：淡绿
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// 列表项半透明白（让渐变透出来，同时能遮挡左滑红块）
  static const Color _itemBg = Color(0x26FFFFFF); // 95% 白，红块基本不透

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });

    _loadAll();

    _friendTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadFriends());
    _roomTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadRoomMessages());
    _applyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadGroupApplies();
      _loadShareholderApplies();
      _loadRooms();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _friendTimer?.cancel();
    _roomTimer?.cancel();
    _applyTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFriends();
      _loadRoomMessages();
      _loadGroupApplies();
      _loadShareholderApplies();
    }
  }

  Future<void> _loadAll() async {
    _loadRooms();
    _loadFriends();
    _loadNotice();
    _loadGroupApplies();
    _loadShareholderApplies();
    _loadRoomMessages();
  }

  Future<dynamic> _post(String url, Map<String, dynamic> data) async {
    try {
      final res = await HttpClient.instance.dio.post(
        url,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic body = res.data;
      if (body is String) {
        try { body = jsonDecode(body); } catch (_) {}
      }
      return body;
    } catch (e) {
      debugPrint('❌ [POST $url] $e');
      return null;
    }
  }

  Future<dynamic> _postGame(String op, [Map<String, dynamic>? data]) =>
      _post(ApiConfig.game, {'op': op, ...?data});

    Future<void> _loadRooms() async {
      // ① 先用缓存秒渲染（仅在本地列表为空时）
      if (_rooms.isEmpty) {
        final cached = DataCache.get('game_rooms');
        if (cached is List) {
          try {
            final list = cached
                .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            if (mounted) setState(() => _rooms = list);
          } catch (_) {}
        }
      }

      // ② 后台请求，回来覆盖 + 写缓存
      final data = await _postGame('get_rooms');
      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List)
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) setState(() => _rooms = list);
        await DataCache.set('game_rooms', data['result']);   // ★ 写缓存
      }
    }

  Future<void> _loadFriends() async {
    // ① 先读缓存，秒渲染（首次进入不显示"正在加载"）
    if (_friends.isEmpty) {
      final cached = DataCache.get('game_friends');
      if (cached is List) {
        try {
          final list = cached
              .map((e) => Friend.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (mounted) setState(() => _friends = list);
        } catch (_) {}
      }
    }

    // ② 后台请求，返回后覆盖 + 写缓存
    final data = await _postGame('get_friends');
    if (data is Map && data['status'] == 1 && data['result'] is List) {
      final list = (data['result'] as List)
          .map((e) => Friend.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      int newTotal = 0;
      for (final f in list) { newTotal += f.unread; }
      if (_prevUnreadTotal >= 0 && newTotal > _prevUnreadTotal) {
        SoundPlayer.instance.playMessage();
      }
      _prevUnreadTotal = newTotal;
      if (mounted) setState(() => _friends = list);

      // ★ 写缓存
      await DataCache.set('game_friends', data['result']);
    }
  }

  Future<void> _loadRoomMessages() async {
    final data = await _postGame('get_room_messages');
    if (data is Map && data['status'] == 1 && data['result'] is Map) {
      final map = Map<String, dynamic>.from(data['result']);
      if (mounted) {
        setState(() {
          _roomMessageCount.clear();
          map.forEach((k, v) {
            _roomMessageCount[int.tryParse(k) ?? 0] = int.tryParse(v.toString()) ?? 0;
          });
        });
      }
    }
  }

    Future<void> _loadNotice() async {
      try {
        final res = await HttpClient.instance.dio
            .get('${ApiConfig.game}&op=get_notice')
            .timeout(const Duration(seconds: 10));
        dynamic data = res.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
        if (data is Map && data['status'] == 1 && data['result'] is List) {
          final list = (data['result'] as List).map((e) => e.toString()).toList();
          final merged = list.join('    ');
          if (mounted) setState(() => _notice = merged);
        }
      } catch (e) {
        debugPrint('📢 公告加载失败: $e');
      }
    }

  Future<void> _loadGroupApplies() async {
    final data = await _post(ApiConfig.group, {'op': 'get_all_apply_list'});
    if (data is Map && data['status'] == 1 && data['result'] is List) {
      final list = (data['result'] as List)
          .map((e) => GroupApply.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) setState(() => _groupApplies = list);
    } else {
      if (mounted) setState(() => _groupApplies = []);
    }
  }

  Future<void> _loadShareholderApplies() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.shareholderApply}&op=get_list',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List)
            .map((e) => ShareholderApply.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) setState(() => _shareholderApplies = list);
      } else {
        if (mounted) setState(() => _shareholderApplies = []);
      }
    } catch (e) {
      debugPrint('❌ [shareholder_apply] $e');
    }
  }

  Future<void> _approveGroupApply(int applyId, String action, int roomid) async {
    final data = await _post(
      '${ApiConfig.groupDetail}&id=$roomid&op=approve_join',
      {'apply_id': applyId, 'action': action},
    );
    if (data is Map && data['status'] == 1) {
      _toast('操作成功');
      _loadGroupApplies();
    } else {
      _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
    }
  }

  Future<void> _reviewShareholderApply(int id, int status) async {
    final data = await _post(
      '${ApiConfig.shareholderApply}&op=review',
      {'id': id, 'status': status},
    );
    if (data is Map && data['status'] == 1) {
      _toast('操作成功');
      _loadShareholderApplies();
    } else {
      _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
    }
  }

    Future<void> _hideRoom(int roomid) async {
      final data = await _postGame('hide_room', {'roomid': roomid});
      if (data is Map && data['status'] == 1) {
        setState(() => _rooms.removeWhere((r) => r.id == roomid));
        // ★ 同步缓存，避免重启后隐藏的房间又出现
        await DataCache.set(
          'game_rooms',
          _rooms.map((r) => r.toJson()).toList(),
        );
        _toast('已隐藏');
      } else {
        _toast('操作失败');
      }
    }

    Future<void> _hideFriend(int fuid) async {
      final data = await _postGame('hide_friend', {'fuid': fuid});
      if (data is Map && data['status'] == 1) {
        setState(() => _friends.removeWhere((f) => f.fuid == fuid));
        // ★ 同步缓存
        await DataCache.set(
          'game_friends',
          _friends.map((f) => f.toJson()).toList(),
        );
        _toast('已隐藏');
      } else {
        _toast('操作失败');
      }
    }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _goToRoom(Room room) {
    if (room.type == 3) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LiuhecaiRoomPage(roomid: room.id, roomName: room.roomname),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RedPacketRoomPage(roomid: room.id, roomName: room.roomname),
      ));
    }
  }

  Future<void> _goToFriend(Friend friend) async {
    if (mounted) setState(() => _friends.removeWhere((f) => f.fuid == friend.fuid));
    _post(ApiConfig.chatRoom, {'op': 'clear_unread', 'fuid': friend.fuid});
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(fuid: friend.fuid)),
    );
    if (mounted) _loadFriends();
  }

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return '';
    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 2) return '昨天';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  // ==================== UI ====================

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
              _buildSearchBar(),
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadAll,
                      color: const Color(0xFF007AFF),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          _buildSystemNoticeItem(),
                          if (_groupApplies.isNotEmpty)
                            _buildApplyCard('进群申请', _buildGroupApplyList()),
                          if (_shareholderApplies.isNotEmpty)
                            _buildApplyCard('股东申请', _buildShareholderApplyList()),
                          ..._rooms.map(_buildRoomItem),
                          if (_friends.isNotEmpty) ...[
                            _buildSectionTitle('最近联系人'),
                            ..._friends.map(_buildFriendItem),
                          ],
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
              '聊天',
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

  Widget _buildSearchBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: GestureDetector(
        onTap: _showSearchDialog,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 18, color: Color(0xFF999999)),
              SizedBox(width: 4),
              Text('搜索', style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemNoticeItem() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GonggaoPage()),
        );
      },
      child: Container(
        color: _itemBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.campaign, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('系统通知',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: 18,
                                child: _notice.isEmpty
                                    ? const Text('欢迎使用简信，点击查看公告',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: Color(0xFF888888)))
                                    : MarqueeText(
                                        text: _notice,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                                      ),
                              ),
                            ],
                          ),
                        ),
            const Text('刚刚', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyCard(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildGroupApplyList() {
    return Column(
      children: _groupApplies.map((room) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('房间：${room.roomname}（房间号：${room.roomnums}）',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...room.applies.map((apply) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  ClipOval(
                    child: apply.avatarUrl.isEmpty
                        ? Container(width: 30, height: 30, color: const Color(0xFFF0ECFF),
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, size: 18, color: AppColors.purple))
                        : Image.network(apply.avatarUrl, width: 30, height: 30, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 30, height: 30, color: const Color(0xFFF0ECFF))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(apply.nickname, style: const TextStyle(fontSize: 13))),
                  _buildSmallBtn('同意', const Color(0xFF28A745),
                      () => _approveGroupApply(apply.id, 'agree', room.roomId)),
                  const SizedBox(width: 5),
                  _buildSmallBtn('拒绝', const Color(0xFFDC3545),
                      () => _approveGroupApply(apply.id, 'reject', room.roomId)),
                ],
              ),
            )),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildShareholderApplyList() {
    return Column(
      children: _shareholderApplies.map((apply) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            ClipOval(
              child: apply.avatarUrl.isEmpty
                  ? Container(width: 30, height: 30, color: const Color(0xFFF0ECFF),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, size: 18, color: AppColors.purple))
                  : Image.network(apply.avatarUrl, width: 30, height: 30, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 30, height: 30, color: const Color(0xFFF0ECFF))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apply.nickname,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('📱${apply.mobile} 发包${apply.sendRatio}% 抢包${apply.grabRatio}%',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ],
              ),
            ),
            _buildSmallBtn('同意', const Color(0xFF28A745),
                () => _reviewShareholderApply(apply.id, 1)),
            const SizedBox(width: 5),
            _buildSmallBtn('拒绝', const Color(0xFFDC3545),
                () => _reviewShareholderApply(apply.id, 2)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSmallBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildRoomItem(Room room) {
    final badge = _roomMessageCount[room.id] ?? 0;
    final subtitle = room.subtitle.isNotEmpty ? room.subtitle : '点击进入群聊';
    return SwipeableItem(
      key: ValueKey('room_${room.id}'),
      onHide: () => _hideRoom(room.id),
      onTap: () => _goToRoom(room),
      child: Container(
        color: _itemBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: room.avatarUrl.isEmpty
                                                      ? _defaultAvatar(Icons.group)
                                                      : Image.network(
                                                          room.avatarUrl,
                                                          width: 48,
                                                          height: 48,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => _defaultAvatar(Icons.group),
                                                        ),
                                                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('【${room.roomname}】',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (badge > 0) _buildBadge(badge),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    final timeStr = _formatTime(friend.lastTime);
    return SwipeableItem(
      key: ValueKey('friend_${friend.fuid}'),
      onHide: () => _hideFriend(friend.fuid),
      onTap: () => _goToFriend(friend),
      child: Container(
        color: _itemBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: friend.avatarUrl.isEmpty
                                          ? _defaultAvatar(Icons.person)
                                          : Image.network(
                                              friend.avatarUrl,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _defaultAvatar(Icons.person),
                                            ),
                                    ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.nickname,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                  const SizedBox(height: 3),
                  const Text('',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                if (friend.unread > 0) ...[
                  const SizedBox(height: 4),
                  _buildBadge(friend.unread),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF5B48B8), fontWeight: FontWeight.w500)),
    );
  }

  Widget _defaultAvatar(IconData icon) {
    return Container(
      width: 48, height: 48,
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.purple, size: 26),
    );
  }

  Widget _buildBadge(int count) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE94848),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10, height: 1)),
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
              _menuItem('创建雷群', () async {
                setState(() => _showPlusMenu = false);
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                );
                if (result == true) {
                  _loadRooms();
                  _loadGroupApplies();
                }
              }),
              _menuItem('创建六合彩群', () async {
                setState(() => _showPlusMenu = false);
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const LiuhecaiCreateGroupPage()),
                );
                if (result == true) {
                  _loadRooms();
                  _loadGroupApplies();
                }
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

  void _showSearchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('搜索房间'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '请输入房间号'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final roomnum = controller.text.trim();
              if (roomnum.isEmpty) return;
              Navigator.pop(context);
              final data = await _post(ApiConfig.redpackets, {'op': 'apply_to_join', 'roomnum': roomnum});
              if (data is Map && data['status'] == 1) {
                _toast('申请已提交');
                _loadRooms();
              } else {
                _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}