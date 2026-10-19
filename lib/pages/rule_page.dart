import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_cache_manager.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class RulePage extends StatefulWidget {
  final int roomid;
  const RulePage({super.key, required this.roomid});

  @override
  State<RulePage> createState() => _RulePageState();
}

class _RulePageState extends State<RulePage> {
  bool _loading = false; // ★ 初始不显示全屏 loading
  bool _isOwner = false;
  bool _saving = false;

  String _savedImageUrl = '';
  Uint8List? _pickedBytes;

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
        '${ApiConfig.rule}&op=get_data&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final raw = r['image_url']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _savedImageUrl = _fullImageUrl(raw);
            _isOwner = _truthy(r['is_owner']);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [rule get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fullImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (mounted) {
        setState(() => _pickedBytes = bytes);
        _toast('图片已选择，点击保存生效');
      }
    } catch (e) {
      debugPrint('❌ [pickImage] $e');
      _toast('选择图片失败：$e');
    }
  }

  Future<void> _save() async {
    if (_pickedBytes == null) {
      _toast('请先选择图片');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(_pickedBytes!, filename: 'rule.jpg'),
        'roomid': widget.roomid.toString(),
      });

      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.saileiRoomInfo}&act=save_rule&roomid=${widget.roomid}',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast('保存成功');
        final url = data['url']?.toString() ?? '';
        if (mounted) {
          setState(() {
            if (url.isNotEmpty) _savedImageUrl = _fullImageUrl(url);
            _pickedBytes = null;
          });
        }
      } else {
        _toast(data is Map ? (data['result']?.toString() ?? '保存失败') : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [save_rule] $e');
      _toast('网络错误，请稍后再试');
    } finally {
      if (mounted) setState(() => _saving = false);
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
              _buildHeader(),
                            Expanded(
                              // ★ 直接渲染主体，不再全屏转圈
                              child: _buildBody(),
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
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque, // ★ 强制拦截，杜绝点击不灵敏
                        child: Container(
                          width: 50, height: 44,
                          alignment: Alignment.center,
                          child: const Icon(CupertinoIcons.back, color: Colors.black, size: 24),
                        ),
                      ),
                    ),
          const Center(
            child: Text(
              '赔率介绍',
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageArea(),
          _buildBottomArea(),
        ],
      ),
    );
  }

  // ---- 图片展示区 ----
  Widget _buildImageArea() {
    if (_pickedBytes != null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 480),
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(_pickedBytes!, fit: BoxFit.contain),
        ),
      );
    }

    if (_savedImageUrl.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: const Text(
          '暂无规则图片',
          style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 150, maxHeight: 480),
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: CachedNetworkImageProvider(
                    _savedImageUrl,
                    cacheManager: AppCacheManager.instance, // ★ 使用全局持久化缓存
                  ),
                  fit: BoxFit.contain,
                  frameBuilder: (_, child, __, ___) => child, // ★ 秒出无闪烁
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: const Text(
                      '图片加载失败',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                ),
      ),
    );
  }

  // ---- 底部区域 ----
  Widget _buildBottomArea() {
    if (!_isOwner) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Text(
          '仅群主可编辑规则图片',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 选择图片按钮（蓝）
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF0060DF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
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
                '📷 选择图片',
                style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          // 保存按钮（选了图才显示，绿）
          if (_pickedBytes != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _saving ? null : _save,
              child: Opacity(
                opacity: _saving ? 0.6 : 1,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF07C160),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF07C160).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _saving ? '保存中...' : '💾 保存规则',
                    style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            '仅群主可上传/更新规则图片',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}