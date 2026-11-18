import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_cache_manager.dart';

import '../core/config.dart';
import '../core/http_client.dart';
import 'liuhecai_share_group_page.dart';
import 'liuhecai_room_setting_page.dart';
import 'liuhecai_room_announcement_page.dart';
import 'liuhecai_rule_page.dart';
import 'liuhecai_game_settings_page.dart';
import 'liuhecai_shareholder_apply_page.dart';
import 'liuhecai_under_page.dart';
import 'liuhecai_rebate_setting_page.dart';
import 'liuhecai_transactions_page.dart';
import 'webview_page.dart';

class LiuhecaiRoomInfoPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiRoomInfoPage({super.key, required this.roomid});

  @override
  State<LiuhecaiRoomInfoPage> createState() => _LiuhecaiRoomInfoPageState();
}

class _LiuhecaiRoomInfoPageState extends State<LiuhecaiRoomInfoPage> {
  bool _loading = true;
  int _myUid = 0;
  bool _isOwner = false;
  bool _isFinance = false;
  bool _showSaEntry = false;
  Map<String, dynamic> _gameSettings = {};

  String _roomName = '';
  double _roomMin = 0;
  double _roomMax = 0;
  String _announcement = '';
  bool _isClosed = false;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _finances = [];
  bool _membersExpanded = false;

