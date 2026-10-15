import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import '../core/http_client.dart';
import '../core/sound_player.dart';
import '../core/data_cache.dart';                                   // ★ 新增
import '../widgets/red_packet_widgets.dart';
import '../widgets/send_red_packet_sheet.dart';
import 'chat_room_page.dart';
import 'recharge_page.dart';
import 'redlog_page.dart';
import 'sailei_room_info_page.dart';
import 'webview_page.dart';
import 'lunpan_page.dart';

class RedPacketRoomPage extends StatefulWidget {
  final int roomid;
  final String roomName;
  const RedPacketRoomPage({
    super.key,
    required this.roomid,
    required this.roomName,
  });

  @override
  State<RedPacketRoomPage> createState() => _RedPacketRoomPageState();
}

class _RedPacketRoomPageState extends State<RedPacketRoomPage> {
  String _announcement = '';
  int _myUid = 0;
  int _ownerUid = 0;
  double _roomMin = 0;
  double _roomMax = 999999;
  bool _noPayPwd = false;
  List<Map<String, dynamic>> _finances = [];

  final List<Map<String, dynamic>> _messages = [];

  bool _showMorePanel = false;
  final TextEditingController _inputCtrl = TextEditingController();
  bool _hasText = false;
  final FocusNode _inputFocus = FocusNode();

  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  bool _isAtBottom = true;

  final Set<String> _myClaimed = {};

  IO.Socket? _socket;
  Timer? _statusTimer;
  Timer? _cacheWriteTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _inputFocus.addListener(_onInputFocusChanged);
    _loadInitial();
    _connectSocket();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollRedPacketStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _cacheWriteTimer?.cancel();
    _socket?.disconnect();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _inputFocus.unfocus();
    _inputFocus.removeListener(_onInputFocusChanged);
    _inputFocus.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

