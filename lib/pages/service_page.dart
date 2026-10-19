import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      CupertinoPageRoute(builder: (_) => const UnderPage()),
    );
  }

  void _goPlatformService() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const ChatRoomPage(
          fuid: _platformServiceUid,
          autoGreeting: true,
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
//                            海报弹窗
// ====================================================================
class _PosterDialog extends StatefulWidget {
  final UserInfo user;
  const _PosterDialog({required this.user});

  @override
  State<_PosterDialog> createState() => _PosterDialogState();
}

class _PosterDialogState extends State<_PosterDialog> {
  Uint8List? _posterBytes;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 确认这里已经删除了 _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });

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
      colors: [Color(0xFF007AFF), Color(0xFF07C160)],
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
      data: 'https://www.guluapp.cn/ykPl',
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
        fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF007AFF),
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
      options: Options(
        responseType: ResponseType.bytes,
        sendTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _save() async {
    if (_posterBytes == null) {
      _toast('正在生成海报，请稍候...');
      await _generate();
    }

    final bytes = _posterBytes;
    if (bytes == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final has = await Gal.hasAccess();
      if (!has) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'jianxin_poster_${DateTime.now().millisecondsSinceEpoch}',
      );

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已保存到相册'),
          duration: Duration(milliseconds: 1800),
        ),
      );
    } catch (e) {
      debugPrint('❌ 保存失败: $e');
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 顶部关闭按钮
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text('×',
                          style: TextStyle(fontSize: 26, color: Color(0xFFAAAAAA), height: 1)),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 用户信息卡片区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56, height: 56,
                      color: const Color(0xFFF0ECFF),
                                            child: widget.user.avatarUrl.isEmpty
                                                ? const Icon(Icons.person, color: Colors.deepPurple, size: 28)
                                                : CachedNetworkImage(
                                                    imageUrl: widget.user.avatarUrl,
                                                    width: 56, height: 56, fit: BoxFit.cover,
                                                    placeholder: (context, url) =>
                                                        const Icon(Icons.person, color: Colors.deepPurple, size: 28),
                                                    errorWidget: (context, url, error) =>
                                                        const Icon(Icons.person, color: Colors.deepPurple, size: 28),
                                                  ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.nickname.isEmpty ? '简信用户' : widget.user.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 4),
                        Text('邀请码: ${widget.user.id}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. 中间二维码内容区
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildContent(),
            ),
            const SizedBox(height: 20),

            // 4. 底部保存按钮
            GestureDetector(
              onTap: _save,
              child: Container(
                height: 54,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F4))),
                  color: Color(0xFFFAFAFC),
                ),
                alignment: Alignment.center,
                child: const Text('保存二维码到手机',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_generating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在生成海报...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '生成失败\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE94848), fontSize: 13),
          ),
        ),
      );
    }

    if (_posterBytes != null) {
      return Image.memory(_posterBytes!, fit: BoxFit.contain);
    }

    // 秒开状态：显示纯净的二维码
    return QrImageView(
      data: 'https://www.guluapp.cn/ykPl',
      version: QrVersions.auto,
      size: 200,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }
}