  bool _kfc = false;
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
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiRoomInfo}&act=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final roominfo = r['roominfo'] is Map ? Map<String, dynamic>.from(r['roominfo']) : <String, dynamic>{};
        final member = r['member'] is Map ? Map<String, dynamic>.from(r['member']) : <String, dynamic>{};

        final members = (r['members'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        final finances = (r['finances'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        final userRoleSa = int.tryParse(r['user_role_sa']?.toString() ?? '0') ?? 0;

        final myUid = int.tryParse(member['id']?.toString() ?? '0') ?? 0;
        final isOwner = _truthy(r['is_owner']);
        final isFinance = finances.any((f) => int.tryParse(f['id']?.toString() ?? '0') == myUid);

        if (mounted) {
          setState(() {
            _myUid = myUid;
            _isOwner = isOwner;
            _isFinance = isFinance;
            _showSaEntry = isOwner || userRoleSa == 1 || userRoleSa == 2;

            _roomName = roominfo['roomname']?.toString() ?? '';
            _roomMin = double.tryParse(roominfo['min']?.toString() ?? '0') ?? 0;
            _roomMax = double.tryParse(roominfo['max']?.toString() ?? '0') ?? 0;
            _announcement = r['announcement']?.toString() ?? '';
            _isClosed = _truthy(r['is_closed']);

            _gameSettings = r['game_settings'] is Map ? Map<String, dynamic>.from(r['game_settings']) : <String, dynamic>{};

            _members = members;
            _finances = finances;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_room_info get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)));
  }

  Future<void> _editRoomName() async {
    if (!_isOwner) return;
    final ctrl = TextEditingController(text: _roomName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改群名称'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '请输入新的群名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _roomName) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiRoomInfo}&act=update_roomname&roomid=${widget.roomid}',
        data: {'roomname': newName, 'roomid': widget.roomid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) { try { data = jsonDecode(data); } catch (_) {} }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('修改成功');
        setState(() => _roomName = newName);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '修改失败') : '修改失败');
      }
    } catch (e) { _toast('网络错误'); }
  }

  Future<void> _toggleClose(bool v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text(v ? '确定要开启封盘吗？全员将无法发送红包' : '确定要取消封盘吗？\n（关封盘会清空今天的期数据，从新序号开始）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiRoomInfo}&act=toggle_close&roomid=${widget.roomid}',
        data: {'status': v ? 1 : 0},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) { try { data = jsonDecode(data); } catch (_) {} }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('操作成功');
        setState(() => _isClosed = v);
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '操作失败') : '操作失败');
      }
    } catch (e) { _toast('网络错误'); }
  }

  // ============ 长按头像弹出操作菜单（已移除免死相关） ============
  Future<void> _onMemberLongPress(Map<String, dynamic> m) async {
    final isVirtual = _truthy(m['is_virtual']);
    final isSelf = _truthy(m['is_self']);
    final uid = int.tryParse(m['id']?.toString() ?? '0') ?? 0;

    if (isVirtual) {
      _toast('虚拟人物无法操作');
      return;
    }
    if (isSelf || uid == _myUid) {
      _toast('不能操作自己');
      return;
    }
    if (!_isOwner && !_isFinance) {
      _toast('您没有管理权限');
      return;
    }

    final nickname = m['nickname']?.toString() ?? '';

    // 动态组装菜单项
    final items = <Widget>[];
    if (_isOwner) {
      items.add(_sheetItem('设为财务', Icons.attach_money, const Color(0xFF007AFF), () => Navigator.pop(context, 'set_finance')));
      items.add(_sheetItem('取消财务', Icons.remove_circle_outline, const Color(0xFF333333), () => Navigator.pop(context, 'remove_finance')));
    }
    items.add(_sheetItem('踢出群聊', Icons.person_remove, const Color(0xFFE94848), () => Navigator.pop(context, 'kick_member')));

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
              Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFD0E4FF), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              ...items,
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
      case 'set_finance': await _setRole(uid, 1); break;
      case 'remove_finance': await _setRole(uid, 0); break;
      case 'kick_member': await _kickMember(uid, nickname); break;
    }
  }

  Widget _sheetItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
        '${ApiConfig.liuhecaiRoomInfo}&act=set_role&roomid=${widget.roomid}',
        data: {'uid': uid, 'role': role},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) { try { data = jsonDecode(data); } catch (_) {} }
      _toast(data is Map ? (data['msg']?.toString() ?? '操作完成') : '操作完成');
      if (data is Map && data['code']?.toString() == '1') _loadData();
    } catch (e) { _toast('网络错误'); }
  }

  Future<void> _kickMember(int uid, String nickname) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: Text('确定将【$nickname】移出群聊吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiRoomInfo}&act=kick_member&roomid=${widget.roomid}',
        data: {'uid': uid, 'roomid': widget.roomid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) { try { data = jsonDecode(data); } catch (_) {} }
      _toast(data is Map ? (data['result']?.toString() ?? '已踢出') : '已踢出');
      if (data is Map && data['status']?.toString() == '1') {
        setState(() { _members.removeWhere((e) => e['id']?.toString() == uid.toString()); });
      }
    } catch (e) { _toast('网络错误'); }
  }

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
    _toast('清除成功');
  }

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

  String _fullAvatarUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('../')) return '${ApiConfig.baseUrl}/${raw.replaceFirst('../', '')}';
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String _stripHtml(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"');
  }

  String _fmt(double v) { if (v == v.roundToDouble()) return v.toInt().toString(); return v.toString(); }

  Color _hexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }

  // ============ 打开全屏成员列表 ============
  void _openMemberList() {
    final canSeeBadge = _isOwner || _isFinance;
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => _MemberListModal(
        members: _members,
        myUid: _myUid,
        isOwner: _isOwner,
        isFinance: _isFinance,
        canSeeBadge: canSeeBadge,
        onAction: (action, uid, nickname) async {
          await _handleMemberAction(action, uid, nickname);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              _buildHeader(),
              Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody()),
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
          Positioned(left: 8, top: 0, bottom: 0, child: GestureDetector(onTap: () => Navigator.of(context).pop(), child: const SizedBox(width: 40, height: 44, child: Icon(CupertinoIcons.back, color: Colors.black, size: 22)))),
          const Center(child: Text('房间信息', style: TextStyle(color: Color(0xFF000000), fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
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

  // ============ 群成员卡片 ============
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

    final canSeeBadge = _isOwner || _isFinance;

    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const crossSpacing = 6.0;
                final itemWidth = (constraints.maxWidth - crossSpacing * (crossAxisCount - 1)) / crossAxisCount;
                final items = <Widget>[];
                for (int i = 0; i < displayItems; i++) {
                  items.add(SizedBox(width: itemWidth, child: _buildMemberItem(_members[i], itemWidth, canSeeBadge)));
                }
                if (showViewBtn) {
                  items.add(SizedBox(width: itemWidth, child: _buildViewMoreItem(itemWidth)));
                }
                return Wrap(spacing: crossSpacing, runSpacing: 12, children: items);
              },
            ),
          ),
          if (total > collapseCount)
            GestureDetector(
              onTap: () {
                if (!_membersExpanded) {
                  setState(() => _membersExpanded = true);
                } else {
                  setState(() => _membersExpanded = false);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6)))),
                alignment: Alignment.center,
                child: Text(_membersExpanded ? '收起' : '查看全部群成员', style: const TextStyle(fontSize: 14, color: Color(0xFF007AFF), fontWeight: FontWeight.w500)),
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
      behavior: HitTestBehavior.opaque,
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
                  : Image(
                      image: CachedNetworkImageProvider(avatar, cacheManager: AppCacheManager.instance),
                      width: avatarSize, height: avatarSize, fit: BoxFit.cover, gaplessPlayback: true,
                      frameBuilder: (_, child, __, ___) => child,
                      loadingBuilder: (_, child, progress) => progress == null ? child : Icon(Icons.person, color: const Color(0xFF007AFF), size: avatarSize * 0.5),
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: const Color(0xFF007AFF), size: avatarSize * 0.5),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(nickname, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
          if (canSeeBadge && roleBadge.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: _hexColor(roleBadgeColor), borderRadius: BorderRadius.circular(6)),
              child: Text(roleBadge, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500)),
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
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5)),
            alignment: Alignment.center,
            child: const Text('查看', style: TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 4),
          const Text('更多成员', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF555555))),
        ],
      ),
    );
  }

  Widget _buildBaseInfoCard() {
    final roomNameDisplay = '【$_roomName】${_fmt(_roomMin)}-${_fmt(_roomMax)}元';
    final annDisplay = _announcement.isEmpty ? '点击设置' : _stripHtml(_announcement);

    return _card([
      _buildFieldRow('群聊名称', value: roomNameDisplay, onTap: _isOwner ? _editRoomName : null, trailing: _isOwner ? const Text('✎', style: TextStyle(fontSize: 16, color: Color(0xFF007AFF))) : null),
      _buildArrowRow('分享群ID', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiShareGroupPage(roomid: widget.roomid))); }),
      if (_isOwner) _buildArrowRow('群设置', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiRoomSettingPage(roomid: widget.roomid))); }),
      _buildArrowRow('群公告', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiRoomAnnouncementPage(roomid: widget.roomid))).then((_) => _loadData()); }, value: annDisplay),
      _buildArrowRow('赔率介绍', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiRulePage(roomid: widget.roomid))); }),
      if (_isOwner) _buildArrowRow('玩法设置', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiGameSettingsPage(roomid: widget.roomid, gameSettings: _gameSettings))).then((_) => _loadData()); }, isLast: true),
    ]);
  }

  Widget _buildCoreApps() {
    return _card([
      if (_showSaEntry) _buildArrowRow('股东与代理', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiShareholderApplyPage(roomid: widget.roomid))); }),
      _buildArrowRow('我的下级', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiUnderPage(roomid: widget.roomid))); }),
      _buildArrowRow('推广奖励', () { _toast('推广奖励开发中'); }, isLast: true),
    ]);
  }

  Widget _buildOwnerPanel() {
    return _card([
      _buildArrowRow('玩家返点设置', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiRebateSettingPage(roomid: widget.roomid))); }),
      _buildArrowRow('充值详情', () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiuhecaiTransactionsPage(roomid: widget.roomid))); }),
      Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Expanded(child: Text('开启封盘', style: TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500))),
            const Text('全员禁发', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
            const SizedBox(width: 8),
            Switch(value: _isClosed, onChanged: _toggleClose, activeColor: Colors.white, activeTrackColor: const Color(0xFF34C759)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildChatSettings() {
    return _card([
      _buildSwitchRow('消息免打扰', _kfc, (v) => setState(() => _kfc = v)),
      _buildSwitchRow('置顶聊天', _mim, (v) => setState(() => _mim = v)),
      _buildSwitchRow('保存到通讯录', _book, (v) => setState(() => _book = v)),
      _buildArrowRow('清空聊天记录', _clearChat, isLast: true),
    ]);
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: const Color(0xFF34C759)),
        ],
      ),
    );
  }

  Widget _buildExitBtn() {
    return GestureDetector(
      onTap: _exitGroup,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: const Text('退出群聊', style: TextStyle(fontSize: 16, color: Color(0xFFE94848), fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildFieldRow(String label, {String? value, VoidCallback? onTap, Widget? trailing}) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6)))),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
          const Spacer(),
          if (value != null && value.isNotEmpty) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFF888888)))),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
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
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.6)))),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
            const Spacer(),
            if (value != null && value.isNotEmpty) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFF888888)))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
