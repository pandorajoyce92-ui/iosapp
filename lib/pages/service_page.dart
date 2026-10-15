import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../models/user_info.dart';
import 'chat_room_page.dart';
import 'under_page.dart';
import 'servant_page.dart';

class ServicePage extends StatefulWidget {
  const ServicePage({super.key});

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  UserInfo? _user;
  bool _loading = true;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _itemBg = Color(0x26FFFFFF);

  // ★ 平台客服 UID（所有玩家注册时自动添加为好友）
  static const int _platformServiceUid = 624878;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.announcement}&op=get_user_info',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final user = UserInfo.fromJson(Map<String, dynamic>.from(data['result']));
        if (mounted) {
          setState(() {
            _user = user;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [get_user_info] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  void _openPoster() {
    final user = _user;
    if (user == null) {
      _toast('用户信息加载中，请稍候…');
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (_) => _PosterDialog(user: user),
    );
  }

  void _goUnder() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UnderPage()),
    );
  }

    // ★ 跳转平台客服私聊（带自动问候）
    void _goPlatformService() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ChatRoomPage(
            fuid: _platformServiceUid,
            autoGreeting: true,   // ★ 告诉聊天页：进入后触发客服问候
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
              _buildTopBar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        children: [
                          _buildMenuCard(),
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
      child: const Center(
        child: Text(
          '客服中心',
          style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: _itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _menuItem(
            icon: Icons.campaign_outlined,
            iconBg: const Color(0xFF007AFF),
            label: '线下推广',
            onTap: _openPoster,
          ),
          Divider(height: 1, thickness: 1, indent: 68, color: Colors.white.withOpacity(0.5)),
          _menuItem(
            icon: Icons.people_outline,
            iconBg: const Color(0xFF07C160),
            label: '下线列表',
            onTap: _goUnder,
          ),
          Divider(height: 1, thickness: 1, indent: 68, color: Colors.white.withOpacity(0.5)),
          _menuItem(
            icon: Icons.support_agent,
            iconBg: const Color(0xFF007AFF),
            label: '联系平台客服',
            onTap: _goPlatformService,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconBg,
    required String label,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                  label,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB), size: 20),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
//                            海报弹窗（不变）
// ====================================================================
class _PosterDialog extends StatefulWidget {
  final UserInfo user;
  const _PosterDialog({required this.user});

  @override
  State<_PosterDialog> createState() => _PosterDialogState();
}

class _PosterDialogState extends State<_PosterDialog> {
  Uint8List? _posterBytes;
  bool _generating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await _buildPoster(
        uid: widget.user.id,
        nickname: widget.user.nickname,
        avatarUrl: widget.user.avatarUrl,
      );
      if (mounted) {
        setState(() {
          _posterBytes = bytes;
          _generating = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 海报生成失败: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _generating = false;
        });
      }
    }
  }

  Future<Uint8List> _buildPoster({
    required int uid,
    required String nickname,
    required String avatarUrl,
  }) async {
    const width = 600.0;
    const height = 800.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    const bannerHeight = 140.0;
    final bannerRect = const Rect.fromLTWH(0, 0, width, bannerHeight);
        final gradient = const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF07C160)],  // ★ 蓝 → 绿
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    canvas.drawRect(bannerRect, Paint()..shader = gradient.createShader(bannerRect));

    _paintText(
      canvas,
      '扫码下载简信App',
      Offset(width / 2, 70),
      const TextStyle(
        fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white,
        fontFamily: 'PingFang SC',
      ),
    );

    const qrSize = 300.0;
    const qrX = (width - qrSize) / 2;
    const qrY = 180.0;

    final qrPainter = QrPainter(
      data: 'https://jianxinchat.top/app/download_page.php?invite_id=$uid',
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );

    final qrImgData = await qrPainter.toImageData(qrSize, format: ui.ImageByteFormat.png);
    if (qrImgData != null) {
      final qrImg = await decodeImageFromList(qrImgData.buffer.asUint8List());
      canvas.drawImage(qrImg, const Offset(qrX, qrY), Paint());
    }

    const avatarSize = 100.0;
    const avatarRadius = avatarSize / 2;
    const avatarX = (width - avatarSize) / 2;
    const avatarY = qrY + qrSize + 50;

    ui.Image? avatarImg;
    if (avatarUrl.isNotEmpty) {
      try {
        avatarImg = await _loadNetworkImage(avatarUrl);
      } catch (e) {
        debugPrint('❌ 头像加载失败: $e');
      }
    }

    if (avatarImg != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(
        center: const Offset(avatarX + avatarRadius, avatarY + avatarRadius),
        radius: avatarRadius,
      )));
      canvas.drawImageRect(
        avatarImg,
        Rect.fromLTWH(0, 0, avatarImg.width.toDouble(), avatarImg.height.toDouble()),
        const Rect.fromLTWH(avatarX, avatarY, avatarSize, avatarSize),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();

      canvas.drawCircle(
        const Offset(avatarX + avatarRadius, avatarY + avatarRadius),
        avatarRadius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE8E0FF),
      );
    } else {
      canvas.drawCircle(
        const Offset(avatarX + avatarRadius, avatarY + avatarRadius),
        avatarRadius,
        Paint()..color = const Color(0xFFE8E0FF),
      );
    }

    final displayName = nickname.isEmpty
        ? '简信用户'
        : (nickname.length > 12 ? '${nickname.substring(0, 12)}...' : nickname);
    final nicknameY = avatarY + avatarSize + 45;
    _paintText(
      canvas,
      displayName,
      Offset(width / 2, nicknameY),
      const TextStyle(
        fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF222222),
        fontFamily: 'PingFang SC',
      ),
    );
    final inviteCodeY = nicknameY + 55;
        _paintText(
          canvas,
          '邀请码：$uid',
          Offset(width / 2, inviteCodeY),
          const TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF007AFF),  // ★ 紫色改蓝
            fontFamily: 'PingFang SC',
          ),
        );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _paintText(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
    final res = await HttpClient.instance.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

    Future<void> _save() async {
      final bytes = _posterBytes;
      if (bytes == null) return;

      // ★ 提前抓 messenger 和 navigator，因为 pop 后 context 会失效
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      try {
        final has = await Gal.hasAccess();
        if (!has) await Gal.requestAccess();
        await Gal.putImageBytes(
          bytes,
          name: 'jianxin_poster_${DateTime.now().millisecondsSinceEpoch}',
        );

        // ★ 保存成功后：先关弹窗，再弹提示
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已保存到相册'),
            duration: Duration(milliseconds: 1800),
          ),
        );
      } catch (e) {
        debugPrint('❌ 保存失败: $e');
        // ★ 保存失败：不关弹窗
        messenger.showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        const Text(
          '点击保存到相册',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
          const SizedBox(height: 14),
          Flexible(
            child: GestureDetector(
              onLongPress: _save,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 32, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildContent(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogBtn('保存到相册', _save, primary: true),
              const SizedBox(width: 10),
              _dialogBtn('关闭', () => Navigator.of(context).pop()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_generating) {
      return const SizedBox(
        width: 200, height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        width: 260, height: 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '生成失败\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE94848), fontSize: 13),
            ),
          ),
        ),
      );
    }
    return Image.memory(_posterBytes!, fit: BoxFit.contain);
  }

  Widget _dialogBtn(String label, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: primary ? null : Colors.transparent,
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
              : null,
          border: primary ? null : Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}