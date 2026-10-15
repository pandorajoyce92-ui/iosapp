class GroupApply {
  final int roomId;
  final String roomname;
  final String roomnums;
  final List<GroupApplyItem> applies;

  GroupApply({
    required this.roomId,
    required this.roomname,
    required this.roomnums,
    required this.applies,
  });

  factory GroupApply.fromJson(Map<String, dynamic> json) => GroupApply(
        roomId: _toInt(json['id']),
        roomname: json['roomname']?.toString() ?? '',
        roomnums: json['roomnums']?.toString() ?? '',
        applies: (json['applies'] as List? ?? [])
            .map((e) => GroupApplyItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class GroupApplyItem {
  final int id;
  final int uid;
  final String nickname;
  final String avatar;

  GroupApplyItem({
    required this.id,
    required this.uid,
    required this.nickname,
    required this.avatar,
  });

  factory GroupApplyItem.fromJson(Map<String, dynamic> json) => GroupApplyItem(
        id: _toInt(json['id']),
        uid: _toInt(json['uid']),
        nickname: json['nickname']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? '',
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return 'https://jianxinchat.top/attachment/$avatar';
  }
}

class ShareholderApply {
  final int id;
  final int roomid;
  final int uid;
  final String nickname;
  final String avatar;
  final String mobile;
  final String sendRatio;
  final String grabRatio;
  final String remark;

  ShareholderApply({
    required this.id,
    required this.roomid,
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.mobile,
    required this.sendRatio,
    required this.grabRatio,
    required this.remark,
  });

  factory ShareholderApply.fromJson(Map<String, dynamic> json) =>
      ShareholderApply(
        id: _toInt(json['id']),
        roomid: _toInt(json['roomid']),
        uid: _toInt(json['uid']),
        nickname: json['nickname']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        sendRatio: json['send_ratio']?.toString() ?? '0',
        grabRatio: json['grab_ratio']?.toString() ?? '0',
        remark: json['remark']?.toString() ?? '',
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return 'https://jianxinchat.top/attachment/$avatar';
  }
}