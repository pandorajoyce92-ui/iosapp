import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiShareGroupPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiShareGroupPage({super.key, required this.roomid});

  @override
  State<LiuhecaiShareGroupPage> createState() =>
      _LiuhecaiShareGroupPageState();
}

class _LiuhecaiShareGroupPageState extends State<LiuhecaiShareGroupPage> {
  bool _loading = true;
  String _roomName = '';
  String _roomNum = '';
  int _sharerId = 0;
  Uint8List? _qrcodeBytes;

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
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiShareGroup}&op=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final b64 = r['qrcode_base64']?.toString() ?? '';
        Uint8List? bytes;
        if (b64.isNotEmpty) {
          try {
            final pure = b64.contains(',') ? b64.split(',').last : b64;
            bytes = base64Decode(pure);
          } catch (e) {
            debugPrint('❌ 二维码 base64 解析失败: $e');
          }
        }
        if (mounted) {
          setState(() {
            _roomName = r['roomname']?.toString() ?? '';
            _roomNum = r['roomnums']?.toString() ?? '';
            _sharerId = int.tryParse(r['sharer_id']?.toString() ?? '0') ?? 0;
            _qrcodeBytes = bytes;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_share_group get_data] $e');
      if (mounted) setState(() => _loading = false);
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

  Future<void> _savePoster() async {
    if (_qrcodeBytes == null) {
      _toast('二维码未加载，请刷新重试');
      return;
    }
    try {
      final bytes = await _buildPoster();
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.88),
        builder: (_) => _PosterPreviewDialog(bytes: bytes),
      );
    } catch (e) {
      debugPrint('❌ 海报生成失败: $e');
      _toast('海报生成失败：$e');
    }
  }

  Future<Uint8List> _buildPoster() async {
    const width = 600.0;
    const height = 800.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // 白色背景
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    // 顶部渐变（蓝 → 绿）
    const bannerHeight = 140.0;
    final bannerRect = const Rect.fromLTWH(0, 0, width, bannerHeight);
    final gradient = const LinearGradient(
      colors: [Color(0xFF007AFF), Color(0xFF07C160)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    canvas.drawRect(
      bannerRect,
      Paint()..shader = gradient.createShader(bannerRect),
    );

    // 横幅文字
    _paintText(
      canvas,
      '扫码加入群聊',
      const Offset(width / 2, 70),
      const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'PingFang SC',
      ),
    );

    // 二维码
    const qrSize = 340.0;
    const qrX = (width - qrSize) / 2;
    const qrY = 220.0;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(qrX - 20, qrY - 20, qrSize + 40, qrSize + 40),
      const Radius.circular(8),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    canvas.drawRRect(shadowRect, Paint()..color = Colors.white);

    final qrImg = await decodeImageFromList(_qrcodeBytes!);
    canvas.drawImageRect(
      qrImg,
      Rect.fromLTWH(0, 0, qrImg.width.toDouble(), qrImg.height.toDouble()),
      const Rect.fromLTWH(qrX, qrY, qrSize, qrSize),
      Paint()..filterQuality = FilterQuality.high,
    );

    // 群名称
    _paintText(
      canvas,
      _roomName,
      Offset(width / 2, qrY + qrSize + 90),
      const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Color(0xFF222222),
        fontFamily: 'PingFang SC',
      ),
    );

    // 群号（蓝）
    _paintText(
      canvas,
      '群号：$_roomNum',
      Offset(width / 2, qrY + qrSize + 150),
      const TextStyle(
        fontSize: 28,
        color: Color(0xFF007AFF),
        fontFamily: 'PingFang SC',
      ),
    );

    // 分享者ID
    _paintText(
      canvas,
      '分享者ID：$_sharerId',
      Offset(width / 2, qrY + qrSize + 195),
      const TextStyle(
        fontSize: 24,
        color: Color(0xFF888888),
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
      child: Stack(
        children: [
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '分享群',
              style: TextStyle(
                color: Color(0xFF000000),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCard(),
          const SizedBox(height: 20),
          _buildSaveBtn(),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '扫码加入群聊',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          // 二维码
          Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _qrcodeBytes == null
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_qrcodeBytes!, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 30),
          // 信息区
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoItem('群名称', _roomName, false, isFirst: true),
                _buildInfoItem('群号', _roomNum, true),
                _buildInfoItem('分享者ID', _sharerId.toString(), true, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '长按保存图片，或点击下方按钮下载',
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    bool highlight, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : 8,
        bottom: isLast ? 0 : 12,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: highlight ? const Color(0xFF007AFF) : const Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: _savePoster,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          '保存图片分享给好友',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ==================== 海报预览弹窗 ====================
class _PosterPreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _PosterPreviewDialog({required this.bytes});

  Future<void> _save(BuildContext context) async {
    try {
      final has = await Gal.hasAccess();
      if (!has) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'jianxin_liuhecai_group_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已保存到相册'),
            duration: Duration(milliseconds: 1800),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 保存失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
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
            '长按下方海报 → 保存到相册',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _save(context),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _save(context),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF07C160)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '保存到相册',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '关闭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}