    Future<void> _loadInitial() async {
      // ① 先用缓存秒渲染（5 分钟内有效）
      if (_messages.isEmpty) {
        final cached = DataCache.get('rp_room_${widget.roomid}');
        final cachedTime = DataCache.getTime('rp_room_${widget.roomid}');
        if (cached is Map &&
            cachedTime != null &&
            DateTime.now().difference(cachedTime).inMinutes < 5) {
          try {
            final r = Map<String, dynamic>.from(cached);
            final member = r['member'] is Map
                ? Map<String, dynamic>.from(r['member'])
                : <String, dynamic>{};
            final roominfo = r['roominfo'] is Map
                ? Map<String, dynamic>.from(r['roominfo'])
                : <String, dynamic>{};
            final list = (r['old_messages'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final fins = (r['finances'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            if (mounted) {
              setState(() {
                _myUid = int.tryParse(member['id']?.toString() ?? '0') ?? 0;
                _ownerUid = int.tryParse(r['owner_uid']?.toString() ?? '0') ?? 0;
                _announcement = roominfo['announcement']?.toString() ?? '';
                _roomMin = double.tryParse(r['min']?.toString() ?? '0') ?? 0;
                _roomMax = double.tryParse(r['max']?.toString() ?? '999999') ?? 999999;
                _noPayPwd = (r['nopaypwd']?.toString() == '1');
                _finances = fins;

                _messages.clear();
                for (final m in list) {
                  if (m['type']?.toString() == '7') continue;
                  if (m['type']?.toString() == '0' && m['contents'] is Map) {
                    final c = m['contents'] as Map;
                    final setid = c['setid']?.toString() ?? '';
                    if (_myClaimed.contains(setid)) {
                      c['isget'] = 1;
                    }
                  }
                  _messages.add(m);
                }
                _loading = false;
              });
              _scrollToBottom(animate: false);
            }
          } catch (_) {}
        }
      }

      // ② 后台请求
      try {
        final res = await HttpClient.instance.dio.post(
          '${ApiConfig.redpackets}&roomid=${widget.roomid}',
          data: {'op': 'get_data', 'roomid': widget.roomid},
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
          final r = Map<String, dynamic>.from(data['result']);
          final member = r['member'] is Map
              ? Map<String, dynamic>.from(r['member'])
              : <String, dynamic>{};
          final roominfo = r['roominfo'] is Map
              ? Map<String, dynamic>.from(r['roominfo'])
              : <String, dynamic>{};

          final list = (r['old_messages'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final fins = (r['finances'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          if (!mounted) return;
          setState(() {
            _myUid = int.tryParse(member['id']?.toString() ?? '0') ?? 0;
            _ownerUid = int.tryParse(r['owner_uid']?.toString() ?? '0') ?? 0;
            _announcement = roominfo['announcement']?.toString() ?? '';
            _roomMin = double.tryParse(r['min']?.toString() ?? '0') ?? 0;
            _roomMax = double.tryParse(r['max']?.toString() ?? '999999') ?? 999999;
            _noPayPwd = (r['nopaypwd']?.toString() == '1');
            _finances = fins;

            _messages.clear();
            for (final m in list) {
              if (m['type']?.toString() == '7') continue;
              if (m['type']?.toString() == '0' && m['contents'] is Map) {
                final c = m['contents'] as Map;
                final setid = c['setid']?.toString() ?? '';
                if (_myClaimed.contains(setid)) {
                  c['isget'] = 1;
                }
              }
              _messages.add(m);
            }
            _loading = false;
          });
          _scrollToBottom(animate: false);

          // ★ 写缓存
          await DataCache.set('rp_room_${widget.roomid}', data['result']);
        } else {
          if (mounted) setState(() => _loading = false);
        }
      } catch (e) {
        debugPrint('❌ [room get_data] $e');
        if (mounted) setState(() => _loading = false);
      }
    }

    /// 节流写缓存：800ms 内多次调用只写一次
    /// 从当前 State 重建 JSON，避免直接从 _messages 存（缺少 member/roominfo 等字段）
    void _scheduleCacheWrite() {
      _cacheWriteTimer?.cancel();
      _cacheWriteTimer = Timer(const Duration(milliseconds: 800), () async {
        if (!mounted) return;
        final payload = <String, dynamic>{
          'member': {'id': _myUid},
          'roominfo': {'announcement': _announcement},
          'owner_uid': _ownerUid,
          'min': _roomMin,
          'max': _roomMax,
          'nopaypwd': _noPayPwd ? 1 : 0,
          'finances': _finances,
          'old_messages': _messages,
        };
        await DataCache.set('rp_room_${widget.roomid}', payload);
      });
    }

  void _connectSocket() {
    try {
      _socket = IO.io(
        ApiConfig.baseUrl,
        <String, dynamic>{
          'transports': ['websocket', 'polling'],
          'autoConnect': true,
          'reconnection': true,
          'reconnectionAttempts': 9999,
          'reconnectionDelay': 2000,
          'forceNew': true,   // ★★★ 每次独立 socket，不复用
        },
      );

      _socket!.onConnect((_) {
        debugPrint('✅ socket connected');
        _socket!.emit('addgroup', widget.roomid);
        final ts = DateTime.now().millisecondsSinceEpoch;
        _socket!.emit('login', '${ts}r${_myUid}r${widget.roomid}');
      });

      _socket!.on('roominfo', (msg) {
        try {
          final str = msg.toString().replaceAll('&quot;', '"');
          final list = jsonDecode(str);
          if (list is! List) return;
          for (final item in list) {
            final m = Map<String, dynamic>.from(item);
            if (m['type']?.toString() == '7') {
              _handleDoneBroadcast(m);
              continue;
            }
            if (_messages.any((e) => e['id'] == m['id'])) continue;
            if (m['contents'] is Map) {
              final c = Map<String, dynamic>.from(m['contents']);
              c['isget'] ??= 0;
              c['total_nums'] ??= c['nums'] ?? 0;
              final setid = c['setid']?.toString() ?? '';
              if (_myClaimed.contains(setid)) {
                c['isget'] = 1;
              }
              m['contents'] = c;
            }
            _messages.add(m);
          }
          if (mounted) {
            setState(() {});
            if (_isAtBottom) _scrollToBottom();
          }
        } catch (e) {
          debugPrint('❌ [roominfo] $e');
        }
      });

      _socket!.onDisconnect((_) => debugPrint('⚠️ socket disconnected'));
      _socket!.onConnectError((e) => debugPrint('❌ socket error: $e'));

      _socket!.connect();
    } catch (e) {
      debugPrint('❌ [socket init] $e');
    }
  }

    void _handleDoneBroadcast(Map<String, dynamic> m) {
      final contents = m['contents'];
      if (contents is! Map) return;
      final redid = contents['redid']?.toString();
      if (redid == null) return;
      for (final msg in _messages) {
        if (msg['type']?.toString() == '0' && msg['contents'] is Map) {
          final c = msg['contents'] as Map;
          if (c['setid']?.toString() == redid) {
            c['nums'] = 0;
          }
        }
      }
      if (mounted) setState(() {});
      _scheduleCacheWrite();   // ★ 新增
    }

  Future<void> _pollRedPacketStatus() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'get_data', 'roomid': widget.roomid},
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
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['old_messages'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final redMap = <String, Map<String, dynamic>>{};
        for (final m in list) {
          if (m['type']?.toString() == '0' && m['contents'] is Map) {
            final c = Map<String, dynamic>.from(m['contents']);
            redMap[c['setid']?.toString() ?? ''] = c;
          }
        }
        bool changed = false;
        for (final msg in _messages) {
          if (msg['type']?.toString() != '0' || msg['contents'] is! Map) continue;
          final c = msg['contents'] as Map;
          final id = c['setid']?.toString() ?? '';
          if (!redMap.containsKey(id)) continue;

          final fresh = redMap[id]!;
          final bool claimed = _myClaimed.contains(id);

          if (claimed) {
            if (c['nums'] != fresh['nums']) {
              c['nums'] = fresh['nums'];
              changed = true;
            }
            if (c['isget']?.toString() != '1') {
              c['isget'] = 1;
              changed = true;
            }
            if (c['total_nums'] != fresh['total_nums']) {
              c['total_nums'] = fresh['total_nums'] ?? c['total_nums'];
              changed = true;
            }
          } else {
            if (c['nums'] != fresh['nums']) {
              c['nums'] = fresh['nums'];
              changed = true;
            }
            if (c['total_nums'] != fresh['total_nums']) {
              c['total_nums'] = fresh['total_nums'] ?? c['total_nums'];
              changed = true;
            }
          }
        }
        if (changed && mounted) {
          setState(() {});
          _scheduleCacheWrite();   // ★ 新增
        }
      }
    } catch (e) {
      debugPrint('❌ [poll] $e');
    }
  }

  Future<void> _sendText() async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;

    final isRecharge = RegExp(r'^充值\s*\d+$').hasMatch(content);
    final isWithdraw = RegExp(r'^提现\s*\d+$').hasMatch(content);
    final needJump = isRecharge || isWithdraw;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'setmess', 'type': 6, 'content': content},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        if (data['status']?.toString() == '0') {
          _toast(data['result']?.toString() ?? data['msg']?.toString() ?? '发送失败');
          return;
        }
        _inputCtrl.clear();
        setState(() => _hasText = false);
        _inputFocus.unfocus();

        final redirect = data['redirect']?.toString() ?? '';
        if (redirect.isNotEmpty) {
          _toast('充值申请已提交，正在跳转...');
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WebViewPage(url: redirect, title: '财务'),
              ),
            );
          }
        } else if (needJump && _finances.isNotEmpty) {
          final fuid = _finances.first['id']?.toString() ?? '';
          if (fuid.isNotEmpty) {
            _toast('充值申请已提交，正在跳转...');
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WebViewPage(
                    url: '${ApiConfig.chatRoom}&fuid=$fuid',
                    title: '财务',
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [setmess] $e');
      _toast('网络错误，请重试');
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    _isAtBottom = pos.pixels >= pos.maxScrollExtent - 60;
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  void _onInputFocusChanged() {
    if (_inputFocus.hasFocus && _showMorePanel && mounted) {
      setState(() => _showMorePanel = false);
    }
  }

  String _stripHtml(String raw) {
    return raw
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_inputFocus.hasFocus) _inputFocus.unfocus();
                if (_showMorePanel && mounted) {
                  setState(() => _showMorePanel = false);
                }
              },
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  _buildHeader(),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMessageList(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
                    ),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 16
                          : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInputBar(),
                        _buildFunctionPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

  // ---- 顶部栏（含群公告跑马灯） ----
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
          // ★ 群公告跑马灯（保留）
          Expanded(
            child: _announcement.isEmpty
                ? const Text(
                    '暂无群公告',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  )
                : _MarqueeText(
                    text: _announcement,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadInitial,
            child: const SizedBox(
              width: 36, height: 36,
              child: Icon(Icons.refresh, color: Colors.black, size: 20),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaileiRoomInfoPage(roomid: widget.roomid),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.more_horiz, color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 消息列表 ----
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text('暂无消息', style: TextStyle(color: Color(0xFF999999))),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildMessage(_messages[i]),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> m) {
    final type = m['type']?.toString() ?? '';
    final uid = int.tryParse(m['uid']?.toString() ?? '0') ?? 0;
    final isSelf = uid == _myUid;
    final contents = m['contents'] is Map
        ? Map<String, dynamic>.from(m['contents'])
        : <String, dynamic>{};

    switch (type) {
      case '0':
        return _buildRedPacketBubble(contents, isSelf);
      case '1':
        if (uid == _myUid) return _buildSystemBubble(contents);
        return const SizedBox.shrink();
      case '2':
      case '4':
        if (type == '4' && uid != _myUid) return const SizedBox.shrink();
        return _buildSystemBubble(contents);
      case '3':
        return _buildWelfareBubble(contents);
      case '5':
        return _buildImageBubble(contents, isSelf);
      case '6':
        return _buildTextBubble(contents, isSelf);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRedPacketBubble(Map<String, dynamic> c, bool isSelf) {
    final nickname = c['nickname']?.toString() ?? '';
    final avatar = c['avatar']?.toString() ?? '';
    // ★★★ 封盘提示：走单独分支 ★★★
    if (int.tryParse(c['is_notice']?.toString() ?? '0') == 1) {
      return _buildNoticeBubble(c, isSelf);
    }
    final gold = c['gold']?.toString() ?? '0';
    final totalNums = c['total_nums']?.toString() ?? '0';
    final boom = c['boom']?.toString() ?? '';
    final nums = int.tryParse(c['nums']?.toString() ?? '0') ?? 0;
    final isget = int.tryParse(c['isget']?.toString() ?? '0') ?? 0;

    final inactive = nums <= 0 || isget == 1;
    final bottomText = isget == 1
        ? '已领取'
        : (nums <= 0 ? '已抢完' : '领取红包');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) _avatar(avatar, size: 38),
        if (!isSelf) const SizedBox(width: 8),
        Column(
          crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(nickname, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Opacity(
              opacity: inactive ? 0.6 : 1,
              child: GestureDetector(
                onTap: () => _onRedPacketTap(c),
                                                child: Container(
                                                  width: 240,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFE94848).withOpacity(0.12),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      Container(
                                                        height: 70,
                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                        decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [Color(0xFFFF7A38), Color(0xFFE94848)],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  '$gold-$totalNums-[$boom]',
                                                                  style: const TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  bottomText,
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: Colors.white.withOpacity(0.9),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Positioned(
                                                              right: 0, top: 0, bottom: 0,
                                                              child: Center(
                                                                child: _RedPacketIcon(
                                                                  width: 34,
                                                                  height: 40,
                                                                  isInactive: inactive,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        height: 24,
                                                        alignment: Alignment.centerLeft,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [Color(0xFFFF7A38), Color(0xFFE94848)],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          '简信红包',
                                                          style: TextStyle(fontSize: 11, color: Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
              ),
            ),
          ],
        ),
        if (isSelf) const SizedBox(width: 8),
        if (isSelf) _avatar(avatar, size: 38),
      ],
    );
  }

  // ★★★ 封盘提示卡片（红包样式，但不显示自绘小红包，底部改为"简信管家提示！"）
  Widget _buildNoticeBubble(Map<String, dynamic> c, bool isSelf) {
    final nickname = c['nickname']?.toString() ?? '';
    final avatar = c['avatar']?.toString() ?? '';
    final noticeText = c['notice_text']?.toString() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) _avatar(avatar, size: 38),
        if (!isSelf) const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(nickname,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Container(
              width: 215, // ★ 和普通红包卡保持一致
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A55C9).withOpacity(0.08), // 或用 Colors.black.withOpacity(0.05)
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 红色封面（不放小红包图标，文字居中，高度自适应）
                  Container(
                    constraints: const BoxConstraints(minHeight: 70),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFFDCFCE7)], // ★ 浅蓝 → 浅绿
                        begin: Alignment.centerLeft,                     // ★ 水平方向
                        end: Alignment.centerRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      noticeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),                        // ★ 深绿字，浅底上看更清楚
                        height: 1.5,
                      ),
                    ),
                  ),
                  // 底部条：改为"简信管家提示！"
                  Container(
                    height: 24,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFFDCFCE7)], // ★ 同色系，和封面一致
                        begin: Alignment.centerLeft,                     // ★ 水平方向
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: const Text(
                      '简信管家提示！',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1B5E20),                        // ★ 深绿字
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isSelf) const SizedBox(width: 8),
        if (isSelf) _avatar(avatar, size: 38),
      ],
    );
  }

