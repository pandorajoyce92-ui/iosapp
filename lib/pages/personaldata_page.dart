import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  int _uid = 0;
  String _avatarUrl = '';
  String _mobile = '';
  String _nickname = '';

  final _nicknameCtrl = TextEditingController();
  final _realnameCtrl = TextEditingController();

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

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _realnameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.personalData}&op=get_data',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final avatar = r['avatar']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _uid = int.tryParse(r['id']?.toString() ?? '0') ?? 0;
            _avatarUrl = avatar;
            _mobile = r['mobile']?.toString() ?? '';
            _nickname = r['nickname']?.toString() ?? '';
            _nicknameCtrl.text = _nickname;
            _realnameCtrl.text = r['realname']?.toString() ?? '';
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [personaldata get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (xfile == null) return;

      setState(() => _uploading = true);
      final bytes = await xfile.readAsBytes();
      final name = xfile.name.isEmpty ? 'avatar.jpg' : xfile.name;

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: name),
      });

      final res = await HttpClient.instance.dio.post(
        ApiConfig.uploadAvatar,
        data: formData,
      );

      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['url'] != null) {
        final url = data['url'].toString();
        if (url.isEmpty) {
          _toast('上传失败：未返回图片地址');
        } else {
          setState(() => _avatarUrl = url);
          _toast('头像上传成功');
        }
      } else {
        final err = data is Map
            ? (data['error'] ?? '未知错误').toString()
            : '未知错误';
        _toast('上传失败：$err');
      }
    } catch (e) {
      debugPrint('❌ 上传异常：$e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      _toast('昵称不能为空');
      return;
    }
    final realname = _realnameCtrl.text.trim();
    if (realname.isEmpty) {
      _toast('真实姓名不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.personalData}&op=save',
        data: {
          'nickname': nickname,
          'realname': realname,
          'avatar': _avatarUrl,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map) {
        _toast(data['result']?.toString() ?? '操作完成');
        if (data['status'] == 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      } else {
        _toast('保存失败');
      }
    } catch (e) {
      debugPrint('❌ 保存异常：$e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showQrCard() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => _QrCardDialog(
        uid: _uid,
        nickname: _nicknameCtrl.text.trim(),
        avatarUrl: _avatarUrl,
        mobile: _mobile,
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
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle('基本设置'),
                            _card([
                              _buildAvatarRow(),
                              _buildInputRow('昵称', _nicknameCtrl, '请输入昵称'),
                              _buildReadonlyRow('账号', _mobile, onTap: () => _toast('账号不可修改')),
                              _buildReadonlyRow('推荐码', _uid.toString()),
                              _buildQrRow(),
                            ]),
                            const SizedBox(height: 12),
                            _sectionTitle('实名信息'),
                            _card([
                              _buildInputRow('真实姓名', _realnameCtrl, '请输入真实姓名'),
                              _buildReadonlyRow('手机号', _mobile, isLast: true),
                            ]),
                            const SizedBox(height: 24),
                            _buildSubmitBtn(),
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
                width: 40, height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '个人资料',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(t,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5B48B8), fontWeight: FontWeight.w500)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _buildAvatarRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text('头像',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48, height: 48,
              color: const Color(0xFFF0ECFF),
              child: _avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: AppColors.purple, size: 26)
                  : Image.network(
                      _avatarUrl,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: AppColors.purple, size: 26),
                    ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: _uploading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007AFF)),
                    )
                  : const Text('更换',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController ctrl, String hint) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonlyRow(String label, String value, {VoidCallback? onTap, bool isLast = false}) {
    final child = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15, color: Color(0xFF999999))),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }

  Widget _buildQrRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showQrCard,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('我的二维码',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111))),
            ),
            const Spacer(),
            Icon(Icons.qr_code, size: 20, color: Colors.black.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Opacity(
        opacity: _saving ? 0.6 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.28),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _saving ? '保存中…' : '保存修改',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
//                        二维码名片弹窗
// ====================================================================
class _QrCardDialog extends StatelessWidget {
  final int uid;
  final String nickname;
  final String avatarUrl;
  final String mobile;

  const _QrCardDialog({
    required this.uid,
    required this.nickname,
    required this.avatarUrl,
    required this.mobile,
  });

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56, height: 56,
                      color: const Color(0xFFF0ECFF),
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: AppColors.purple, size: 28)
                          : Image.network(
                              avatarUrl,
                              width: 56, height: 56, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, color: AppColors.purple, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname.isEmpty ? '简信用户' : nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 4),
                        Text('账号: $mobile',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                        const SizedBox(height: 4),
                        Text('邀请码: $uid',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: 'https://www.guluapp.cn/cpPa',
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _savePoster(context),
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

  Future<void> _savePoster(BuildContext context) async {
    try {
      final bytes = await _buildPoster(
        uid: uid,
        nickname: nickname,
        avatarUrl: avatarUrl,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.88),
        builder: (_) => _PosterPreviewDialog(bytes: bytes),
      );
    } catch (e) {
      debugPrint('❌ 海报生成失败: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('海报生成失败：$e')),
      );
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
      const Offset(width / 2, 70),
      const TextStyle(
          fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'PingFang SC'),
    );

    const qrSize = 300.0;
    const qrX = (width - qrSize) / 2;
    const qrY = 180.0;

    final qrPainter = QrPainter(
      data: 'https://www.guluapp.cn/cpPa',
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
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(
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
          ..color = const Color(0xFFDBEAFE),
      );
    } else {
      canvas.drawCircle(
        const Offset(avatarX + avatarRadius, avatarY + avatarRadius),
        avatarRadius,
        Paint()..color = const Color(0xFFDBEAFE),
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
          fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF222222), fontFamily: 'PingFang SC'),
    );

    final inviteCodeY = nicknameY + 55;
    _paintText(
      canvas,
      '邀请码：$uid',
      Offset(width / 2, inviteCodeY),
      const TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF007AFF), fontFamily: 'PingFang SC'),
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
}

// ====================================================================
//                        海报预览 + 点击保存
// ====================================================================
class _PosterPreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _PosterPreviewDialog({required this.bytes});

  Future<void> _save(BuildContext context) async {
    // ★ 提前抓取 messenger 和 navigator，因为 pop 后 context 会失效
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
      // ★ 保存失败：不关弹窗，让用户重试
      messenger.showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
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
          // ★ 文案改为"点击保存到相册"
          const Text(
            '点击保存到相册',
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
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Text('保存到相册',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
                  child: const Text('关闭',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}