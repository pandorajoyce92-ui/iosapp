import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';
import 'share_group_page.dart';
import '../core/data_cache.dart';                                   // ★ 新增
import 'package:image_picker/image_picker.dart';
import 'room_announcement_page.dart';
import 'rule_page.dart';
import 'welfare_setting_page.dart';
import 'shareholder_apply_page.dart';
import 'welfare_numbers_page.dart';
import 'lottery_setting_page.dart';
import 'rebate_setting_page.dart';
import 'room_transactions_page.dart';
import 'immortal_robot_log_page.dart';
import 'webview_page.dart';

class SaileiRoomInfoPage extends StatefulWidget {
  final int roomid;
  const SaileiRoomInfoPage({super.key, required this.roomid});

  @override
  State<SaileiRoomInfoPage> createState() => _SaileiRoomInfoPageState();
}

class _SaileiRoomInfoPageState extends State<SaileiRoomInfoPage> {
  bool _loading = true;
  int _myUid = 0;
  bool _isOwner = false;

  String _roomName = '';
  double _roomMin = 0;
  double _roomMax = 0;
  String _announcement = '';
  bool _isClosed = false;
  bool _isRobot = false;
  bool _isMuted = false;   // ★ 新增

  List<Map<String, dynamic>> _members = [];
  bool _membersExpanded = false;

  List<Map<String, dynamic>> _finances = [];

  List<Map<String, dynamic>> _welfareList = [];
  bool _welfareExpanded = false;

  bool _userIsShareholder = false;
  bool _userIsAgent = false;

