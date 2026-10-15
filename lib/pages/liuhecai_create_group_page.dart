import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';

class LiuhecaiCreateGroupPage extends StatefulWidget {
  const LiuhecaiCreateGroupPage({super.key});

  @override
  State<LiuhecaiCreateGroupPage> createState() => _LiuhecaiCreateGroupPageState();
}

class _LiuhecaiCreateGroupPageState extends State<LiuhecaiCreateGroupPage> {
  final _groupNameCtrl    = TextEditingController();
  final _announcementCtrl = TextEditingController();
  final _noticeCtrl       = TextEditingController();
  final _minNumsCtrl      = TextEditingController(text: '7');
  final _maxNumsCtrl      = TextEditingController(text: '9');
  final _secondCtrl       = TextEditingController(text: '180');

  String _avatarRelative = '';
  String _avatarFull = '';

  bool _uploading = false;
  bool _submitting = false;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0xF2FFFFFF);

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _announcementCtrl.dispose();
    _noticeCtrl.dispose();
    _minNumsCtrl.dispose();
    _maxNumsCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
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
        '${ApiConfig.liuhecaiCreateGroup}&op=upload',
        data: formData,
      );

      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        final rel = data['url']?.toString() ?? '';
        if (rel.isEmpty) {
          _toast('上传失败：未返回图片地址');
        } else {
          setState(() {
            _avatarRelative = rel;
            _avatarFull = 'https://jianxinchat.top/attachment/$rel';
          });
          _toast('头像上传成功');
        }
      } else {
        final msg = data is Map
            ? (data['message'] ?? data['result'] ?? '未知错误').toString()
            : '未知错误';
        _toast('上传失败：$msg');
      }
    } catch (e) {
      debugPrint('❌ 上传异常：$e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final groupName = _groupNameCtrl.text.trim();
    if (groupName.isEmpty) {
      _toast('请填写群名称');
      return;
    }

    final minNums = int.tryParse(_minNumsCtrl.text.trim());
    final maxNums = int.tryParse(_maxNumsCtrl.text.trim());
    if (minNums == null || maxNums == null || minNums <= 0 || maxNums <= 0 || minNums >= maxNums) {
      _toast('请正确填写发包个数范围（最小 < 最大）');
      return;
    }

    final second = int.tryParse(_secondCtrl.text.trim()) ?? 180;
    if (second <= 0) {
      _toast('请填写有效的红包过期秒数');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiCreateGroup}&op=submit',
        data: {
          'avatar': _avatarRelative,
          'group_name': groupName,
          'announcement': _announcementCtrl.text.trim(),
          'notice': _noticeCtrl.text.trim(),
          'min_nums': minNums,
          'max_nums': maxNums,
          'second': second,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        _toast(data['result']?.toString() ?? '申请已提交');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final msg = data is Map ? (data['result'] ?? '操作失败').toString() : '操作失败';
        _toast(msg);
        if (mounted) setState(() => _submitting = false);
      }
    } catch (e) {
      debugPrint('❌ 提交异常：$e');
      _toast('网络错误，请稍后再试');
      if (mounted) setState(() => _submitting = false);
    }
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('基本信息'),
                      _card([
                        _buildAvatarRow(),
                        _buildInputRow('群名称', _groupNameCtrl, hint: '请输入群名称', maxLength: 20, required: true),
                        _buildInputRow('群公告', _announcementCtrl, hint: '请填写群公告（选填）'),
                        _buildNoticeRow(),
                        _buildNoticeCount(),
                      ]),
                      const SizedBox(height: 12),

                      _sectionTitle('发包个数范围'),
                      _card([_buildNumsRow()]),
                      const SizedBox(height: 12),

                      _sectionTitle('红包设置'),
                      _card([_buildSecondRow()]),
                      const SizedBox(height: 20),

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
              '创建六合彩群',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF000000),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48, height: 48,
              color: const Color(0xFFF0ECFF),
              child: _avatarFull.isEmpty
                  ? const Icon(Icons.casino, color: AppColors.purple, size: 26)
                  : Image.network(
                      _avatarFull,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.casino, color: AppColors.purple, size: 26),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '群头像',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
            ),
          ),
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
                  : const Text(
                      '上传图片',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int? maxLength,
    bool required = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111),
                ),
                children: required
                    ? const [TextSpan(text: '*', style: TextStyle(color: Color(0xFFE94848)))]
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLength: maxLength,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 80,
              child: Text(
                '建群须知',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _noticeCtrl,
              maxLength: 80,
              maxLines: 3,
              minLines: 3,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: Color(0xFF111111), height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: '请填写建群须知（最多80字）',
                hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCount() => Padding(
        padding: const EdgeInsets.only(right: 14, bottom: 8, top: 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_noticeCtrl.text.length}/80',
            style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
          ),
        ),
      );

  Widget _buildNumsRow() {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text(
                '个数区间',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
              ),
            ),
            Expanded(child: _smallIntInput(_minNumsCtrl, '最小')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14)),
            ),
            Expanded(child: _smallIntInput(_maxNumsCtrl, '最大')),
            const SizedBox(width: 6),
            const Text('个', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondRow() {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text(
                '有效时间',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
              ),
            ),
            Expanded(child: _smallIntInput(_secondCtrl, '请输入秒数')),
            const SizedBox(width: 6),
            const Text('秒', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _smallIntInput(TextEditingController ctrl, String hint) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: const Color(0xFFEBEBF0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Opacity(
        opacity: _submitting ? 0.6 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _submitting ? '提交中…' : '提交审核',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}