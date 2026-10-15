class Friend {
  final int fuid;
  final String nickname;
  final String avatar;
  final int unread;
  final int lastTime;

  Friend({
    required this.fuid,
    required this.nickname,
    required this.avatar,
    required this.unread,
    required this.lastTime,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        fuid: _toInt(json['fuid']),
        nickname: json['nickname']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? '',
        unread: _toInt(json['unread']),
        lastTime: _toInt(json['last_time']),
      );

        Map<String, dynamic> toJson() => {
              'fuid': fuid,
              'nickname': nickname,
              'avatar': avatar,
              'unread': unread,
              'last_time': lastTime,
            };

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return 'https://jianxinchat.top$avatar';
  }
}