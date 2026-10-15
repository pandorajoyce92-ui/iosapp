class SummaryCardData {
  final int uid;
  final String nickname;
  final String avatar;
  final String roleType;
  final String inviteCode;
  final String joinWay;
  final String belongTo;

  final double recharge;
  final double withdraw;
  final double sendFlow;
  final double getFlow;
  final double welfare;
  final double boomDeduct;
  final double boomReturn;
  final double winLoss;
  final double balance;
  final double ratio;

  final double preProfit;
  final double actualProfit; // 实际收益（分红收益 / 提点 / 群主分红）
  final String profitLabel;  // 收益标签文字

  final double sendRatio;    // ★ 新增：发包流水比例（代理用）
  final double grabRatio;    // ★ 新增：抢包流水比例（代理用）

  final Map<String, double> downlineSummary;

  SummaryCardData({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.roleType,
    required this.inviteCode,
    required this.joinWay,
    required this.belongTo,
    required this.recharge,
    required this.withdraw,
    required this.sendFlow,
    required this.getFlow,
    required this.welfare,
    required this.boomDeduct,
    required this.boomReturn,
    required this.winLoss,
    required this.balance,
    required this.ratio,
    required this.preProfit,
    required this.actualProfit,
    required this.profitLabel,
    required this.sendRatio,    // ★ 新增
    required this.grabRatio,    // ★ 新增
    required this.downlineSummary,
  });

  bool get isPlayer => roleType == 'player';
  bool get hasViewSubordinate => !isPlayer;

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory SummaryCardData.fromJson(Map<String, dynamic> j) {
    // 用 ?? {} 兜底，玩家卡片没有 downline_summary 也不会崩
    final dynamic rawDs = j['downline_summary'];
    final Map<String, dynamic> ds = (rawDs is Map)
        ? Map<String, dynamic>.from(rawDs)
        : <String, dynamic>{};

    return SummaryCardData(
      uid: _toInt(j['uid']),
      nickname: j['nickname']?.toString() ?? '',
      avatar: j['avatar']?.toString() ?? '',
      roleType: j['role_type']?.toString() ?? 'player',
      inviteCode: j['invite_code']?.toString() ?? '无',
      joinWay: j['join_way']?.toString() ?? '',
      belongTo: j['belong_to']?.toString() ?? '',
      recharge: _toDouble(j['recharge']),
      withdraw: _toDouble(j['withdraw']),
      sendFlow: _toDouble(j['send_flow']),
      getFlow: _toDouble(j['get_flow']),
      welfare: _toDouble(j['welfare']),
      boomDeduct: _toDouble(j['boom_deduct']),
      boomReturn: _toDouble(j['boom_return']),
      winLoss: _toDouble(j['win_loss']),
      balance: _toDouble(j['balance']),
      ratio: _toDouble(j['ratio']),
      preProfit: _toDouble(j['pre_profit']),
      actualProfit: _toDouble(j['actual_profit']),
      profitLabel: j['profit_label']?.toString() ?? '',
      sendRatio: _toDouble(j['send_ratio']),    // ★ 新增
      grabRatio: _toDouble(j['grab_ratio']),    // ★ 新增
      downlineSummary: {
        'total_send_flow':   _toDouble(ds['total_send_flow']),
        'total_get_flow':    _toDouble(ds['total_get_flow']),
        'total_boom_return': _toDouble(ds['total_boom_return']),
        'total_recharge':    _toDouble(ds['total_recharge']),
        'total_withdraw':    _toDouble(ds['total_withdraw']),
        'total_win_loss':    _toDouble(ds['total_win_loss']),
        'total_welfare':     _toDouble(ds['total_welfare']),
      },
    );
  }
}