  Widget _buildSystemBubble(Map<String, dynamic> c) {
    final content = _stripHtml(c['content']?.toString() ?? '');
    if (content.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          content,
          style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildWelfareBubble(Map<String, dynamic> c) {
    final nickname = c['nickname']?.toString() ?? '';
    final welfareName = c['welfare_name']?.toString() ?? '';
    final welfareNumber = c['welfare_number']?.toString() ?? '';
    final goldmoney = c['goldmoney']?.toString() ?? '0';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            children: [
              TextSpan(text: '@$nickname'),
              const TextSpan(text: ' 抢到 '),
              TextSpan(
                text: welfareName,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
              ),
              TextSpan(text: '（$welfareNumber） 领取奖励 '),
              TextSpan(
                text: goldmoney,
                style: const TextStyle(color: Color(0xFFE94848), fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ' 元'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildImageBubble(Map<String, dynamic> c, bool isSelf) {
    final avatar = c['avatar']?.toString() ?? '';
    final nickname = c['nickname']?.toString() ?? '';
    final content = c['content']?.toString() ?? '';

    // ★★★ 识别本地资源（约定：以 asset:// 开头）★★★
    final isAsset = content.startsWith('asset://');
    final assetPath = isAsset ? content.substring(8) : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) _avatar(avatar, size: 38),
        if (!isSelf) const SizedBox(width: 8),
        Column(
          crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(nickname, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isAsset
                    ? Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100, height: 100, color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      )
                    : Image.network(
                        content,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100, height: 100, color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (isSelf) const SizedBox(width: 8),
        if (isSelf) _avatar(avatar, size: 38),
      ],
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> c, bool isSelf) {
    final avatar = c['avatar']?.toString() ?? '';
    final nickname = c['nickname']?.toString() ?? '';
    final content = _stripHtml(c['content']?.toString() ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) _avatar(avatar, size: 38),
        if (!isSelf) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(nickname, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelf ? const Color(0xFF95EC69) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isSelf ? 8 : 2),
                    topRight: Radius.circular(isSelf ? 2 : 8),
                    bottomLeft: const Radius.circular(8),
                    bottomRight: const Radius.circular(8),
                  ),
                  boxShadow: isSelf
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isSelf) const SizedBox(width: 8),
        if (isSelf) _avatar(avatar, size: 38),
      ],
    );
  }

      Widget _avatar(String url, {double size = 38}) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: size, height: size,
            color: const Color(0xFFE6F2FF),
            child: url.isEmpty
                ? const Icon(Icons.person, color: Color(0xFF007AFF), size: 20)
                : Image.network(
                    url,
                    width: size, height: size, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, color: Color(0xFF007AFF), size: 20),
                  ),
          ),
        );
      }

  Future<void> _onRedPacketTap(Map<String, dynamic> c) async {
      _inputFocus.unfocus();
      final setid = c['setid']?.toString() ?? '';
      if (setid.isEmpty) return;

      final isget = int.tryParse(c['isget']?.toString() ?? '0') ?? 0;
      final nums = int.tryParse(c['nums']?.toString() ?? '0') ?? 0;

      // ★ 已领取 或 已抢完 → 直接进入详情页（不再走抢红包流程）
      if (isget == 1 || nums <= 0) {
        await _showRedDetail(setid);
        return;
      }

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'beforered', 'setid': setid, 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is! Map || data['result'] is! Map) {
        _toast('加载失败');
        return;
      }

      final r = Map<String, dynamic>.from(data['result']);
      final info = r['info'] is Map
          ? Map<String, dynamic>.from(r['info'])
          : <String, dynamic>{};
      final mess = r['mess']?.toString() ?? '恭喜发财,大吉大利';
      final canOpen = data['status']?.toString() == '1';

      if (!canOpen && mess.contains('抢过')) {
        for (final msg in _messages) {
          if (msg['type']?.toString() == '0' && msg['contents'] is Map) {
            final cc = msg['contents'] as Map;
            if (cc['setid']?.toString() == setid) {
              cc['isget'] = 1;
              cc['nums'] = 0;
            }
          }
        }
        if (mounted) setState(() {});
        await _showRedDetail(setid);
        return;
      }

      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) => RedPacketOpenDialog(
          nickname: info['nickname']?.toString() ?? '',
          avatar: info['avatar']?.toString() ?? '',
          message: mess,
          canOpen: canOpen,
        ),
      );

      if (action == 'open') {
        await _doOpenRed(setid);
      } else if (action == 'detail') {
        await _showRedDetail(setid);
      }
    } catch (e) {
      debugPrint('❌ [beforered] $e');
      _toast('网络错误');
    }
  }

  Future<void> _doOpenRed(String setid) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'gorobnow', 'setid': setid, 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is! Map) {
        _toast('数据异常');
        return;
      }

      final result = data['result']?.toString() ?? '操作完成';
      _toast(result);

      final ok = data['status']?.toString() == '1';
      final alreadyGet = result.contains('抢过') || result.contains('已抢');

      if (ok) {
        final isboom = int.tryParse(data['isboom']?.toString() ?? '0') ?? 0;
        if (isboom == 1) {
          SoundPlayer.instance.playBoom();
        } else {
          SoundPlayer.instance.playGrabSuccess();
        }
      }

      if (ok || alreadyGet) {
        _myClaimed.add(setid);
        for (final msg in _messages) {
          if (msg['type']?.toString() == '0' && msg['contents'] is Map) {
            final cc = msg['contents'] as Map;
            if (cc['setid']?.toString() == setid) {
              cc['isget'] = 1;
              cc['nums'] = 0;
            }
          }
        }
        if (mounted) setState(() {});
        _scheduleCacheWrite();

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) await _showRedDetail(setid);
      }
    } catch (e) {
      debugPrint('❌ [gorobnow] $e');
      _toast('网络错误');
    }
  }

  Future<void> _showRedDetail(String setid) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'getreddetail', 'setid': setid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is! Map || data['status']?.toString() != '1' || data['result'] is! Map) {
        _toast(data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败');
        return;
      }
      final r = Map<String, dynamic>.from(data['result']);
      if (!mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => RedPacketDetailPanel(
          data: r,
          onOpenReport: () {
            Navigator.of(context).pop();
            _showRedReport();
          },
        ),
        transitionBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    } catch (e) {
      debugPrint('❌ [getreddetail] $e');
      _toast('网络错误');
    }
  }

  Future<void> _showRedReport() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'getrecord', 'roomid': widget.roomid, 'type': 1},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is! Map || data['status']?.toString() != '1' || data['result'] is! Map) {
        _toast('加载失败');
        return;
      }
      final r = Map<String, dynamic>.from(data['result']);
      if (!mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => RedReportPanel(data: r),
        transitionBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    } catch (e) {
      debugPrint('❌ [getrecord] $e');
      _toast('网络错误');
    }
  }

  // ---- 输入栏 ----
  Widget _buildInputBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _inputFocus.unfocus();
              setState(() => _showMorePanel = !_showMorePanel);
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(
                _showMorePanel ? Icons.close : Icons.add,
                size: 22,
                color: const Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                onChanged: (v) {
                  final has = v.trim().isNotEmpty;
                  if (has != _hasText) setState(() => _hasText = has);
                },
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
                style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  hintText: '输入聊天内容...',
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _hasText ? _sendText : null,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _hasText
                    ? const Color(0xFF07C160)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.send,
                size: 18,
                color: _hasText ? Colors.white : const Color(0xFF999999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionPanel() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _showMorePanel
          ? _buildFunctionGrid()
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  Widget _buildFunctionGrid() {
    final items = [
      _FuncItem('发红包', null, const Color(0xFF5AC8FA), _onSendRed,
          customIcon: const _SendRedIcon()),
      _FuncItem('看余额', Icons.account_balance_wallet, const Color(0xFF5AC8FA), _onCheckBalance),
      _FuncItem('账单', Icons.receipt_long, const Color(0xFF5AC8FA), _onBill),
      // _FuncItem('充值', Icons.add_circle, const Color(0xFF5AC8FA), _onRecharge),
      _FuncItem('幸运抽奖', null, const Color(0xFF5AC8FA), _onLottery,
          customIcon: const _LotteryWheelIcon()),
      _FuncItem('抢包奖励', Icons.emoji_events, const Color(0xFF5AC8FA), _onReward),
      _FuncItem('联系财务', Icons.support_agent, const Color(0xFF5AC8FA), _onFinance),
      _FuncItem('联系群主', Icons.verified_user, const Color(0xFF5AC8FA), _onOwner),
      _FuncItem('照片', Icons.image, const Color(0xFF5AC8FA), _onPhoto),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        physics: const NeverScrollableScrollPhysics(),
        children: items.map((it) {
          return GestureDetector(
            onTap: it.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: it.customIcon ?? Icon(it.icon, size: 30, color: it.color),
                ),
                const SizedBox(height: 6),
                Text(it.label, style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _onSendRed() async {
    setState(() => _showMorePanel = false);

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => SendRedPacketSheet(
        roomid: widget.roomid,
        roomMin: _roomMin,
        roomMax: _roomMax,
        noPayPwd: _noPayPwd,
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

    if (ok == true && mounted) {
      _scrollToBottom();
    }
  }

  Future<void> _onCheckBalance() async {
    setState(() => _showMorePanel = false);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'getmymoney', 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      final v = res.data?.toString() ?? '0.00';
      final bal = double.tryParse(v) ?? 0;
      _toast('当前可用余额：${bal.toStringAsFixed(2)} 元');
    } catch (e) {
      _toast('查询失败');
    }
  }

  void _onBill() {
    setState(() => _showMorePanel = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RedlogPage(roomid: widget.roomid),
      ),
    );
  }

  void _onRecharge() {
    setState(() => _showMorePanel = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RechargePage()),
    );
  }

  void _onLottery() {
    setState(() => _showMorePanel = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LunpanPage(roomid: widget.roomid),
      ),
    );
  }

  void _onReward() {
    setState(() => _showMorePanel = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('抢包奖励'),
        content: const Text('顺子/豹子/特殊数字奖励\n满足条件系统将自动发放，无需手动领取。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _onFinance() {
    setState(() => _showMorePanel = false);
    if (_finances.isEmpty) {
      _toast('暂无财务人员');
      return;
    }
    if (_finances.length == 1) {
      final fuid = int.tryParse(_finances.first['id']?.toString() ?? '0') ?? 0;
      if (fuid <= 0) {
        _toast('财务信息异常');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(fuid: fuid)),
      );
    } else {
      _toast('请前往通讯录查找财务人员');
    }
  }

  void _onOwner() {
    setState(() => _showMorePanel = false);
    if (_ownerUid <= 0) {
      _toast('无法获取群主信息');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(fuid: _ownerUid)),
    );
  }

  Future<void> _onPhoto() async {
    setState(() => _showMorePanel = false);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (xfile == null) return;

      _toast('上传中…');
      final bytes = await xfile.readAsBytes();
      final name = xfile.name.isEmpty ? 'photo.jpg' : xfile.name;

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: name),
      });

      final uploadRes = await HttpClient.instance.dio.post(
        ApiConfig.uploadImage,
        data: formData,
      );

      dynamic ud = uploadRes.data;
      if (ud is String) {
        try { ud = jsonDecode(ud); } catch (_) {}
      }
      debugPrint('📤 上传返回: $ud');

      String? url;
      if (ud is Map) {
        if (ud['url'] != null && ud['url'].toString().isNotEmpty) {
          url = ud['url'].toString();
        } else if (ud['result'] is Map && (ud['result'] as Map)['url'] != null) {
          url = (ud['result'] as Map)['url'].toString();
        } else if (ud['result'] is String && (ud['result'] as String).isNotEmpty) {
          url = ud['result'].toString();
        } else if (ud['data'] is Map && (ud['data'] as Map)['url'] != null) {
          url = (ud['data'] as Map)['url'].toString();
        }
      }
      if (url == null || url.isEmpty) {
        _toast('上传失败，请检查网络');
        return;
      }

      if (!url.startsWith('http')) {
        url = '${ApiConfig.baseUrl}/${url.replaceFirst(RegExp(r'^/+'), '')}';
      }

      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.redpackets}&roomid=${widget.roomid}',
        data: {'op': 'setmess', 'type': 5, 'content': url},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '0') {
        _toast(data['result']?.toString() ?? '发送失败');
      } else {
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ [photo] $e');
      _toast('上传失败：$e');
    }
  }
}

