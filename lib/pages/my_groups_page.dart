import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../models/room.dart';
import 'red_packet_room_page.dart';
import 'liuhecai_room_page.dart';

class MyGroupsPage extends StatefulWidget {
  const MyGroupsPage({super.key});

  @override
  State<MyGroupsPage> createState() => _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage> {
  List<Room> _rooms = [];
  bool _loading = true;

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
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.group,
        data: {'op': 'json_mylist'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is List) {
        final list = (data['result'] as List)
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _rooms = list;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ 加载群聊失败: $e');
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _sendToHall(Room room) async {
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.game,
        data: {'op': 'show_room', 'roomid': room.id},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      final msg =
          (data is Map ? data['result']?.toString() : null) ?? '已发送到大厅';
      _toast(msg);
    } catch (e) {
      debugPrint('❌ 发送到大厅失败: $e');
      _toast('网络异常，请重试');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showActionSheet(Room room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(top: 60),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
                  ),
                  child: const Text('群操作',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _sendToHall(room);
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
                    ),
                    child: const Text(
                      '发送到大厅',
                      style: TextStyle(
                        fontSize: 16, color: Color(0xFF007AFF), fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: const Text('取消',
                        style: TextStyle(fontSize: 16, color: Color(0xFF666666))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              _buildTip(),
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
              '我的群聊',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      height: 32,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: const Text(
        '💡 点击进入群聊，长按发送到大厅',
        style: TextStyle(fontSize: 12, color: Color(0xFF5B48B8)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('还没有加入任何群聊',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF007AFF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: _rooms.length,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _itemBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildItem(_rooms[i]),
        ),
      ),
    );
  }

  Widget _buildItem(Room room) {
    return GestureDetector(
      onTap: () => _goToRoom(room),
      onLongPress: () => _showActionSheet(room),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: room.avatarUrl.isEmpty
                  ? _defaultAvatar()
                  : Image.network(
                      room.avatarUrl,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '【${room.roomname}】',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 48, height: 48,
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.group, color: AppColors.purple, size: 24),
    );
  }
}