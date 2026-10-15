class ChatMessage {
  final int id;
  final int type;        // 0转账 1文字 2图片 3充值 4提现 5六合彩转账
  final int uid;
  final String nickname;
  final String rawAvatar;
  final String content;
  final String addtime;
  final int timestamp;   // 原始时间戳（秒），用于时间分隔符

  // type=0 转账
  final double money;
  final String status;
  final int chatid;

  // type=3/4 充值提现
  final int applyId;
  final int roomid;
  final int roomnums;
  final double amount;
  final String playerNickname;
  final int playerUid;
  final int applyStatus;  // 0待处理 1已完成 2已拒绝
  final int isUpdate;     // 1=卡片状态更新消息

  // type=5 六合彩转账
  final int toUid;
  final String toNickname;
  final String toAvatar;

  ChatMessage({
    required this.id,
    required this.type,
    required this.uid,
    required this.nickname,
    required this.rawAvatar,
    required this.content,
    required this.addtime,
    this.timestamp = 0,
    this.money = 0,
    this.status = '',
    this.chatid = 0,
    this.applyId = 0,
    this.roomid = 0,
    this.roomnums = 0,
    this.amount = 0,
    this.playerNickname = '',
    this.playerUid = 0,
    this.applyStatus = 0,
    this.isUpdate = 0,
    this.toUid = 0,
    this.toNickname = '',
    this.toAvatar = '',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _toInt(json['id']),
        type: _toInt(json['type']),
        uid: _toInt(json['uid']),
        nickname: json['nickname']?.toString() ?? '',
        rawAvatar: json['avatar']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        addtime: json['addtime']?.toString() ?? '',
        timestamp: _toInt(json['timestamp']),
        money: _toDouble(json['money']),
        status: json['status']?.toString() ?? '',
        chatid: _toInt(json['chatid']),
        applyId: _toInt(json['apply_id']),
        roomid: _toInt(json['roomid']),
        roomnums: _toInt(json['roomnums']),
        amount: _toDouble(json['amount']),
        playerNickname: json['player_nickname']?.toString() ?? '',
        playerUid: _toInt(json['player_uid']),
        applyStatus: _toInt(json['apply_status']),
        isUpdate: _toInt(json['is_update']),
        toUid: _toInt(json['to_uid']),
        toNickname: json['to_nickname']?.toString() ?? '',
        toAvatar: json['to_avatar']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'uid': uid,
        'nickname': nickname,
        'avatar': rawAvatar,
        'content': content,
        'addtime': addtime,
        'timestamp': timestamp,
        'money': money,
        'status': status,
        'chatid': chatid,
        'apply_id': applyId,
        'roomid': roomid,
        'roomnums': roomnums,
        'amount': amount,
        'player_nickname': playerNickname,
        'player_uid': playerUid,
        'apply_status': applyStatus,
        'is_update': isUpdate,
        'to_uid': toUid,
        'to_nickname': toNickname,
        'to_avatar': toAvatar,
      };

  /// 用于卡片状态更新时替换
  ChatMessage copyWith({int? applyStatus}) => ChatMessage(
        id: id,
        type: type,
        uid: uid,
        nickname: nickname,
        rawAvatar: rawAvatar,
        content: content,
        addtime: addtime,
        timestamp: timestamp,
        money: money,
        status: status,
        chatid: chatid,
        applyId: applyId,
        roomid: roomid,
        roomnums: roomnums,
        amount: amount,
        playerNickname: playerNickname,
        playerUid: playerUid,
        applyStatus: applyStatus ?? this.applyStatus,
        isUpdate: isUpdate,
        toUid: toUid,
        toNickname: toNickname,
        toAvatar: toAvatar,
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String get avatarUrl => buildAvatar(rawAvatar);

  String get toAvatarUrl => buildAvatar(toAvatar);

  static String buildAvatar(String a) {
    a = a.trim();
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