class _FuncItem {
  final String label;
  final IconData? icon;
  final Widget? customIcon;   // ★ 新增：优先使用自绘图标
  final Color color;
  final VoidCallback onTap;
  _FuncItem(this.label, this.icon, this.color, this.onTap, {this.customIcon});
}

// ================= 简易跑马灯 =================
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late ScrollController _ctrl;
  Timer? _timer;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_ctrl.hasClients) return;
      _offset += 1;
      final max = _ctrl.position.maxScrollExtent;
      if (_offset > max + 60) _offset = 0;
      _ctrl.jumpTo(_offset.clamp(0, max));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style, maxLines: 1),
          const SizedBox(width: 60),
          Text(widget.text, style: widget.style, maxLines: 1),
        ],
      ),
    );
  }
}

// ================= 自绘红包图标（“抢”字款） =================
class _RedPacketIcon extends StatelessWidget {
  final double width;
  final double height;
  final bool isInactive; // ★ 新增：熄灭状态
  const _RedPacketIcon({
    this.width = 34,
    this.height = 40,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _RedPacketIconPainter(isInactive: isInactive),
      ),
    );
  }
}

class _RedPacketIconPainter extends CustomPainter {
  final bool isInactive; // ★ 新增
  const _RedPacketIconPainter({this.isInactive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.18));

