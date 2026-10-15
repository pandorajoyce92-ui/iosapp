import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../core/sound_player.dart';
import '../models/chat_message.dart';
import '../widgets/chat_bubble.dart';
import '../core/data_cache.dart';                                   // ★ 新增

class ChatRoomPage extends StatefulWidget {
  final int fuid;
  final bool autoGreeting;   // ★ 新增：进入后触发客服自动问候
  const ChatRoomPage({
    super.key,
    required this.fuid,
    this.autoGreeting = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> with WidgetsBindingObserver {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _showFuncPanel = false;
  bool _hasText = false;

  int _myUid = 0;
  String _myAvatar = '';
  String _myNickname = '';
  String _friendAvatar = '';
  String _friendNickname = '';
  String _remark = '';

    IO.Socket? _socket;
    String _md5fuid = '';

    Timer? _pollTimer;

    // ★ 多选删除（微信式本地隐藏）
    bool _selectMode = false;
    final Set<int> _selectedIds = {};
    final Set<int> _deletedIds = {};
    String get _deletedIdsKey => 'chat_deleted_ids_${widget.fuid}';

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  /// 时间分隔符间隔：5 分钟
  static const int _timeInterval = 5 * 60;

      @override
      void initState() {
        super.initState();
        WidgetsBinding.instance.addObserver(this);
        _inputCtrl.addListener(_onInputChanged);
        // ★ 新增：输入框聚焦后等键盘弹起完，滚到最新
        _inputFocus.addListener(_onFocusChanged);
        _loadDeletedIds();
        _init();
      }

      // ★ 新增
      void _onFocusChanged() {
        if (_inputFocus.hasFocus) {
          // 300ms 等键盘弹起动画结束
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _scrollCtrl.hasClients) {
              _scrollToBottom(animate: true);
            }
          });
        }
      }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);   // ★ 新增
      _inputCtrl.removeListener(_onInputChanged);
      _inputFocus.removeListener(_onFocusChanged);
      _inputCtrl.dispose();
      _scrollCtrl.dispose();
      _inputFocus.dispose();
      _pollTimer?.cancel();
      _socket?.dispose();
      _cacheWriteTimer?.cancel();   // ★ 新增
      super.dispose();
    }

      // ==================== 多选删除 ====================
      void _loadDeletedIds() {
        final cached = DataCache.get(_deletedIdsKey);
        if (cached is List) {
          _deletedIds.clear();
          for (final v in cached) {
            final id = int.tryParse(v.toString());
            if (id != null) _deletedIds.add(id);
          }
        }
      }

      Future<void> _saveDeletedIds() async {
        await DataCache.set(_deletedIdsKey, _deletedIds.toList());
      }

      void _enterSelectMode(int id) {
        if (!mounted) return;
        setState(() {
          _selectMode = true;
          _selectedIds.clear();
          _selectedIds.add(id);
        });
      }

      void _toggleSelect(int id) {
        if (!mounted) return;
        setState(() {
          if (_selectedIds.contains(id)) {
            _selectedIds.remove(id);
          } else {
            _selectedIds.add(id);
          }
        });
      }

      void _exitSelectMode() {
        if (!mounted) return;
        setState(() {
          _selectMode = false;
          _selectedIds.clear();
        });
      }

      Future<void> _deleteSelected() async {
        if (_selectedIds.isEmpty) return;
        final count = _selectedIds.length;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除确认'),
            content: Text('确定删除选中的 $count 条聊天记录？\n仅在你手机上删除，对方不受影响。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除', style: TextStyle(color: Color(0xFFE94848))),
              ),
            ],
          ),
        );
        if (confirmed != true) return;

        setState(() {
          _deletedIds.addAll(_selectedIds);
          _messages.removeWhere((m) => _selectedIds.contains(m.id));
          _selectMode = false;
          _selectedIds.clear();
        });
        await _saveDeletedIds();
        _scheduleCacheWrite();
      }

    // ★ 新增：监听键盘高度变化，自动滚到最新消息
    @override
    void didChangeMetrics() {
      super.didChangeMetrics();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;
        _scrollToBottom(animate: false);
      });
    }

  void _onInputChanged() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

    Future<void> _init() async {
      await _loadInfo();
      await _loadMd5();
      await _loadHistory();
      _clearUnread();
      if (mounted) setState(() => _loading = false);
      _connectSocket();
      _startPolling();
      _scrollToBottom(animate: false);   // ★ 首次进入直接到底，不要动画

      // ★ 客服自动问候（只对客服 624878 生效）
      if (widget.autoGreeting && widget.fuid == 624878) {
        _triggerServiceGreeting();
      }
    }

    // ★ 触发客服问候，然后拉一次新消息
    Future<void> _triggerServiceGreeting() async {
      try {
        await HttpClient.instance.dio.post(
          '${ApiConfig.entryUrl}&p=chat_room',
          data: {'op': 'auto_greeting', 'fuid': widget.fuid},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        // 稍等一下，让后端写入 + socket 推送
        await Future.delayed(const Duration(milliseconds: 400));
        await _pollNewMessages();
      } catch (e) {
        debugPrint('❌ [auto_greeting] $e');
      }
    }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      await _pollNewMessages();
    });
  }

    Future<void> _pollNewMessages() async {
      try {
        final res = await HttpClient.instance.dio.post(
          '${ApiConfig.entryUrl}&p=chat_room',
          data: {'op': 'get_history', 'fuid': widget.fuid},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        dynamic data = res.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
        if (data is Map && data['status'] == 1 && data['result'] is List) {
          final rawList = data['result'] as List;
          final list = rawList
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList();
              final existingIds = _messages.map((m) => m.id).toSet();
              final newOnes = list
                  .where((m) => !existingIds.contains(m.id))
                  .where((m) => !_deletedIds.contains(m.id))   // ★ 过滤
                  .toList();
          if (newOnes.isNotEmpty && mounted) {
            setState(() => _messages.addAll(newOnes));
            _scrollToBottom();

            // ★ 有新消息 → 同步缓存（覆盖旧的）
            final toSave = rawList.length > 200
                ? rawList.sublist(rawList.length - 200)
                : rawList;
            await DataCache.set('chat_${widget.fuid}', toSave);
          }
        }
      } catch (_) {}
    }

  Future<void> _loadInfo() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=chat_room',
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
            _myAvatar = ChatMessage.buildAvatar(r['myAvatar']?.toString() ?? '');
            _myNickname = r['myNickname']?.toString() ?? '';
            _friendAvatar = ChatMessage.buildAvatar(r['friendAvatar']?.toString() ?? '');
            _friendNickname = r['friendNickname']?.toString() ?? '';
            _remark = r['remark']?.toString() ?? _friendNickname;
            _myUid = int.tryParse(r['uid']?.toString() ?? '0') ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 加载用户信息失败: $e');
    }
  }

  Future<void> _loadMd5() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=chat_room',
        data: {'op': 'get_md5fuid', 'fuid': widget.fuid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        _md5fuid = r['md5fuid']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('❌ 获取 md5fuid 失败: $e');
    }
  }

    Future<void> _loadHistory() async {
      // ① 先用缓存秒渲染
      if (_messages.isEmpty) {
        final cached = DataCache.get('chat_${widget.fuid}');
        if (cached is List) {
          try {
            final list = cached
                .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
                .toList();
                      if (mounted) {
                        setState(() => _messages = list
                            .where((m) => !_deletedIds.contains(m.id))
                            .toList());
                        _scrollToBottom(animate: false);
                      }
          } catch (_) {}
        }
      }

      // ② 后台请求，回来覆盖 + 写缓存
      try {
        final res = await HttpClient.instance.dio.post(
          '${ApiConfig.entryUrl}&p=chat_room',
          data: {'op': 'get_history', 'fuid': widget.fuid},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        dynamic data = res.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
                if (data is Map && data['status'] == 1 && data['result'] is List) {
                  final rawList = data['result'] as List;
                  final list = rawList
                      .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
                      .where((m) => !_deletedIds.contains(m.id))   // ★ 过滤
                      .toList();
                  if (mounted) setState(() => _messages = list);
                  _scrollToBottom(animate: false);

          // ★ 写缓存（最多留 200 条，避免 shared_preferences 膨胀）
          final toSave = rawList.length > 200
              ? rawList.sublist(rawList.length - 200)
              : rawList;
          await DataCache.set('chat_${widget.fuid}', toSave);
        }
      } catch (e) {
        debugPrint('❌ 加载历史消息失败: $e');
      }
    }

  Future<void> _clearUnread() async {
    try {
      await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=chat_room',
        data: {'op': 'clear_unread', 'fuid': widget.fuid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (_) {}
  }

  void _connectSocket() {
    if (_md5fuid.isEmpty) return;
    try {
      _socket = IO.io(
        'https://jianxinchat.top',
        <String, dynamic>{
          'transports': ['websocket', 'polling'],
          'autoConnect': true,
          'reconnection': true,
          'reconnectionAttempts': 9999,
          'reconnectionDelay': 2000,
          'forceNew': true,   // ★★★ 每次独立 socket，不复用
        },
      );

      _socket!.onConnect((_) => _socket!.emit('login', _md5fuid));
      _socket!.on('new_msg', _handleNewMessage);
      _socket!.connect();
    } catch (e) {
      debugPrint('🔌 Socket 连接失败: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    try {
      dynamic msg = data;
      if (msg is String) {
        msg = msg.replaceAll('&quot;', '"');
        try { msg = jsonDecode(msg); } catch (_) {}
      }
      if (msg is! Map) return;
      final newMsg = ChatMessage.fromJson(Map<String, dynamic>.from(msg));

      // ★ 收到对方发来的消息 → 响铃
      final senderUid = newMsg.uid;
      final isCardUpdate = (newMsg.type == 3 || newMsg.type == 4) && newMsg.isUpdate == 1;
      if ((senderUid > 0 && senderUid != _myUid) || isCardUpdate) {
        SoundPlayer.instance.playMessage();
      }

      // ★ 卡片状态更新消息（type=3/4 且 is_update=1）：更新已有卡片
      if ((newMsg.type == 3 || newMsg.type == 4) && newMsg.isUpdate == 1) {
        final idx = _messages.indexWhere((m) =>
            (m.type == 3 || m.type == 4) && m.applyId == newMsg.applyId);
        if (idx >= 0 && mounted) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(applyStatus: newMsg.applyStatus);
          });
        }
        return;
      }

                                    // 普通消息
                                    if (_messages.any((m) => m.id == newMsg.id)) return;
                                    if (_deletedIds.contains(newMsg.id)) return;   // ★ 已本地删除
                                    if (mounted) {
                                      setState(() => _messages.add(newMsg));
                                      _scrollToBottom();
                                    }

                  // ★ 有新消息 → 延迟写缓存（500ms 内累积多条一起写，避免频繁 IO）
                  _scheduleCacheWrite();
                } catch (e) {
                  debugPrint('❌ 解析新消息失败: $e');
                }
              }

              // ★ 节流：500ms 内多次调用只写一次
              Timer? _cacheWriteTimer;
              void _scheduleCacheWrite() {
                _cacheWriteTimer?.cancel();
                _cacheWriteTimer = Timer(const Duration(milliseconds: 500), () async {
                  if (_messages.isEmpty) return;
                  final toSave = _messages.length > 200
                      ? _messages.sublist(_messages.length - 200)
                      : _messages;
                  // ChatMessage 已有 toJson()
                  await DataCache.set(
                    'chat_${widget.fuid}',
                    toSave.map((m) => m.toJson()).toList(),
                  );
                });
              }

    void _scrollToBottom({bool animate = true}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollCtrl.hasClients) return;

        // ★ 第一次：粗跳到底（不管 ListView 是否测量完）
        final max1 = _scrollCtrl.position.maxScrollExtent;
        _scrollCtrl.jumpTo(max1);

        // ★ 第二次：等 100ms 让列表完成布局，再精调一次
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted || !_scrollCtrl.hasClients) return;
          final max2 = _scrollCtrl.position.maxScrollExtent;
          if (max2 > max1) {
            if (animate) {
              _scrollCtrl.animateTo(
                max2,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            } else {
              _scrollCtrl.jumpTo(max2);
            }
          }
        });
      });
    }

  Future<void> _sendText() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.entryUrl}&p=chat_room',
        data: {'op': 'setmess', 'type': 1, 'content': text, 'fuid': widget.fuid},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        _inputCtrl.clear();
        setState(() {
          _showFuncPanel = false;
          _hasText = false;
        });
        Future.delayed(const Duration(milliseconds: 300), _pollNewMessages);
      } else {
        _toast((data is Map ? data['result']?.toString() : null) ?? '发送失败');
      }
    } catch (e) {
      debugPrint('❌ 发送失败: $e');
      _toast('网络异常');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;

      setState(() => _showFuncPanel = false);
      _toast('正在上传...');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      final uploadRes = await HttpClient.instance.dio.post(
        'https://jianxinchat.top/upload.php',
        data: formData,
      );
      dynamic upData = uploadRes.data;
      if (upData is String) {
        try { upData = jsonDecode(upData); } catch (_) {}
      }
      if (upData is Map && upData['status'] == 1) {
        final imgUrl = upData['url']?.toString() ?? '';
        await HttpClient.instance.dio.post(
          '${ApiConfig.entryUrl}&p=chat_room',
          data: {'op': 'setmess', 'type': 2, 'content': imgUrl, 'fuid': widget.fuid},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        Future.delayed(const Duration(milliseconds: 300), _pollNewMessages);
      } else {
        _toast('上传失败');
      }
    } catch (e) {
      debugPrint('❌ 上传图片失败: $e');
      _toast('上传失败');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 充值/提现卡片点击处理
  Future<void> _handleApplyTap(ChatMessage msg, {required bool isRecharge}) async {
    final title = isRecharge ? '充值确认' : '提现确认';
    final actionText = isRecharge ? '充值' : '提现';
    final playerNick = msg.playerNickname.isEmpty ? '玩家' : msg.playerNickname;
    final amtStr = msg.amount.toStringAsFixed(0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          isRecharge
              ? '确认同意 $playerNick 充值 $amtStr 元到房间 ${msg.roomnums} 吗？'
              : '确认处理 $playerNick 的提现 $amtStr 元申请吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('拒绝', style: TextStyle(color: Color(0xFFE94848))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意', style: TextStyle(color: Color(0xFF07C160))),
          ),
        ],
      ),
    );
    if (confirmed == null) return;

    final action = confirmed ? 'agree' : 'reject';
    final url = '${ApiConfig.entryUrl}&p=chat_room';
    final op = isRecharge ? 'confirm_recharge' : 'confirm_withdraw';

    try {
      final res = await HttpClient.instance.dio.post(
        url,
        data: {
          'op': op,
          'action': action,
          'apply_id': msg.applyId,
          'roomid': msg.roomid,
          'fuid': widget.fuid,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1) {
        // 立即更新本地卡片状态
        final idx = _messages.indexWhere((m) =>
            (m.type == 3 || m.type == 4) && m.applyId == msg.applyId);
        if (idx >= 0 && mounted) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              applyStatus: confirmed ? 1 : 2,
            );
          });
        }
        _toast(confirmed ? '$actionText成功' : '已拒绝');
      } else {
        _toast((data is Map ? data['result']?.toString() : null) ?? '操作失败');
      }
    } catch (e) {
      debugPrint('❌ $op 失败: $e');
      _toast('网络异常');
    }
  }

  // ==================== 时间分隔符 ====================
  String _formatTimeSeparator(int timestamp) {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateStart = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(dateStart).inDays;

    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');

    if (diffDays == 0) return '$hh:$mm';
    if (diffDays == 1) return '昨天 $hh:$mm';
    if (diffDays < 7) {
      const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
      return '星期${weekdays[date.weekday % 7]} $hh:$mm';
    }
    if (date.year == now.year) {
      return '${date.month}月${date.day}日 $hh:$mm';
    }
    return '${date.year}年${date.month}月${date.day}日 $hh:$mm';
  }

  /// 构建消息列表（含时间分隔符）
  List<Widget> _buildMessageWidgets() {
    final widgets = <Widget>[];
    int lastTime = 0;
    for (final msg in _messages) {
      // 时间分隔符
      if (msg.timestamp > 0 && (msg.timestamp - lastTime > _timeInterval || lastTime == 0)) {
        widgets.add(_buildTimeSeparator(_formatTimeSeparator(msg.timestamp)));
      }
      if (msg.timestamp > 0) lastTime = msg.timestamp;

            final bubble = ChatBubble(
              key: ValueKey('msg_${msg.id}_${msg.applyStatus}'),
              msg: msg,
              myUid: _myUid,
              myAvatar: _myAvatar,
              friendAvatar: _friendAvatar,
              onTapTransfer: (m) => _toast('转账详情：${m.status}'),
              onTapRecharge: (m) => _handleApplyTap(m, isRecharge: true),
              onTapWithdraw: (m) => _handleApplyTap(m, isRecharge: false),
              onTapImage: _showImagePreview,
            );

            // ★ 长按进选择模式；选择模式下点击切换选中
            widgets.add(
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _enterSelectMode(msg.id),
                child: Stack(
                  children: [
                    bubble,
                    if (_selectMode)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleSelect(msg.id),
                        ),
                      ),
                    if (_selectMode && _selectedIds.contains(msg.id))
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.10),
                              border: Border.all(color: const Color(0xFF007AFF), width: 2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
    }
    return widgets;
  }

  Widget _buildTimeSeparator(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ),
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
                _buildHeader(),
                // ★ 聊天区 + 底部栏 共用同一张聊天壁纸
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/chat_bg.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _showFuncPanel = false);
                                  },
                                  child: ListView(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    children: _buildMessageWidgets(),
                                  ),
                                ),
                        ),
                        _buildBottomBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 80),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
        if (_selectMode) {
          return Container(
            height: 44,
            color: Colors.transparent,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _exitSelectMode,
                  child: const SizedBox(
                    width: 60, height: 44,
                    child: Center(
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '已选 ${_selectedIds.length} 条',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 60),
              ],
            ),
          );
        }
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
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          Center(
            child: Text(
              _remark.isEmpty ? _friendNickname : _remark,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

      Widget _buildBottomBar() {
                // ★ 选择模式：显示删除栏
                if (_selectMode) {
                  return Container(
                    color: Colors.white,
                    padding: EdgeInsets.only(
                      left: 16, right: 16, top: 12,
                      bottom: 12 + MediaQuery.of(context).padding.bottom * 0.5,
                    ),
                    child: GestureDetector(
                      onTap: _selectedIds.isEmpty ? null : _deleteSelected,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _selectedIds.isEmpty
                              ? const Color(0xFFCCCCCC)
                              : const Color(0xFFE94848),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _selectedIds.isEmpty
                              ? '删除'
                              : '删除 (${_selectedIds.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }
        return Container(
          // ★ 去掉灰底，让壁纸透出
          color: Colors.transparent,
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: 8 + MediaQuery.of(context).padding.bottom * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 功能面板（仅当展开时渲染，避免 0 高度时的 1px 横线）
              if (_showFuncPanel)
                Container(
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
                  ),
                  child: Row(
                    children: [
                      _funcItem(
                        '转账',
                        Icons.account_balance_wallet_outlined,
                        () => _toast('功能开发中...'),
                      ),
                      _funcItem('图片', Icons.image_outlined, _pickAndSendImage),
                    ],
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // + 号
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showFuncPanel = !_showFuncPanel);
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
                        _showFuncPanel ? Icons.close : Icons.add,
                        size: 22,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                                // ★ 输入框：白色椭圆，壁纸仅在它外面透出
                                Expanded(
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _inputFocus,
                        minLines: 1,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          hintText: '请输入要发送的信息...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 发送图标
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
            ],
          ),
        );
      }

  Widget _funcItem(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 28, color: const Color(0xFF797787)),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}