//                  全屏群成员列表弹窗（已移除免死相关）
// ====================================================================
class _MemberListModal extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final int myUid;
  final bool isOwner;
  final bool isFinance;
  final bool canSeeBadge;
  final Future<void> Function(String action, int uid, String nickname) onAction;

  const _MemberListModal({
    required this.members,
    required this.myUid,
    required this.isOwner,
    required this.isFinance,
    required this.canSeeBadge,
    required this.onAction,
  });

  @override
  State<_MemberListModal> createState() => _MemberListModalState();
}

class _MemberListModalState extends State<_MemberListModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showSearch = false;
  String _keyword = '';
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
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
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut, alignment: 0.0);
    }
  }

  Future<void> _onLongPress(Map<String, dynamic> m) async {
    final isVirtual = _truthy(m['is_virtual']);
    final isSelf = _truthy(m['is_self']);
    final uid = int.tryParse(m['id']?.toString() ?? '0') ?? 0;

    if (isVirtual) {
      _toast('虚拟人物无法操作');
      return;
    }
    if (isSelf || uid == widget.myUid) {
      _toast('不能操作自己');
      return;
    }
    if (!widget.isOwner && !widget.isFinance) {
      _toast('您没有管理权限');
      return;
    }

    final nickname = m['nickname']?.toString() ?? '';

    final items = <Widget>[];
    if (widget.isOwner) {
      items.add(_sheetItem('设为财务', Icons.attach_money, const Color(0xFF007AFF), () => Navigator.pop(context, 'set_finance')));
      items.add(_sheetItem('取消财务', Icons.remove_circle_outline, const Color(0xFF333333), () => Navigator.pop(context, 'remove_finance')));
    }
    items.add(_sheetItem('踢出群聊', Icons.person_remove, const Color(0xFFE94848), () => Navigator.pop(context, 'kick_member')));

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              const SizedBox(height: 12),
              ...items,
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    await widget.onAction(action, uid, nickname);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)));
  }

  Widget _sheetItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
    final keys = grouped.keys.toList()..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              _buildTopBar(),
              if (_showSearch) _buildSearchBar(),
              Expanded(
                child: keys.isEmpty
                    ? const Center(child: Text('暂无成员', style: TextStyle(color: Color(0xFF999999), fontSize: 14)))
                    : Stack(
                        children: [
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    color: Colors.white.withOpacity(0.35),
                                    child: Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                                  ),
                                  ...list.map(_buildItem),
                                ],
                              );
                            }).toList(),
                          ),
                          Positioned(
                            right: 0, top: 0, bottom: 10,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final itemHeight = constraints.maxHeight / keys.length;
                                int idxOf(double dy) => ((dy / itemHeight).floor()).clamp(0, keys.length - 1);
                                return Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (e) => _scrollTo(keys[idxOf(e.localPosition.dy)]),
                                  onPointerMove: (e) => _scrollTo(keys[idxOf(e.localPosition.dy)]),
                                  child: Container(
                                    width: 30,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: keys.map((k) => Text(k, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w600))).toList(),
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
            behavior: HitTestBehavior.opaque,
            child: Container(width: 54, height: 54, alignment: Alignment.center, child: const Icon(CupertinoIcons.back, color: Colors.black, size: 24)),
          ),
          Expanded(
            child: Text('群成员(${widget.members.length})', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF000000), fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => setState(() => _showSearch = !_showSearch),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(width: 44, height: 54, child: Icon(CupertinoIcons.search, color: Colors.black, size: 22)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _keyword = v.trim()),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), hintText: '搜索昵称或UID', hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() { _keyword = ''; _showSearch = false; });
            },
            behavior: HitTestBehavior.opaque,
            child: const Text('取消', style: TextStyle(color: Color(0xFF007AFF), fontSize: 14, fontWeight: FontWeight.w500)),
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
                    : Image(
                        image: CachedNetworkImageProvider(avatar, cacheManager: AppCacheManager.instance),
                        width: 38, height: 38, fit: BoxFit.cover, gaplessPlayback: true,
                        frameBuilder: (_, child, __, ___) => child,
                        loadingBuilder: (_, child, progress) => progress == null ? child : const Icon(Icons.person, color: Color(0xFF007AFF), size: 20),
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF007AFF), size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Color(0xFF111111)))),
            if (widget.canSeeBadge && roleBadge.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _hexColor(roleBadgeColor), borderRadius: BorderRadius.circular(8)),
                child: Text(roleBadge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}