class FriendItem {
  final int id;
  final int uid;
  final int fuid;
  final String nickname;
  final String rawAvatar;
  final int unread;

  FriendItem({
    required this.id,
    required this.uid,
    required this.fuid,
    required this.nickname,
    required this.rawAvatar,
    required this.unread,
  });

  factory FriendItem.fromJson(Map<String, dynamic> json) => FriendItem(
        id: _toInt(json['id']),
        uid: _toInt(json['uid']),
        fuid: _toInt(json['fuid']),
        nickname: json['nickname']?.toString() ?? '',
        rawAvatar: json['avatar']?.toString() ?? '',
        unread: _toInt(json['unread']),
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// 智能拼接头像 URL（兼容多种数据格式）
  String get avatarUrl {
    final a = rawAvatar.trim();
    if (a.isEmpty) return '';

    // 1. 完整 URL（http/https）
    if (a.startsWith('http://') || a.startsWith('https://')) {
      // http 强制改 https，避免明文流量拦截
      if (a.startsWith('http://')) {
        return a.replaceFirst('http://', 'https://');
      }
      return a;
    }

    // 2. 以 / 开头（绝对路径）
    if (a.startsWith('/')) {
      return 'https://jianxinchat.top$a';
    }

    // 3. 以 images/ 或 attachment/ 开头
    if (a.startsWith('images/') || a.startsWith('attachment/')) {
      return 'https://jianxinchat.top/attachment/$a';
    }

    // 4. 默认：只有文件名，拼 /attachment/
    return 'https://jianxinchat.top/attachment/$a';
  }
}