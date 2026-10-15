class NewFriendItem {
  final int id;
  final int uid;
  final int fuid;
  final String nickname;
  final String rawAvatar;
  final String addtime;
  final String remark;

  NewFriendItem({
    required this.id,
    required this.uid,
    required this.fuid,
    required this.nickname,
    required this.rawAvatar,
    required this.addtime,
    required this.remark,
  });

  factory NewFriendItem.fromJson(Map<String, dynamic> json) => NewFriendItem(
        id: _toInt(json['id']),
        uid: _toInt(json['uid']),
        fuid: _toInt(json['fuid']),
        nickname: json['nickname']?.toString() ?? '',
        rawAvatar: json['avatar']?.toString() ?? '',
        addtime: json['addtime']?.toString() ?? '',
        remark: json['remark']?.toString() ?? '',
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl {
    final a = rawAvatar.trim();
    if (a.isEmpty) return '';
    if (a.startsWith('http://')) return a.replaceFirst('http://', 'https://');
    if (a.startsWith('https://')) return a;
    if (a.startsWith('/')) return 'https://jianxinchat.top$a';
    if (a.startsWith('images/') || a.startsWith('attachment/')) {
      return 'https://jianxinchat.top/attachment/$a';
    }
    return 'https://jianxinchat.top/attachment/$a';
  }
}