    // 1. 红包主体
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF5A5A), Color(0xFFD91F1F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    // 2. 顶部翻盖
    final flapBottom = h * 0.42;
    final flapPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, flapBottom)
      ..quadraticBezierTo(w / 2, flapBottom + w * 0.22, 0, flapBottom)
      ..close();

    canvas.drawPath(
      flapPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6E6E), Color(0xFFE02020)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, flapBottom)),
    );

    // 翻盖下沿高光
    final edgePath = Path()
      ..moveTo(0, flapBottom)
      ..quadraticBezierTo(w / 2, flapBottom + w * 0.22, w, flapBottom);
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.restore();

    // 3. 中心金色印章
    final center = Offset(w / 2, h * 0.52);
    // ★ 熄灭时圈变小一点
    final sealR = isInactive ? w * 0.18 : w * 0.28;

    // 阴影
    canvas.drawCircle(
      center + Offset(0, h * 0.025),
      sealR,
      Paint()..color = Colors.black.withOpacity(0.18),
    );

    // 金色底
    canvas.drawCircle(
      center,
      sealR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFFE8C15A)],
          stops: [0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: sealR)),
    );

    // 印章描边
    canvas.drawCircle(
      center,
      sealR,
      Paint()
        ..color = const Color(0xFFB98B2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

            // 4. 中间"抢"字（★ 熄灭时不绘制）
            if (!isInactive) {
              final tp = TextPainter(
                text: TextSpan(
                  text: '抢',
                  style: TextStyle(
                    color: const Color(0xFFB81F1F),
                    fontSize: sealR * 1.25,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
            }
  }

  @override
  bool shouldRepaint(covariant _RedPacketIconPainter oldDelegate) =>
      oldDelegate.isInactive != isInactive; // ★ 状态变了才重绘
}
// ================= 发红包图标（淡红色小信封） =================
class _SendRedIcon extends StatelessWidget {
  const _SendRedIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: CustomPaint(painter: _SendRedIconPainter()),
    );
  }
}

class _SendRedIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const mainColor = Color(0xFF5AC8FA);   // ★ 统一色
    final strokeW = w * 0.07;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeW / 2, strokeW / 2, w - strokeW, h - strokeW),
      Radius.circular(w * 0.22),
    );

    // 底：浅蓝
    canvas.drawRRect(rrect, Paint()..color = mainColor);

    // 描边：白
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // 翻盖弧线：白
    canvas.save();
    canvas.clipRRect(rrect);
    final flapY = h * 0.28;
    final dipY  = h * 0.45;
    final flapPath = Path()
      ..moveTo(0, flapY)
      ..quadraticBezierTo(w / 2, dipY + h * 0.05, w, flapY);
    canvas.drawPath(
      flapPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 0.9,
    );
    canvas.restore();

    // 中心圆环：白
    final center = Offset(w / 2, h * 0.40);
    final circleR = w * 0.13;
    canvas.drawCircle(center, circleR + strokeW * 0.6, Paint()..color = mainColor);
    canvas.drawCircle(
      center,
      circleR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 0.9,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= 幸运抽奖图标（转轮） =================
class _LotteryWheelIcon extends StatelessWidget {
  const _LotteryWheelIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _LotteryWheelPainter()),
    );
  }
}

