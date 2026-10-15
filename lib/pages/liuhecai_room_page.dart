import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/config.dart';
import '../core/http_client.dart';
import '../widgets/red_packet_widgets.dart';
import 'chat_room_page.dart';
import '../widgets/bet_sheet.dart';
import 'liuhecai_redlog_page.dart';
import 'liuhecai_room_info_page.dart';
import 'webview_page.dart';

class LiuhecaiRoomPage extends StatefulWidget {
  final int roomid;
  final String roomName;
  const LiuhecaiRoomPage({
    super.key,
    required this.roomid,
    required this.roomName,
  });

  @override
  State<LiuhecaiRoomPage> createState() => _LiuhecaiRoomPageState();
}

class _LiuhecaiRoomPageState extends State<LiuhecaiRoomPage> {
  String _announcement = '';
  int _myUid = 0;
  int _ownerUid = 0;
  List<Map<String, dynamic>> _finances = [];

  Map<String, dynamic> _gameSettings = {};

  String _periodNum = '';
  int _remainSeconds = 0;
  bool _betClosed = false;
  Timer? _countdownTimer;
  Timer? _syncTimer;

  bool _notified60 = false;
  bool _notified45 = false;
  bool _notified30 = false;

  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _myClaimed = {};

  bool _showMorePanel = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _hasText = false;

  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  bool _isAtBottom = true;
  bool _isTriggering = false;