  bool _mim = false;
  bool _book = false;

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
    _loadData();
  }

    Future<void> _loadData() async {
      // ① 先用缓存秒渲染
      if (_members.isEmpty) {
        final cached = DataCache.get('sailei_${widget.roomid}');
        if (cached is Map) {
          try {
            _applyData(Map<String, dynamic>.from(cached), fromCache: true);
          } catch (_) {}
        }
      }

      // ② 后台请求
      try {
        final res = await HttpClient.instance.dio.get(
          '${ApiConfig.saileiRoomInfo}&act=get_data&roomid=${widget.roomid}',
          options: Options(responseType: ResponseType.plain),
        );
        dynamic data = res.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
        if (data is Map && data['status'] == 1 && data['result'] is Map) {
          final r = Map<String, dynamic>.from(data['result']);
          _applyData(r);
          await DataCache.set('sailei_${widget.roomid}', data['result']);
        } else {
          if (mounted) setState(() => _loading = false);
        }
      } catch (e) {
        debugPrint('❌ [sailei get_data] $e');
        if (mounted) setState(() => _loading = false);
      }
    }

    /// 把 get_data 返回的数据灌进 UI 状态
    void _applyData(Map<String, dynamic> r, {bool fromCache = false}) {
      final roominfo = r['roominfo'] is Map
          ? Map<String, dynamic>.from(r['roominfo'])
          : <String, dynamic>{};
      final member = r['member'] is Map
          ? Map<String, dynamic>.from(r['member'])
          : <String, dynamic>{};

      final members = (r['members'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final finances = (r['finances'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final welfare = (r['welfare_list'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _myUid = int.tryParse(member['id']?.toString() ?? '0') ?? 0;
        _isOwner = _truthy(r['is_owner']);

        _roomName = roominfo['roomname']?.toString() ?? '';
        _roomMin = double.tryParse(roominfo['min']?.toString() ?? '0') ?? 0;
        _roomMax = double.tryParse(roominfo['max']?.toString() ?? '0') ?? 0;
        _announcement = r['announcement']?.toString() ?? '';
        _isClosed = _truthy(r['is_closed']);
        _isRobot = _truthy(r['isrobot']);
        _isMuted = _truthy(roominfo['is_muted']);

        _members = members;
        _finances = finances;
        _welfareList = welfare;

        _userIsShareholder = _truthy(r['user_is_shareholder']);
        _userIsAgent = _truthy(r['user_is_agent']);

        if (!fromCache) _loading = false;
      });
    }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  // ============ 群名修改 ============
  Future<void> _editRoomName() async {
    if (!_isOwner) return;
    final ctrl = TextEditingController(text: _roomName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改群名称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入新的群名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _roomName) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=update_roomname&roomid=${widget.roomid}',
        data: {'roomname': newName, 'roomid': widget.roomid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('修改成功');
        setState(() => _roomName = newName);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '修改失败') : '修改失败');
      }
    } catch (e) {
      _toast('网络错误');
    }
  }

    // ============ ★ 设置群头像（仅群主） ============
    Future<void> _pickAndUploadAvatar() async {
      if (!_isOwner) {
        _toast('仅群主可设置');
        return;
      }
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          imageQuality: 85,
        );
        if (xfile == null) return;

        _toast('上传中…');
        final bytes = await xfile.readAsBytes();
        final name = xfile.name.isEmpty ? 'room_avatar.jpg' : xfile.name;

        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: name),
        });

        final res = await HttpClient.instance.dio.post(
          '${ApiConfig.saileiRoomInfo}&act=upload_room_avatar&roomid=${widget.roomid}',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );

        dynamic data = res.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
        if (data is Map && data['status']?.toString() == '1') {
          _toast('群头像已更新');
          _loadData();   // 刷新页面数据
        } else {
          _toast(data is Map
              ? (data['result']?.toString() ?? '上传失败')
              : '上传失败');
        }
      } catch (e) {
        debugPrint('❌ [upload_room_avatar] $e');
        _toast('上传失败：$e');
      }
    }

  // ============ 封盘开关 ============
  Future<void> _toggleClose(bool v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text(v ? '确定要开启封盘吗？全员将无法发送红包' : '确定要取消封盘吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=toggle_close&roomid=${widget.roomid}',
        data: {'status': v ? 1 : 0},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('操作成功');
        setState(() => _isClosed = v);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
      }
    } catch (e) {
      _toast('网络错误');
    }
  }

  // ============ ★ 新增：禁言开关 ============
  Future<void> _toggleMute(bool v) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=toggle_mute&roomid=${widget.roomid}',
        data: {'status': v ? 1 : 0},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast(data['result']?.toString() ?? '操作成功');
        setState(() => _isMuted = v);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
        setState(() => _isMuted = !v);
      }
    } catch (e) {
      _toast('网络错误');
      setState(() => _isMuted = !v);
    }
  }

  // ============ 长按成员：角色菜单 ============
  Future<void> _onMemberLongPress(Map<String, dynamic> m) async {
    final isVirtual = _truthy(m['is_virtual']);
    final isSelf = _truthy(m['is_self']);
    if (isVirtual || isSelf) return;
    if (!_isOwner) return;

    final uid = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
    if (uid <= 0) return;
    final nickname = m['nickname']?.toString() ?? '';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(nickname,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              _sheetItem('设为财务', Icons.attach_money, const Color(0xFF007AFF),
                  () => Navigator.pop(context, 'set_finance')),
              _sheetItem('取消财务', Icons.remove_circle_outline, const Color(0xFF333333),
                  () => Navigator.pop(context, 'remove_finance')),
              _sheetItem('设为免死机器人', Icons.badge, const Color(0xFF007AFF),
                  () => Navigator.pop(context, 'set_die_robot')),
              // ★ 新增：取消免死
              _sheetItem('取消免死', Icons.cancel_outlined, const Color(0xFF999999),
                  () => Navigator.pop(context, 'cancel_die_robot')),
              _sheetItem('踢出群聊', Icons.person_remove, const Color(0xFFE94848),
                  () => Navigator.pop(context, 'kick_member')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    await _handleMemberAction(action, uid, nickname);
  }

  Future<void> _handleMemberAction(String action, int uid, String nickname) async {
    switch (action) {
      case 'set_finance':
        await _setRole(uid, 1);
        break;
      case 'remove_finance':
        await _setRole(uid, 0);
        break;
      case 'set_die_robot':
        await _setDieRobot(uid, nickname);
        break;
      case 'cancel_die_robot':
        await _cancelDieRobot();
        break;
      case 'kick_member':
        await _kickMember(uid, nickname);
        break;
    }
  }

  Widget _sheetItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _setRole(int uid, int role) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=set_role&roomid=${widget.roomid}',
        data: {'uid': uid, 'role': role},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      _toast(data is Map ? (data['msg']?.toString() ?? '操作完成') : '操作完成');
      if (data is Map && data['code']?.toString() == '1') _loadData();
    } catch (e) {
      _toast('网络错误');
    }
  }

  Future<void> _setDieRobot(int uid, String nickname) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text('确认将【$nickname】的头像和昵称设为免死机器人形象？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=set_die_robot&roomid=${widget.roomid}',
        data: {'uid': uid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      _toast(data is Map ? (data['msg']?.toString() ?? '操作完成') : '操作完成');
    } catch (e) {
      _toast('网络错误');
    }
  }

  // ★ 新增：取消免死机器人
  Future<void> _cancelDieRobot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确认取消免死机器人的自定义形象吗？\n取消后恢复为默认的【简信管家】头像和昵称。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=cancel_die_robot&roomid=${widget.roomid}',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      _toast(data is Map ? (data['msg']?.toString() ?? '操作完成') : '操作完成');
    } catch (e) {
      _toast('网络错误');
    }
  }

  Future<void> _kickMember(int uid, String nickname) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text('确定将【$nickname】踢出群聊？\n该操作会取消其在本房间的股东/代理/财务身份。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=kick_member&roomid=${widget.roomid}',
        data: {'uid': uid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      _toast(data is Map ? (data['msg']?.toString() ?? '已踢出') : '已踢出');
      if (data is Map && data['code']?.toString() == '1') {
        setState(() {
          _members.removeWhere((e) => e['id']?.toString() == uid.toString());
        });
      }
    } catch (e) {
      _toast('网络错误');
    }
  }

  // ============ 清空聊天记录 ============
  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('是否清空聊天记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await HttpClient.instance.dio.post(
        '${ApiConfig.chatDetails}&op=clear',
        data: {'status': 1, 'id': ''},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      _toast('清除成功');
    } catch (e) {
      _toast('已清除');
    }
  }

  // ============ 退出群聊 ============
  Future<void> _exitGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确定要退出该群聊吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    _toast('退出功能开发中');
  }

  // ============ ★ 新增：打开全屏成员列表 ============
  void _openMemberList() {
    final canSeeBadge = _isOwner ||
        _finances.any((f) => int.tryParse(f['id']?.toString() ?? '0') == _myUid);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MemberListModal(
        members: _members,
        myUid: _myUid,
        isOwner: _isOwner,
        canSeeBadge: canSeeBadge,
        onAction: (action, uid, nickname) async {
          await _handleMemberAction(action, uid, nickname);
        },
      ),
    ));
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
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 40, height: 44,
              child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '群员信息',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMembersCard(),
          const SizedBox(height: 12),
          _buildBaseInfoCard(),
          const SizedBox(height: 12),
          _buildCoreApps(),
          if (_isOwner) ...[
            const SizedBox(height: 12),
            _buildOwnerPanel(),
          ],
          const SizedBox(height: 12),
          _buildChatSettings(),
          const SizedBox(height: 12),
          _buildExitBtn(),
        ],
      ),
    );
  }

  // ============ 卡片 1：群成员（对齐 H5：折叠 10 / 展开 50 + 查看按钮） ============
  Widget _buildMembersCard() {
    const collapseCount = 10;
    const expandMax = 50;
    final total = _members.length;
    if (total == 0) return const SizedBox.shrink();

    int displayItems;
    bool showViewBtn = false;

    if (_membersExpanded) {
      if (total > expandMax) {
        displayItems = expandMax - 1;
        showViewBtn = true;
      } else {
        displayItems = total;
      }
    } else {
      displayItems = total < collapseCount ? total : collapseCount;
    }

    final canSeeBadge = _isOwner ||
        _finances.any((f) => int.tryParse(f['id']?.toString() ?? '0') == _myUid);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const crossSpacing = 6.0;
                final itemWidth =
                    (constraints.maxWidth - crossSpacing * (crossAxisCount - 1)) / crossAxisCount;
                final items = <Widget>[];
                for (int i = 0; i < displayItems; i++) {
                  items.add(SizedBox(
                    width: itemWidth,
                    child: _buildMemberItem(_members[i], itemWidth, canSeeBadge),
                  ));
                }
                if (showViewBtn) {
                  items.add(SizedBox(width: itemWidth, child: _buildViewMoreItem(itemWidth)));
                }
                return Wrap(
                  spacing: crossSpacing,
                  runSpacing: 12,
                  children: items,
                );
              },
            ),
          ),
              if (total > collapseCount)
                      GestureDetector(
                        onTap: () {
                          setState(() => _membersExpanded = !_membersExpanded);
                        },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6))),
                ),
                alignment: Alignment.center,
                child: Text(
                  _membersExpanded ? '收起' : '查看全部群成员',
                  style: const TextStyle(
                    fontSize: 14, color: Color(0xFF007AFF), fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> m, double width, bool canSeeBadge) {
    final avatar = _fullAvatarUrl(m['avatar']?.toString() ?? '');
    final nickname = m['nickname']?.toString() ?? '';
    final avatarSize = width.clamp(36.0, 48.0);
    final roleBadge = m['role_badge']?.toString() ?? '';
    final roleBadgeColor = m['role_badge_color']?.toString() ?? '';

    return GestureDetector(
      onLongPress: () => _onMemberLongPress(m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              color: const Color(0xFFE6F2FF),
                                          child: avatar.isEmpty
                                              ? Icon(Icons.person, color: const Color(0xFF007AFF), size: avatarSize * 0.5)
                                              : Image.network(
                                                  avatar,
                                                  width: avatarSize,
                                                  height: avatarSize,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(Icons.person, color: const Color(0xFF007AFF), size: avatarSize * 0.5),
                                                ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
          ),
          if (canSeeBadge && roleBadge.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _hexColor(roleBadgeColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                roleBadge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewMoreItem(double width) {
    final avatarSize = width.clamp(36.0, 48.0);
    return GestureDetector(
      onTap: _openMemberList,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text(
              '查看',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '更多成员',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }

  // ============ 卡片 2：基础信息 ============
  Widget _buildBaseInfoCard() {
    final roomNameDisplay = '【$_roomName】${_fmt(_roomMin)}-${_fmt(_roomMax)}元';
    final annDisplay = _announcement.isEmpty ? '点击设置' : _stripHtml(_announcement);

    return _card([
      _buildFieldRow(
        '群聊名称',
        value: roomNameDisplay,
        onTap: _isOwner ? _editRoomName : null,
        trailing: _isOwner
            ? const Text('✎', style: TextStyle(fontSize: 16, color: Color(0xFF007AFF)))
            : null,
      ),
            if (_isOwner)
              _buildArrowRow(
                '设置群头像',
                _pickAndUploadAvatar,
                value: '点击上传',
              ),
      _buildArrowRow('分享群ID', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShareGroupPage(roomid: widget.roomid)),
        );
      }),
      _buildArrowRow('群公告', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoomAnnouncementPage(roomid: widget.roomid)),
        ).then((_) => _loadData());
      }, value: annDisplay),
      _buildArrowRow('赔率介绍', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RulePage(roomid: widget.roomid)),
        );
      }),
      if (_isOwner)
        _buildArrowRow('重磅福利', () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WelfareSettingPage(roomid: widget.roomid)),
          );
        }, isLast: true),
    ]);
  }

  // ============ 卡片 3：核心应用 ============
  Widget _buildCoreApps() {
    final canAccessSa = _isOwner || _userIsShareholder || _userIsAgent;
    return Column(
      children: [
        if (canAccessSa)
          _card([
            _buildArrowRow('股东与代理', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShareholderApplyPage(roomid: widget.roomid)),
              );
            }, isLast: true),
          ]),
        if (canAccessSa) const SizedBox(height: 12),
        _buildWelfareNumbersCard(),
      ],
    );
  }

  Widget _buildWelfareNumbersCard() {
    return _card([
      _buildFieldRow(
        '抢包数字奖励',
        value: _welfareList.isEmpty ? (_isOwner ? '点击设置' : '暂无规则') : '',
        onTap: _isOwner
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WelfareNumbersPage(roomid: widget.roomid)),
                ).then((_) => _loadData());
              }
            : null,
        trailing: _isOwner
            ? const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18)
            : null,
      ),
      if (_welfareList.isNotEmpty) ...[
        GestureDetector(
          onTap: () => setState(() => _welfareExpanded = !_welfareExpanded),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F2FF),
              border: Border.all(color: const Color(0xFFB3D8FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _welfareExpanded ? '收起规则' : '显示全部',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Icon(
                  _welfareExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16, color: const Color(0xFF007AFF),
                ),
              ],
            ),
          ),
        ),
        if (_welfareExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: _welfareList.map((w) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(w['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                          children: [
                            TextSpan(text: '抢到 ${w['welfarenums']} 元 → 奖 '),
                            TextSpan(
                              text: '${w['goldmoney']} 元',
                              style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    ]);
  }

  // ============ 卡片 4：群主管理 ============
  Widget _buildOwnerPanel() {
    return _card([
      _buildArrowRow('幸运抽奖设置', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LotterySettingPage(roomid: widget.roomid)),
        );
      }),
      _buildArrowRow('玩家返点设置', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RebateSettingPage(roomid: widget.roomid)),
        );
      }),
      _buildArrowRow('充值详情', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoomTransactionsPage(roomid: widget.roomid)),
        );
      }),
      _buildArrowRow('免死机器人流水', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ImmortalRobotLogPage(roomid: widget.roomid)),
        );
      }, value: '查看记录'),
      Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '开启封盘',
                style: TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500),
              ),
            ),
            const Text('全员禁发', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
            const SizedBox(width: 8),
            Switch(
              value: _isClosed,
              onChanged: _toggleClose,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF34C759),
            ),
          ],
        ),
      ),
    ]);
  }

  // ============ 卡片 5：聊天设置（禁言 + 置顶 + 保存 + 清空） ============
  Widget _buildChatSettings() {
    return _card([
      // ★ 开启禁言（仅群主）
      if (_isOwner)
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Text('开启禁言',
                        style: TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
                    SizedBox(width: 6),
                    Text('只能发口令', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ],
                ),
              ),
              Switch(
                value: _isMuted,
                onChanged: _toggleMute,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF34C759),
              ),
            ],
          ),
        ),
      _buildSwitchRow('置顶聊天', _mim, (v) => setState(() => _mim = v)),
      _buildSwitchRow('保存到通讯录', _book, (v) => setState(() => _book = v)),
      _buildArrowRow('清空聊天记录', _clearChat, isLast: true),
    ]);
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildExitBtn() {
    return GestureDetector(
      onTap: _exitGroup,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '退出群聊',
          style: TextStyle(fontSize: 16, color: Color(0xFFE94848), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ============ 通用组件 ============
  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

    Widget _buildFieldRow(String label, {String? value, VoidCallback? onTap, Widget? trailing}) {
      final row = Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            // ★ 改成 Expanded + 右对齐（去掉 Spacer）
            Expanded(
              child: Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      );
      if (onTap == null) return row;
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
    }

    Widget _buildArrowRow(String label, VoidCallback onTap, {String? value, bool isLast = false}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6))),
          ),
          child: Row(
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              // ★ 改成 Expanded + 右对齐（去掉 Spacer）
              Expanded(
                child: Text(
                  value ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
            ],
          ),
        ),
      );
    }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
  }

  String _fullAvatarUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('../')) return '${ApiConfig.baseUrl}/${raw.replaceFirst('../', '')}';
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Color _hexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }
}