class _LotteryWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final outerR = w * 0.48;
    final innerR = w * 0.36;

    // 外环：浅蓝径向渐变（浅 → 深）
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF8EE0FF), Color(0xFF5AC8FA)],
          stops: [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    // 内部扇区：白色
    const sections = 12;
    final sweep = 2 * math.pi / sections;
    for (int i = 0; i < sections; i++) {
      final startAngle = i * sweep - math.pi / 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          startAngle,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white);
    }

    // 扇区分割线
    final linePaint = Paint()
      ..color = const Color(0xFF5AC8FA)
      ..strokeWidth = 0.7;
    for (int i = 0; i < sections; i++) {
      final angle = i * sweep - math.pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        ),
        linePaint,
      );
    }

    // 内圈白描边
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = const Color(0xFF5AC8FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 中心轴
    canvas.drawCircle(center, w * 0.075, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      w * 0.075,
      Paint()
        ..color = const Color(0xFF5AC8FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(center, w * 0.032, Paint()..color = const Color(0xFF5AC8FA));

    // 指针
    final pointerPath = Path()
      ..moveTo(center.dx, center.dy - innerR + 3.5)
      ..lineTo(center.dx - 3.2, center.dy - outerR + 0.5)
      ..lineTo(center.dx + 3.2, center.dy - outerR + 0.5)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = const Color(0xFF5AC8FA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============// ================= 红包卡形状裁剪（如意角） =================
                class _RedPacketCardClipper extends CustomClipper<Path> {
                  @override
                  Path getClip(Size size) {
                    final w = size.width;
                    final h = size.height;

                    // ★ 如意角参数（想调就改这两处）
                    const r = 14.0;         // 角区域整体尺寸
                    const inner = 6.0;      // 内凹/外凸的"交叉点"位置
                    const inner2 = 4.0;     // 贝塞尔控制点辅助位置

                    final path = Path();

                    // ============ 左上角 ============
                    path.moveTo(r, 0);
                    // 内凹：顶边 → 卡片内部
                    path.cubicTo(
                      r * 0.6, 0,
                      inner2, inner2,
                      inner, inner,
                    );
                    // 外凸：交叉点 → 左边缘
                    path.cubicTo(
                      inner + 2, inner + 2,
                      0, r * 0.6,
                      0, r,
                    );

                    // ============ 左边缘向下 ============
                    path.lineTo(0, h - r);

                    // ============ 左下角 ============
                    path.cubicTo(
                      0, h - r * 0.6,
                      inner2, h - inner2,
                      inner, h - inner,
                    );
                    path.cubicTo(
                      inner + 2, h - inner - 2,
                      r * 0.6, h,
                      r, h,
                    );

                    // ============ 底边向右 ============
                    path.lineTo(w - r, h);

                    // ============ 右下角 ============
                    path.cubicTo(
                      w - r * 0.6, h,
                      w - inner2, h - inner2,
                      w - inner, h - inner,
                    );
                    path.cubicTo(
                      w - inner - 2, h - inner - 2,
                      w, h - r * 0.6,
                      w, h - r,
                    );

                    // ============ 右边缘向上 ============
                    path.lineTo(w, r);

                    // ============ 右上角 ============
                    path.cubicTo(
                      w, r * 0.6,
                      w - inner2, inner2,
                      w - inner, inner,
                    );
                    path.cubicTo(
                      w - inner - 2, inner + 2,
                      w - r * 0.6, 0,
                      w - r, 0,
                    );

                    path.close();
                    return path;
                  }

                  @override
                  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
                }

// ================= 红包卡装饰：密集祥云纹 + 金色双线 =================
class _RedPacketDecorPainter extends CustomPainter {
  final Path cardPath;
  _RedPacketDecorPainter(this.cardPath);

  @override
  void paint(Canvas canvas, Size size) {
    // 金色双线描边
    canvas.drawPath(
      cardPath,
      Paint()
        ..color = const Color(0xFFFFC93C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final innerPath = _scalePath(cardPath, size, 0.94);
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = const Color(0xFFFFE082).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  /// 把形状按比例缩小（用于金色内描边）★ 补回这个方法
  Path _scalePath(Path src, Size size, double scale) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final matrix = Matrix4.identity()
      ..translate(cx, cy)
      ..scale(scale)
      ..translate(-cx, -cy);
    return src.transform(matrix.storage);
  }

  @override
  bool shouldRepaint(covariant _RedPacketDecorPainter oldDelegate) =>
      oldDelegate.cardPath != cardPath;
}