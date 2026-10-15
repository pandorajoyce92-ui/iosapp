import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/http_client.dart';

class ShareholderApplyPage extends StatefulWidget {
  final int roomid;
  const ShareholderApplyPage({super.key, required this.roomid});

  @override
  State<ShareholderApplyPage> createState() => _ShareholderApplyPageState();
}

class _ShareholderApplyPageState extends State<ShareholderApplyPage> {
  bool _loading = true;

  bool _isOwner = false;
  bool _isShareholder = false;
  bool _isAgent = false;
  int _myAgentLevel = -1;
  int _myUid = 0;
  double _mySendRatio = 0;
  double _myGrabRatio = 0;
  double _myRatio = 0;
  int _ownerUid = 0;

  List<_Member> _members = [];

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
        '${ApiConfig.shareholderApply}&op=get_members&roomid=${widget.roomid}',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final list = (r['members'] as List? ?? [])
            .map((e) => _Member.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (mounted) {
          setState(() {
            _isOwner = _truthy(r['is_owner']);
            _isShareholder = _truthy(r['is_shareholder']);
            _isAgent = _truthy(r['is_agent']);
            _myAgentLevel = int.tryParse(r['my_agent_level']?.toString() ?? '-1') ?? -1;
            _myUid = int.tryParse(r['my_uid']?.toString() ?? '0') ?? 0;
            _mySendRatio = _toDouble(r['my_send_ratio']);
            _myGrabRatio = _toDouble(r['my_grab_ratio']);
            _myRatio = _toDouble(r['my_ratio']);
            _ownerUid = int.tryParse(r['owner_uid']?.toString() ?? '0') ?? 0;
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
      debugPrint('❌ [shareholder_apply get_members] $e');
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
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  List<String> _getAvailableOptions(int targetLevel) {
    final my = _myAgentLevel;
    final opts = <String>[];

    if (my == 99) {
      opts.add('cancel');
      opts.add('shareholder');
      opts.add('agent_1');
      opts.add('player_rebate');
    } else if (my == 0) {
      if (targetLevel == -1) {
        opts.add('agent_1');
        opts.add('player_rebate');
      } else if (targetLevel == 1) {
        opts.add('cancel');
        opts.add('player_rebate');
      }
    } else if (my == 1) {
      if (targetLevel == -1) {
        opts.add('agent_2');
        opts.add('player_rebate');
      } else if (targetLevel == 2) {
        opts.add('cancel');
        opts.add('player_rebate');
      }
    } else if (my == 2) {
      if (targetLevel == -1) {
        opts.add('agent_3');
        opts.add('player_rebate');
      } else if (targetLevel == 3) {
        opts.add('cancel');
        opts.add('player_rebate');
      }
    } else if (my == 3) {
      if (targetLevel == -1) {
        opts.add('player_rebate');
      }
    }
    return opts;
  }

  Future<void> _openSetRole(_Member m) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _RoleSheet(
        roomid: widget.roomid,
        target: m,
        myAgentLevel: _myAgentLevel,
        mySendRatio: _mySendRatio,
        myGrabRatio: _myGrabRatio,
        availableOptions: _getAvailableOptions(m.agentLevel),
      ),
    );
    if (result == true && mounted) {
      _load();
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

  Widget _buildTopBar() {
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
          _buildMyPanel(),
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

  Widget _buildMyPanel() {
    final lvl = _myAgentLevel;

    if (lvl == 99 || lvl == 0) {
      final tip = lvl == 99
          ? '你是群主，可设置股东、一级代理，也可以给玩家设返点。'
          : '你是股东（分红 ${_fmtRatio(_myRatio)}%），可设置一级代理，也可以给玩家设返点。';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: Color(0xFF007AFF), width: 4),
          ),
        ),
        child: Text(
          tip,
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.8),
        ),
      );
    }

    if (lvl == 1 || lvl == 2 || lvl == 3) {
      final lvlText = lvl == 1 ? '一级代理' : (lvl == 2 ? '二级代理' : '三级代理');
      final tip = lvl == 3
          ? '你是三级代理，不能设下级代理，只能给玩家设返点。'
          : (lvl == 1
              ? '你可以设置二级代理，也可以给玩家设返点。下级点位不能超过你自己的返点。'
              : '你可以设置三级代理，也可以给玩家设返点。下级点位不能超过你自己的返点。');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE6F2FF), Color(0xFFD9F0E7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的身份：$lvlText',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                  ),
                ),
                Text(
                  '发包返点：${_fmtRatio(_mySendRatio)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                  ),
                ),
                Text(
                  '抢包返点：${_fmtRatio(_myGrabRatio)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: Color(0xFF007AFF), width: 4),
              ),
            ),
            child: Text(
              tip,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.8),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMemberItem(_Member m) {
    final opts = m.isOwner || m.id == _myUid
        ? <String>[]
        : _getAvailableOptions(m.agentLevel);
    final canSet = opts.isNotEmpty;

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
              child: m.avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF007AFF), size: 22)
                  : Image.network(
                      m.avatarUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Color(0xFF007AFF), size: 22),
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
                        m.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    if (_buildRoleTag(m) != null) ...[
                      const SizedBox(width: 6),
                      _buildRoleTag(m)!,
                    ],
                  ],
                ),
                if (_ratioHint(m).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _ratioHint(m),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                  ),
                ],
              ],
            ),
          ),
          if (canSet)
            GestureDetector(
              onTap: () => _openSetRole(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildRoleTag(_Member m) {
    if (m.isOwner) return _tag('群主', const Color(0xFFE94848));
    if (m.agentLevel == 0) return _tag('股东', const Color(0xFF8B5CF6));
    if (m.agentLevel == 1) return _tag('一级代理', const Color(0xFF3B82F6));
    if (m.agentLevel == 2) return _tag('二级代理', const Color(0xFF06B6D4));
    if (m.agentLevel == 3) return _tag('三级代理', const Color(0xFF10B981));
    return null;
  }

  Widget _tag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _ratioHint(_Member m) {
    if (m.isOwner) return '';
    if (m.agentLevel == 1 || m.agentLevel == 2 || m.agentLevel == 3) {
      return '发包 ${_fmtRatio(m.sendRatio)}% · 抢包 ${_fmtRatio(m.grabRatio)}%';
    }
    if (m.agentLevel == 0 && m.ratio > 0) {
      return '分红 ${_fmtRatio(m.ratio)}%';
    }
    if (m.agentLevel == -1) {
      if (m.sendRatio > 0 || m.grabRatio > 0) {
        return '玩家返点 发包 ${_fmtRatio(m.sendRatio)}% · 抢包 ${_fmtRatio(m.grabRatio)}%';
      }
    }
    return '';
  }

  String _fmtRatio(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

// ================= 成员模型 =================
class _Member {
  final int id;
  final String nickname;
  final String avatar;
  final int roleType;
  final int agentLevel;
  final double ratio;
  final double sendRatio;
  final double grabRatio;
  final bool isOwner;

  _Member({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.roleType,
    required this.agentLevel,
    required this.ratio,
    required this.sendRatio,
    required this.grabRatio,
    required this.isOwner,
  });

  factory _Member.fromJson(Map<String, dynamic> j) {
    return _Member(
      id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
      nickname: j['nickname']?.toString() ?? '',
      avatar: j['avatar']?.toString() ?? '',
      roleType: int.tryParse(j['role_type']?.toString() ?? '0') ?? 0,
      agentLevel: int.tryParse(j['agent_level']?.toString() ?? '-1') ?? -1,
      ratio: _d(j['ratio']),
      sendRatio: _d(j['send_ratio']),
      grabRatio: _d(j['grab_ratio']),
      isOwner: (j['is_owner']?.toString() == '1'),
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) return avatar;
    if (avatar.startsWith('../')) {
      return 'https://jianxinchat.top/${avatar.replaceFirst('../', '')}';
    }
    return 'https://jianxinchat.top/${avatar.replaceFirst(RegExp(r'^/+'), '')}';
  }
}

// ================= 设置角色弹窗 =================
class _RoleSheet extends StatefulWidget {
  final int roomid;
  final _Member target;
  final int myAgentLevel;
  final double mySendRatio;
  final double myGrabRatio;
  final List<String> availableOptions;

  const _RoleSheet({
    required this.roomid,
    required this.target,
    required this.myAgentLevel,
    required this.mySendRatio,
    required this.myGrabRatio,
    required this.availableOptions,
  });

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late String _selectedOpt;
  final _ratioCtrl = TextEditingController();
  final _sendCtrl = TextEditingController();
  final _grabCtrl = TextEditingController();
  bool _saving = false;

  static const _optLabels = <String, String>{
    'cancel': '取消身份',
    'shareholder': '设为股东',
    'agent_1': '设为一级代理',
    'agent_2': '设为二级代理',
    'agent_3': '设为三级代理',
    'player_rebate': '设置玩家返点',
  };

  @override
  void initState() {
    super.initState();
    _selectedOpt = widget.availableOptions.isNotEmpty
        ? widget.availableOptions.first
        : 'cancel';
    _ratioCtrl.text = _fmt(widget.target.ratio);
    _sendCtrl.text = _fmt(widget.target.sendRatio);
    _grabCtrl.text = _fmt(widget.target.grabRatio);
  }

  @override
  void dispose() {
    _ratioCtrl.dispose();
    _sendCtrl.dispose();
    _grabCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2000)),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final opt = _selectedOpt;

    String op;
    final Map<String, dynamic> data = {
      'roomid': widget.roomid,
      'uid': widget.target.id,
    };

    if (opt == 'cancel') {
      op = 'set_role';
      data['role_type'] = 0;
    } else if (opt == 'shareholder') {
      final ratio = double.tryParse(_ratioCtrl.text) ?? 0;
      if (ratio < 0 || ratio > 100) {
        _toast('分红比例需在 0~100 之间');
        return;
      }
      op = 'set_role';
      data['role_type'] = 1;
      data['ratio'] = ratio;
    } else if (opt == 'agent_1' || opt == 'agent_2' || opt == 'agent_3') {
      final lvl = int.parse(opt.replaceFirst('agent_', ''));
      final send = double.tryParse(_sendCtrl.text) ?? 0;
      final grab = double.tryParse(_grabCtrl.text) ?? 0;
      if (send < 0 || send > 100) {
        _toast('发包比例需在 0~100');
        return;
      }
      if (grab < 0 || grab > 100) {
        _toast('抢包比例需在 0~100');
        return;
      }
      if (widget.myAgentLevel != 99 && widget.myAgentLevel != 0) {
        if (send > widget.mySendRatio) {
          _toast('发包比例不能超过 ${_fmt(widget.mySendRatio)}%');
          return;
        }
        if (grab > widget.myGrabRatio) {
          _toast('抢包比例不能超过 ${_fmt(widget.myGrabRatio)}%');
          return;
        }
      }
      op = 'set_role';
      data['role_type'] = 2;
      data['agent_level'] = lvl;
      data['send_ratio'] = send;
      data['grab_ratio'] = grab;
    } else if (opt == 'player_rebate') {
      final send = double.tryParse(_sendCtrl.text) ?? 0;
      final grab = double.tryParse(_grabCtrl.text) ?? 0;
      if (send < 0 || send > 100) {
        _toast('发包返点需在 0~100');
        return;
      }
      if (grab < 0 || grab > 100) {
        _toast('抢包返点需在 0~100');
        return;
      }
      if (widget.myAgentLevel != 99 && widget.myAgentLevel != 0) {
        if (send > widget.mySendRatio) {
          _toast('发包返点不能超过 ${_fmt(widget.mySendRatio)}%');
          return;
        }
        if (grab > widget.myGrabRatio) {
          _toast('抢包返点不能超过 ${_fmt(widget.myGrabRatio)}%');
          return;
        }
      }
      op = 'set_player_rebate';
      data['send_ratio'] = send;
      data['grab_ratio'] = grab;
    } else {
      return;
    }

    data['op'] = op;

    setState(() => _saving = true);
    try {
      final res = await HttpClient.instance.dio.post(
        ApiConfig.shareholderApply,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic body = res.data;
      if (body is String) {
        try { body = jsonDecode(body); } catch (_) {}
      }
      if (body is Map && body['status']?.toString() == '1') {
        _toast('保存成功');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final msg = body is Map
            ? (body['result']?.toString() ?? body['msg']?.toString() ?? '保存失败')
            : '保存失败';
        _toast(msg);
      }
    } catch (e) {
      debugPrint('❌ [save] $e');
      _toast('网络错误，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showRatio = _selectedOpt == 'shareholder';
    final showSendGrab = _selectedOpt == 'agent_1' ||
        _selectedOpt == 'agent_2' ||
        _selectedOpt == 'agent_3' ||
        _selectedOpt == 'player_rebate';
    final showLimitHint = (_selectedOpt == 'agent_1' ||
            _selectedOpt == 'agent_2' ||
            _selectedOpt == 'agent_3' ||
            _selectedOpt == 'player_rebate') &&
        widget.myAgentLevel != 99 &&
        widget.myAgentLevel != 0;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
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
                const Text(
                  '目标',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.target.nickname}（UID: ${widget.target.id}）',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '选择操作',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    border: Border.all(color: const Color(0xFFD0E4FF)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedOpt,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
                      items: widget.availableOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt,
                          child: Text(_optLabels[opt] ?? opt),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedOpt = v);
                      },
                    ),
                  ),
                ),
                if (showRatio) ...[
                  const SizedBox(height: 14),
                  _labeledField('分红比例（%）', _ratioCtrl, '如 25.0'),
                ],
                if (showSendGrab) ...[
                  const SizedBox(height: 14),
                  _labeledField(
                    '发包提成比例（%）',
                    _sendCtrl,
                    '如 3.0',
                    hintText: showLimitHint
                        ? '不能超过你的发包返点 ${_fmt(widget.mySendRatio)}%'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _labeledField(
                    '抢包提成比例（%）',
                    _grabCtrl,
                    '如 2.0',
                    hintText: showLimitHint
                        ? '不能超过你的抢包返点 ${_fmt(widget.myGrabRatio)}%'
                        : null,
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
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController ctrl,
    String hint, {
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F9FF),
            border: Border.all(color: const Color(0xFFD0E4FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
            ),
          ),
        ),
        if (hintText != null) ...[
          const SizedBox(height: 4),
          Text(
            hintText,
            style: const TextStyle(fontSize: 12, color: Color(0xFFE94848)),
          ),
        ],
      ],
    );
  }
}