// ====================================================================
//                  全屏群成员列表弹窗
// ====================================================================
class _MemberListModal extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final int myUid;
  final bool isOwner;
  final bool canSeeBadge;
  final Future<void> Function(String action, int uid, String nickname) onAction;

  const _MemberListModal({
    required this.members,
    required this.myUid,
    required this.isOwner,
    required this.canSeeBadge,
    required this.onAction,
  });

  @override
  State<_MemberListModal> createState() => _MemberListModalState();
}

class _MemberListModalState extends State<_MemberListModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();   // ★ 新增
  bool _showSearch = false;
  String _keyword = '';
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    // ★ 预创建全部分组的 GlobalKey，保证 ensureVisible 能找到目标
    for (final m in widget.members) {
      final init = m['initial']?.toString() ?? '#';
      final key = init.isEmpty ? '#' : init;
      _sectionKeys.putIfAbsent(key, () => GlobalKey());
    }
  }

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _itemBg = Color(0xF2FFFFFF);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_keyword.isEmpty) return widget.members;
    final kw = _keyword.toLowerCase();
    return widget.members.where((m) {
      final name = (m['nickname']?.toString() ?? '').toLowerCase();
      final uid = m['id']?.toString() ?? '';
      return name.contains(kw) || uid.contains(kw);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final m in _filtered) {
      final init = m['initial']?.toString() ?? '#';
      final key = init.isEmpty ? '#' : init;
      map.putIfAbsent(key, () => []).add(m);
    }
    return map;
  }

        void _scrollTo(String key) {
          final ctx = _sectionKeys[key]?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: 0.0,
            );
          }
        }

  Future<void> _onLongPress(Map<String, dynamic> m) async {
    final isVirtual = _truthy(m['is_virtual']);
    final isSelf = _truthy(m['is_self']);
    if (isVirtual || isSelf) return;
    if (!widget.isOwner) return;
    final uid = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
    if (uid <= 0) return;
    final nickname = m['nickname']?.toString() ?? '';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(nickname,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              _sheetItem('设为财务', Icons.attach_money, const Color(0xFF007AFF),
                  () => Navigator.pop(context, 'set_finance')),
              _sheetItem('取消财务', Icons.remove_circle_outline, const Color(0xFF333333),
                  () => Navigator.pop(context, 'remove_finance')),
              _sheetItem('设为免死机器人', Icons.badge, const Color(0xFF007AFF),
                  () => Navigator.pop(context, 'set_die_robot')),
              _sheetItem('取消免死', Icons.cancel_outlined, const Color(0xFF999999),
                  () => Navigator.pop(context, 'cancel_die_robot')),
              _sheetItem('踢出群聊', Icons.person_remove, const Color(0xFFE94848),
                  () => Navigator.pop(context, 'kick_member')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    await widget.onAction(action, uid, nickname);
  }

  Widget _sheetItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  String _fullAvatarUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('../')) return '${ApiConfig.baseUrl}/${raw.replaceFirst('../', '')}';
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Color _hexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

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
              // ★ 顶栏：透明 + 黑字
              _buildTopBar(),
              if (_showSearch) _buildSearchBar(),
                            Expanded(
                              child: keys.isEmpty
                                  ? const Center(
                                      child: Text('暂无成员',
                                          style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
                                    )
                                  : Stack(
                                      children: [
                                        // 普通 ListView（非 builder），让所有分组 key 都提前构建
                                        ListView(
                                          controller: _scrollCtrl,
                                          cacheExtent: 100000,
                                          children: keys.map((k) {
                                            final list = grouped[k]!;
                                            final sectionKey = _sectionKeys[k] ?? GlobalKey();
                                            return Column(
                                              key: sectionKey,
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // 分组标题（浅色半透明）
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                  color: Colors.white.withOpacity(0.35),
                                                  child: Text(k,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF007AFF),
                                                          fontWeight: FontWeight.w600)),
                                                ),
                                                ...list.map(_buildItem),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                                                                            // 右侧字母索引（Listener 版本，不受手势竞争影响）
                                                                                            Positioned(
                                                                                              right: 0, top: 0, bottom: 10,
                                                                                              child: LayoutBuilder(
                                                                                                builder: (context, constraints) {
                                                                                                  final itemHeight =
                                                                                                      constraints.maxHeight / keys.length;

                                                                                                  int idxOf(double dy) {
                                                                                                    final i = (dy / itemHeight).floor();
                                                                                                    return i.clamp(0, keys.length - 1);
                                                                                                  }

                                                                                                  return Listener(
                                                                                                    behavior: HitTestBehavior.opaque,
                                                                                                    onPointerDown: (e) {
                                                                                                      debugPrint('👆 点按下 dy=${e.localPosition.dy}');
                                                                                                      _scrollTo(keys[idxOf(e.localPosition.dy)]);
                                                                                                    },
                                                                                                    onPointerMove: (e) {
                                                                                                      _scrollTo(keys[idxOf(e.localPosition.dy)]);
                                                                                                    },
                                                                                                    child: Container(
                                                                                                      width: 30,
                                                                                                      alignment: Alignment.center,
                                                                                                      child: Column(
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                                        children: keys
                                                                                                            .map((k) => Text(
                                                                                                                  k,
                                                                                                                  textAlign: TextAlign.center,
                                                                                                                  style: const TextStyle(
                                                                                                                    fontSize: 11,
                                                                                                                    color: Color(0xFF007AFF),
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                  ),
                                                                                                                ))
                                                                                                            .toList(),
                                                                                                      ),
                                                                                                    ),
                                                                                                  );
                                                                                                },
                                                                                              ),
                                                                                            ),
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
      height: 54,
      color: Colors.transparent,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44, height: 54,
              child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
            ),
          ),
          Expanded(
            child: Text(
              '群成员(${widget.members.length})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF000000), fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showSearch = !_showSearch),
            child: const SizedBox(
              width: 44, height: 54,
              child: Icon(CupertinoIcons.search, color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _keyword = v.trim()),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  hintText: '搜索昵称或UID',
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() {
                _keyword = '';
                _showSearch = false;
              });
            },
            child: const Text('取消',
                style: TextStyle(color: Color(0xFF007AFF), fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> m) {
    final avatar = _fullAvatarUrl(m['avatar']?.toString() ?? '');
    final nickname = m['nickname']?.toString() ?? '';
    final roleBadge = m['role_badge']?.toString() ?? '';
    final roleBadgeColor = m['role_badge_color']?.toString() ?? '';

    return GestureDetector(
      onLongPress: () => _onLongPress(m),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: _itemBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 38, height: 38,
                color: const Color(0xFFE6F2FF),
                                                              child: avatar.isEmpty
                                                                  ? const Icon(Icons.person, color: Color(0xFF007AFF), size: 20)
                                                                  : Image.network(
                                                                      avatar,
                                                                      width: 38, height: 38, fit: BoxFit.cover,
                                                                      errorBuilder: (_, __, ___) =>
                                                                          const Icon(Icons.person, color: Color(0xFF007AFF), size: 20),
                                                                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              ),
            ),
            if (widget.canSeeBadge && roleBadge.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _hexColor(roleBadgeColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  roleBadge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}