  IO.Socket? _socket;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _inputFocus.addListener(_onInputFocusChanged);
    _loadInitial();
    _connectSocket();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _syncFromServer(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
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
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
          _finances = fins;

          _periodNum = r['period_num']?.toString() ?? '';
          _remainSeconds =
              int.tryParse(r['remain_seconds']?.toString() ?? '0') ?? 0;
          _betClosed = _remainSeconds <= 30;
          _gameSettings = r['game_settings'] is Map
              ? Map<String, dynamic>.from(r['game_settings'])
              : <String, dynamic>{};

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

        if (_remainSeconds <= 0) {
          _triggerLottery();
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFromServer() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
        final newPeriod = r['period_num']?.toString() ?? _periodNum;
        final newRemain =
            int.tryParse(r['remain_seconds']?.toString() ?? '0') ?? 0;

        if (!mounted) return;
        if (newPeriod != _periodNum) {
          setState(() {
            _periodNum = newPeriod;
            _remainSeconds = newRemain;
            _betClosed = newRemain <= 30;
            _notified60 = false;
            _notified45 = false;
            _notified30 = false;
          });
          if (newRemain <= 0) _triggerLottery();
        } else {
          if ((newRemain - _remainSeconds).abs() > 2) {
            setState(() {
              _remainSeconds = newRemain;
              _betClosed = newRemain <= 30;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai sync] $e');
    }
  }

  void _tickCountdown() {
    if (!mounted) return;
    if (_remainSeconds > 0) {
      setState(() => _remainSeconds--);
      if (_remainSeconds <= 30) {
        _betClosed = true;
      }
      if (_remainSeconds == 60 && !_notified60) {
        _notified60 = true;
        _sendBroadcast('距离【第$_periodNum期】停止下注还有30秒');
      }
      if (_remainSeconds == 45 && !_notified45) {
        _notified45 = true;
        _sendBroadcast('距离【第$_periodNum期】停止下注还有15秒');
      }
      if (_remainSeconds == 30 && !_notified30) {
        _notified30 = true;
        _sendBroadcast('【第$_periodNum期】即将开奖，已停止下注。');
      }
    } else {
      _triggerLottery();
    }
  }

  Future<void> _triggerLottery() async {
    if (_isTriggering) return;
    _isTriggering = true;
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
        data: {'op': 'trigger_lottery', 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      debugPrint('🎰 trigger_lottery 返回: $data');

      if (data is Map) {
        final status = data['status']?.toString();
        if (status == '1') {
          _syncFromServer();
        } else if (status == '2') {
          await Future.delayed(const Duration(seconds: 3));
          _isTriggering = false;
          _triggerLottery();
          return;
        } else {
          await Future.delayed(const Duration(seconds: 2));
          _syncFromServer();
        }
      }
    } catch (e) {
      debugPrint('❌ [trigger_lottery] $e');
    } finally {
      _isTriggering = false;
    }
  }

  Future<void> _sendBroadcast(String msg) async {
    try {
      await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
        data: {'op': 'broadcast', 'msg': msg, 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
    } catch (e) {
      debugPrint('❌ [broadcast] $e');
    }
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
              debugPrint('✅ [liuhecai] socket connected');
              _socket!.emit('addgroup', widget.roomid);
              final ts = DateTime.now().millisecondsSinceEpoch;
              _socket!.emit('login', '${ts}r${_myUid}r${widget.roomid}');
              debugPrint('📡 [socket] emit addgroup=${widget.roomid}, login=${ts}r${_myUid}r${widget.roomid}');
            });

            _socket!.on('roominfo', (msg) {
              debugPrint('📥 [socket roominfo] 原始: $msg');
                try {
                  final str = msg.toString().replaceAll('&quot;', '"');
                  final list = jsonDecode(str);
                  if (list is! List) return;
                  for (final item in list) {
                    final m = Map<String, dynamic>.from(item);
                    debugPrint('📥 [socket roominfo] type=${m['type']} uid=${m['uid']} contents=${m['contents']}');
                    if (_messages.any((e) => e['id'] == m['id'])) continue;
            if (m['type']?.toString() == '0' && m['contents'] is Map) {
              final c = m['contents'] as Map;
              final setid = c['setid']?.toString() ?? '';
              if (_myClaimed.contains(setid)) {
                c['isget'] = 1;
              }
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

            _socket!.onDisconnect((reason) {
              debugPrint('⚠️ [liuhecai] socket disconnected, reason=$reason');
            });
            _socket!.onConnectError((e) {
              debugPrint('❌ [liuhecai] socket connect_error: $e');
            });
            _socket!.onError((e) {
              debugPrint('❌ [liuhecai] socket error: $e');
            });

            _socket!.connect();
            debugPrint('📡 [socket] connect() 已调用, url=${ApiConfig.baseUrl}, roomid=${widget.roomid}');
    } catch (e) {
      debugPrint('❌ [liuhecai socket init] $e');
    }
  }

  Future<void> _sendText() async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
          _toast(data['result']?.toString() ?? '发送失败');
          return;
        }
        _inputCtrl.clear();
        setState(() => _hasText = false);
        _inputFocus.unfocus();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ [setmess] $e');
      _toast('网络错误');
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

  void _onInputFocusChanged() {
    if (_inputFocus.hasFocus && _showMorePanel && mounted) {
      setState(() => _showMorePanel = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
      ),
    );
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

  String _fullImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('../')) {
      return '${ApiConfig.baseUrl}/${raw.replaceFirst('../', '')}';
    }
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
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
                    : _buildMessageList(),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.5)),
                  ),
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
    );
  }

