import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class LiuhecaiShareholderApplyPage extends StatefulWidget {
  final int roomid;
  const LiuhecaiShareholderApplyPage({super.key, required this.roomid});

  @override
  State<LiuhecaiShareholderApplyPage> createState() =>
      _LiuhecaiShareholderApplyPageState();
}

class _LiuhecaiShareholderApplyPageState
    extends State<LiuhecaiShareholderApplyPage> {
  bool _loading = true;

  bool _isOwner = false;
  bool _isShareholder = false;
  bool _isAgent = false;
  double _myRatio = 0;

  List<Map<String, dynamic>> _members = [];

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0xF2FFFFFF);
  static const Color _borderColor = Color(0xFFD0E4FF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiShareholderApply}&op=get_members&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['members'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (mounted) {
          setState(() {
            _isOwner = _truthy(r['is_owner']);
            _isShareholder = _truthy(r['is_shareholder']);
            _isAgent = _truthy(r['is_agent']);
            _myRatio = _toDouble(r['my_ratio']);
            _members = list;
            _loading = false;
          });
        }
      } else {
        final msg = data is Map ? (data['result']?.toString() ?? '加载失败') : '加载失败';
        if (mounted) setState(() => _loading = false);
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_shareholder_apply get_members] $e');
      if (mounted) setState(() => _loading = false);
      _toast('网络错误');
    }
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
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

  String _fmtRatio(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  Future<void> _openSetRole(Map<String, dynamic> m) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _SetRoleSheet(
        roomid: widget.roomid,
        target: m,
        isOwner: _isOwner,
        isShareholder: _isShareholder,
      ),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _openRebate(Map<String, dynamic> m) async {
    final playerUid = _toInt(m['id']);
    if (playerUid <= 0) return;

    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.liuhecaiShareholderApply}&op=get_rebate&roomid=${widget.roomid}&player_uid=$playerUid',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        if (!mounted) return;
        final ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.55),
          builder: (_) => _RebateSheet(
            roomid: widget.roomid,
            playerUid: playerUid,
            playerNickname:
                r['player_nickname']?.toString() ?? m['nickname']?.toString() ?? '',
            agentRatio: _toDouble(r['agent_ratio']),
            currentRebate: _toDouble(r['rebate_ratio']),
          ),
        );
        if (ok == true && mounted) _load();
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '加载失败')
            : '加载失败');
      }
    } catch (e) {
      debugPrint('❌ [liuhecai_shareholder_apply get_rebate] $e');
      _toast('网络错误');
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fullAvatarUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('../')) {
      return '${ApiConfig.baseUrl}/${raw.replaceFirst('../', '')}';
    }
    return '${ApiConfig.baseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
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
            left: 8,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 40,
                height: 44,
                child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
              ),
            ),
          ),
          const Center(
            child: Text(
              '股东与代理',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isAgent) _buildRatioBox(),
          if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  '暂无成员',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
              ),
            )
          else
            ..._members.map(_buildMemberItem),
        ],
      ),
    );
  }

  Widget _buildRatioBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF007AFF),
            fontWeight: FontWeight.w600,
            height: 1.6,
          ),
          children: [
            const TextSpan(text: '当前佣金比例：'),
            TextSpan(text: '${_fmtRatio(_myRatio)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> m) {
    final avatar = _fullAvatarUrl(m['avatar']?.toString() ?? '');
    final nickname = m['nickname']?.toString() ?? '';
    final roleType = _toInt(m['role_type']);
    final todayBet = _toDouble(m['today_bet']);
    final myRebate = _toDouble(m['my_rebate']);

    final canSet = _isOwner || _isShareholder;
    final canRebate = _isAgent && roleType == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: const Color(0xFFE6F2FF),
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF007AFF), size: 22)
                  : Image.network(
                      avatar,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Color(0xFF007AFF),
                        size: 22,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    if (roleType == 1) ...[
                      const SizedBox(width: 6),
                      _roleTag('股东', const Color(0xFF8B5CF6)),
                    ] else if (roleType == 2) ...[
                      const SizedBox(width: 6),
                      _roleTag('代理', const Color(0xFFF59E0B)),
                    ],
                  ],
                ),
                if (_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '今日下注：${todayBet.toStringAsFixed(2)} 元',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canSet)
                GestureDetector(
                  onTap: () => _openSetRole(m),
                  child: _actionBtn('设置', const Color(0xFF007AFF)),
                ),
              if (canSet && canRebate) const SizedBox(width: 6),
              if (canRebate)
                GestureDetector(
                  onTap: () => _openRebate(m),
                  child: _actionBtn(
                    myRebate > 0 ? '返点 (${_fmtRatio(myRebate)}%)' : '返点',
                    const Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleTag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ==================== 设置角色弹窗 ====================
class _SetRoleSheet extends StatefulWidget {
  final int roomid;
  final Map<String, dynamic> target;
  final bool isOwner;
  final bool isShareholder;

  const _SetRoleSheet({
    required this.roomid,
    required this.target,
    required this.isOwner,
    required this.isShareholder,
  });

  @override
  State<_SetRoleSheet> createState() => _SetRoleSheetState();
}

class _SetRoleSheetState extends State<_SetRoleSheet> {
  late int _roleType;
  final _ratioCtrl = TextEditingController(text: '0.0');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roleType = int.tryParse(widget.target['role_type']?.toString() ?? '0') ?? 0;
  }

  @override
  void dispose() {
    _ratioCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final ratio = double.tryParse(_ratioCtrl.text.trim()) ?? 0;
    if (_roleType != 0 && (ratio < 0)) {
      _toast('请输入有效比例');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiShareholderApply}&op=set_role&roomid=${widget.roomid}',
        data: {
          'op': 'set_role',
          'roomid': widget.roomid,
          'uid': widget.target['id'],
          'role_type': _roleType,
          'ratio': ratio,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast(data['result']?.toString() ?? '保存成功');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '保存失败')
            : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [set_role] $e');
      _toast('网络错误');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  '设置角色',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('选择角色',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _LiuhecaiShareholderApplyPageColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _roleType,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                    items: _buildRoleOptions(),
                    onChanged: (v) {
                      if (v != null) setState(() => _roleType = v);
                    },
                  ),
                ),
              ),
              if (_roleType != 0) ...[
                const SizedBox(height: 14),
                const Text('设置比例（%）',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                const SizedBox(height: 6),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _LiuhecaiShareholderApplyPageColors.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _ratioCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '如 3.5',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFBBBBBB),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Opacity(
                        opacity: _saving ? 0.7 : 1,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _saving ? '保存中...' : '保存',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildRoleOptions() {
    final items = <DropdownMenuItem<int>>[];
    if (widget.isOwner) {
      items.add(const DropdownMenuItem(value: 0, child: Text('取消身份')));
      items.add(const DropdownMenuItem(value: 1, child: Text('设为股东')));
      items.add(const DropdownMenuItem(value: 2, child: Text('设为代理')));
    } else if (widget.isShareholder) {
      items.add(const DropdownMenuItem(value: 0, child: Text('取消身份')));
      items.add(const DropdownMenuItem(value: 2, child: Text('设为代理')));
    }
    return items;
  }
}

// ==================== 返点设置弹窗 ====================
class _RebateSheet extends StatefulWidget {
  final int roomid;
  final int playerUid;
  final String playerNickname;
  final double agentRatio;
  final double currentRebate;

  const _RebateSheet({
    required this.roomid,
    required this.playerUid,
    required this.playerNickname,
    required this.agentRatio,
    required this.currentRebate,
  });

  @override
  State<_RebateSheet> createState() => _RebateSheetState();
}

class _RebateSheetState extends State<_RebateSheet> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.currentRebate));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final rebate = double.tryParse(_ctrl.text.trim()) ?? 0;
    if (rebate < 0) {
      _toast('返点不能为负数');
      return;
    }
    if (rebate > widget.agentRatio) {
      _toast('返点不能超过 ${_fmt(widget.agentRatio)}%');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.liuhecaiShareholderApply}&op=set_rebate&roomid=${widget.roomid}',
        data: {
          'op': 'set_rebate',
          'roomid': widget.roomid,
          'player_uid': widget.playerUid,
          'rebate_ratio': rebate,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status']?.toString() == '1') {
        _toast(data['result']?.toString() ?? '设置成功');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _toast(data is Map
            ? (data['result']?.toString() ?? '保存失败')
            : '保存失败');
      }
    } catch (e) {
      debugPrint('❌ [set_rebate] $e');
      _toast('网络错误');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  '设置返点',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                  children: [
                    const TextSpan(text: '玩家：'),
                    TextSpan(
                      text: widget.playerNickname,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                  children: [
                    const TextSpan(text: '您的佣金比例：'),
                    TextSpan(
                      text: '${_fmt(widget.agentRatio)}%',
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '给玩家设置的返点（%），不能超过您的佣金比例',
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _LiuhecaiShareholderApplyPageColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF222222),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '如 2.0',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFBBBBBB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Opacity(
                        opacity: _saving ? 0.7 : 1,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _saving ? '保存中...' : '保存',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 弹窗辅助类：避免命名冲突
class _LiuhecaiShareholderApplyPageColors {
  static const Color borderColor = Color(0xFFD0E4FF);
}