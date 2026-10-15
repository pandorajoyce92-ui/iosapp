class Room {
  final int id;
  final String roomname;
  final String surl;
  final int type;
  final double min;
  final double max;
  final List<dynamic> content;
  final int displayCount;
  final int messageCount;

  Room({
    required this.id,
    required this.roomname,
    required this.surl,
    required this.type,
    required this.min,
    required this.max,
    required this.content,
    required this.displayCount,
    required this.messageCount,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: _toInt(json['id']),
        roomname: json['roomname']?.toString() ?? '',
        surl: json['surl']?.toString() ?? '',
        type: _toInt(json['type']),
        min: _toDouble(json['min']),
        max: _toDouble(json['max']),
        content: json['content'] is List ? json['content'] : [],
        displayCount: _toInt(json['display_count']),
        messageCount: _toInt(json['message_count']),
      );

        Map<String, dynamic> toJson() => {
              'id': id,
              'roomname': roomname,
              'surl': surl,
              'type': type,
              'min': min,
              'max': max,
              'content': content,
              'display_count': displayCount,
              'message_count': messageCount,
            };

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

    String get avatarUrl {
      if (surl.isEmpty) return '';
      if (surl.startsWith('http://') || surl.startsWith('https://')) return surl;
      // ★ 已经带 /attachment/ 前缀 → 直接用
      if (surl.startsWith('/attachment/')) {
        return 'https://jianxinchat.top$surl';
      }
      // ★ 带 attachment/ 前缀（不带斜杠）→ 补斜杠
      if (surl.startsWith('attachment/')) {
        return 'https://jianxinchat.top/$surl';
      }
      // ★ 纯相对路径 → 补 /attachment/
      return 'https://jianxinchat.top/attachment/$surl';
    }

  String get subtitle {
    if (type == 3) return '六合彩';
    final minStr = min.toStringAsFixed(min == min.roundToDouble() ? 0 : 2);
    final maxStr = max.toStringAsFixed(max == max.roundToDouble() ? 0 : 2);
    final base = '$minStr-$maxStr元';
    if (type == 2) return base;
    final odds = content.isNotEmpty ? content[0]?.toString() ?? '' : '';
    if (odds.isNotEmpty) return '$base 踩雷${odds}倍';
    return base;
  }
}