  // ---- 顶部栏 ----
  Widget _buildHeader() {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 40,
              height: 44,
              child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
            ),
          ),
          Expanded(
            child: _MarqueeText(
              text:
                  '【六合彩】${widget.roomName}  |  期号：$_periodNum  |  倒计时：${_remainSeconds}s',
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
              width: 36,
              height: 36,
              child: Icon(Icons.refresh, color: Colors.black, size: 20),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LiuhecaiRoomInfoPage(roomid: widget.roomid),
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
        return _buildLiuhecaiRedBubble(contents, isSelf);
      case '1':
        if (uid == _myUid) return _buildSystemBubble(contents);
        return const SizedBox.shrink();
      case '2':
      case '4':
        if (type == '4' && uid != _myUid) return const SizedBox.shrink();
        return _buildSystemBubble(contents);
      case '5':
        return _buildImageBubble(contents, isSelf);
      case '6':
        return _buildTextBubble(contents, isSelf);
      default:
        return const SizedBox.shrink();
    }
  }

  // 六合彩红包气泡（保留橙红，红包象征色）
  Widget _buildLiuhecaiRedBubble(Map<String, dynamic> c, bool isSelf) {
    final nickname = c['nickname']?.toString() ?? '';
    final avatar = c['avatar']?.toString() ?? '';
    final gold = c['gold']?.toString() ?? '0';
    final nums = int.tryParse(c['nums']?.toString() ?? '0') ?? 0;
    final remain =
        int.tryParse(c['remain_nums']?.toString() ?? '$nums') ?? nums;
    final periodNum = c['period_num']?.toString() ?? '';
    final setid = c['setid']?.toString() ?? '';

    final isget = int.tryParse(c['isget']?.toString() ?? '0') ?? 0;
    final hasClaimed = isget == 1 || _myClaimed.contains(setid);

    final inactive = hasClaimed || remain <= 0;
    final bottomText = hasClaimed
        ? '已领取'
        : (remain <= 0 ? '已抢完' : '领取红包');
    final periodText =
        periodNum.isNotEmpty ? '${periodNum.padLeft(3, '0')}期' : '';
    final contentText = '$gold元-${nums}包-[六合彩$periodText]';

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
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Opacity(
              opacity: inactive ? 0.6 : 1,
              child: GestureDetector(
                onTap: () => _onLiuhecaiRedTap(c),
                child: Container(
                  width: 215,
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
                                  contentText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
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
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Text(
                                  '🧧',
                                  style: TextStyle(
                                    fontSize: 30,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
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
                          '六合彩红包',
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

    Widget _buildImageBubble(Map<String, dynamic> c, bool isSelf) {
      final avatar = c['avatar']?.toString() ?? '';
      final nickname = c['nickname']?.toString() ?? '';
      final rawContent = c['content']?.toString() ?? '';
      final content = _fullImageUrl(rawContent);

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
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showImagePreview(content),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      content,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
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

    void _showImagePreview(String url) {
      if (url.isEmpty) return;
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(8),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
          ),
        ),
      );
    }

  Widget _buildTextBubble(Map<String, dynamic> c, bool isSelf) {
    final avatar = c['avatar']?.toString() ?? '';
    final nickname = c['nickname']?.toString() ?? '';
    final content = _stripHtml(c['content']?.toString() ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isSelf) _avatar(avatar, size: 38),
        if (!isSelf) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(nickname,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF111111),
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
        width: size,
        height: size,
        color: const Color(0xFFE6F2FF),
        child: url.isEmpty
            ? const Icon(Icons.person, color: Color(0xFF007AFF), size: 20)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
      ),
    );
  }

  // ---- 六合彩红包点击 ----
  Future<void> _onLiuhecaiRedTap(Map<String, dynamic> c) async {
    _inputFocus.unfocus();
    final setid = c['setid']?.toString() ?? '';
    if (setid.isEmpty) return;

    if (_myClaimed.contains(setid)) {
      await _loadAndShowLiuhecaiDetail(setid);
      return;
    }

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
      if (data is Map &&
          data['status']?.toString() == '1' &&
          data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final selfMoney =
            double.tryParse(r['self_money']?.toString() ?? '0') ?? 0;
        final getedtime = r['getedtime']?.toString() ?? '';

        final canOpen = selfMoney == 0 && getedtime != '已抢完';
        final message = canOpen
            ? '恭喜发财,大吉大利'
            : (selfMoney > 0 ? '你已抢过该红包' : '红包已抢完');

        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.65),
          builder: (_) => RedPacketOpenDialog(
            nickname: r['nickname']?.toString() ?? '',
            avatar: r['avatar']?.toString() ?? '',
            message: message,
            canOpen: canOpen,
          ),
        );

        if (action == 'open') {
          await _doLiuhecaiRob(setid);
        } else if (action == 'detail') {
          await _showLiuhecaiRedDetail(r);
        }
      } else {
        _toast(
          data is Map
              ? (data['result']?.toString() ?? '加载失败')
              : '加载失败',
        );
      }
    } catch (e) {
      debugPrint('❌ [liuhecai getreddetail] $e');
      _toast('网络错误');
    }
  }

  Future<void> _doLiuhecaiRob(String setid) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
        data: {'op': 'rob_red', 'setid': setid, 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      final result = data is Map ? data['result']?.toString() : null;
      _toast(result ?? '操作完成');

      if (data is Map && data['status']?.toString() == '1') {
        _myClaimed.add(setid);
        for (final msg in _messages) {
          if (msg['type']?.toString() == '0' && msg['contents'] is Map) {
            final cc = msg['contents'] as Map;
            if (cc['setid']?.toString() == setid) {
              cc['isget'] = 1;
              cc['remain_nums'] = 0;
            }
          }
        }
        if (mounted) setState(() {});

        await Future.delayed(const Duration(milliseconds: 400));
        final res2 = await HttpClient.instance.dio.post(
          '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
          data: {'op': 'getreddetail', 'setid': setid},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
          ),
        );
        dynamic d2 = res2.data;
        if (d2 is String) {
          try { d2 = jsonDecode(d2); } catch (_) {}
        }
        if (d2 is Map && d2['result'] is Map) {
          final r = Map<String, dynamic>.from(d2['result']);
          await _showLiuhecaiRedDetail(r);
        }
      }
    } catch (e) {
      debugPrint('❌ [liuhecai rob_red] $e');
      _toast('网络错误');
    }
  }

  Future<void> _loadAndShowLiuhecaiDetail(String setid) async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
      if (data is Map &&
          data['status']?.toString() == '1' &&
          data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        await _showLiuhecaiRedDetail(r);
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '加载失败')
            : '加载失败');
      }
    } catch (e) {
      debugPrint('❌ [liuhecai loadDetail] $e');
      _toast('网络错误');
    }
  }

  Future<void> _showLiuhecaiRedDetail(Map<String, dynamic> r) async {
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
          _showLiuhecaiRedReport();
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
  }

  Future<void> _showLiuhecaiRedReport() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
      if (data is! Map ||
          data['status']?.toString() != '1' ||
          data['result'] is! Map) {
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
      debugPrint('❌ [liuhecai getrecord] $e');
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
              width: 36,
              height: 36,
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
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  hintText: '输入聊天内容...',
                  hintStyle:
                      TextStyle(color: Color(0xFF999999), fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _hasText ? _sendText : null,
            child: Container(
              width: 36,
              height: 36,
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
      _FuncItem('下注', Icons.card_giftcard, const Color(0xFFE94848), _onBet),
      _FuncItem('看余额', Icons.account_balance_wallet,
          const Color(0xFF007AFF), _onCheckBalance),
      _FuncItem('账单', Icons.receipt_long, const Color(0xFF07C160), _onBill),
      _FuncItem('联系财务', Icons.support_agent, const Color(0xFF07C160),
          _onFinance),
      _FuncItem('联系群主', Icons.verified_user, const Color(0xFF007AFF),
          _onOwner),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(it.icon, size: 30, color: it.color),
                ),
                const SizedBox(height: 6),
                Text(it.label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF555555))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _onBet() async {
    setState(() => _showMorePanel = false);

    if (_betClosed) {
      _toast('下注已截止，请等待开奖');
      return;
    }

    final switches = _gameSettings['switches'];
    if (switches is Map && switches.isNotEmpty) {
      final anyEnabled = switches.values.any((v) => v == 1 || v == '1' || v == true);
      if (!anyEnabled) {
        _toast('当前房间暂无可用玩法，请联系群主或财务');
        return;
      }
    }

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => BetSheet(
        roomid: widget.roomid,
        periodNum: _periodNum,
        gameSettings: _gameSettings,
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
        '${ApiConfig.liuhecai}&roomid=${widget.roomid}',
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
        builder: (_) => LiuhecaiRedlogPage(roomid: widget.roomid),
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
      final fuid =
          int.tryParse(_finances.first['id']?.toString() ?? '0') ?? 0;
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

  void _onPhoto() {
    setState(() => _showMorePanel = false);
    _toast('照片上传开发中（阶段 4 上线）');
  }
}

class _FuncItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _FuncItem(this.label, this.icon, this.color, this.onTap);
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