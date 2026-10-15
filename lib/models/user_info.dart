/// 当前登录用户信息（兼容 announcement.php / mine.php 两个接口）
class UserInfo {
  final int id;
  final String nickname;
  final String mobile;
  final String avatar;
  final String goldmoney; // mine.php 返回，announcement.php 为空

  UserInfo({
    required this.id,
    required this.nickname,
    required this.mobile,
    required this.avatar,
    this.goldmoney = '',
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['avatar']?.toString() ?? '';
    return UserInfo(
      id: _toInt(json['id']),
      nickname: json['nickname']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      avatar: raw,
      goldmoney: json['goldmoney']?.toString() ?? '',
    );
  }

  /// 完整头像 URL
  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return 'https://jianxinchat.top/attachment/${avatar.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}