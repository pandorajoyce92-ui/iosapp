/// 后端接口地址
class ApiConfig {
  static const String baseUrl = 'https://jianxinchat.top';

  /// 微擎会员模块入口
  static const String entryUrl =
      '$baseUrl/app/index.php?i=1&c=entry&do=member&m=sz_yi';

  // 登录相关
  static const String login    = '$entryUrl&p=login';
  static const String register = '$entryUrl&p=register';
  static const String forget   = '$entryUrl&p=forget';

  // 聊天大厅
  static const String game     = '$entryUrl&p=game';

  // 群相关
  static const String group          = '$entryUrl&p=group';
  static const String groupDetail    = '$entryUrl&p=group_detail';
  static const String createGroup    = '$entryUrl&p=create_group';
  static const String liuhecaiCreateGroup = '$entryUrl&p=liuhecai_create_group';

  // 股东
  static const String shareholderApply = '$entryUrl&p=shareholder_apply';

  // 房间
  static const String redpackets = '$entryUrl&p=redpackets';
  static const String liuhecai   = '$entryUrl&p=liuhecai';

  // 私聊 / 通讯录 / 我的
  static const String chatRoom    = '$entryUrl&p=chat_room';
  static const String addressBook = '$entryUrl&p=address_book';
  static const String mine        = '$entryUrl&p=mine';

  // 客服中心 / 推广
    static const String announcement = '$entryUrl&p=announcement';
    static const String under        = '$entryUrl&p=under';
    static const String servant      = '$entryUrl&p=servant';

  // 我的 - 子页面
    static const String personalData = '$entryUrl&p=personaldata';
    static const String recharge     = '$entryUrl&p=recharge_1';
    static const String withdrawal   = '$entryUrl&p=withdrawal';
    static const String redlog       = '$entryUrl&p=redlog';
    static const String gonggao      = '$entryUrl&p=gonggao';
    static const String install      = '$entryUrl&p=install';

  // 外部链接
    static const String downloadPage = '$baseUrl/app/download_page.php';

  // 设置 - 密码
    static const String loginPassword = '$entryUrl&p=login_password';
    static const String resetPassword = '$entryUrl&p=resetPassword';   // 注意大写 P
    static const String payPassword   = '$entryUrl&p=pay_password';

  // 个人资料 - 独立头像上传脚本
    static const String uploadAvatar     = '$baseUrl/app/upload_avatar.php';

  // ★★★ 新增：群规图片上传（独立脚本，20M 限制）
    static const String uploadGroupRule  = '$baseUrl/app/upload_group_rule.php';

  // 提现记录
    static const String withdrawalReport = '$entryUrl&p=withdrawal_report';

  // 短信验证码
    static const String sendCode = '$entryUrl&p=sendcode';

  // 群聊图片上传（微擎 util/uploader）
    static const String uploadImage = '$baseUrl/app/index.php?i=1&c=entry&do=util&m=sz_yi&p=uploader';

  // 幸运抽奖
    static const String lunpan = '$entryUrl&p=lunpan';

  // 群设置 - 子页
    static const String shareGroup         = '$entryUrl&p=share_group';
    static const String roomAnnouncement   = '$entryUrl&p=room_announcement';
    static const String saileiRoomInfo     = '$entryUrl&p=sailei_room_info';
    static const String welfareSetting     = '$entryUrl&p=welfare_setting';
    static const String lotterySetting     = '$entryUrl&p=lottery_setting';
    static const String rebateSetting      = '$entryUrl&p=rebate_setting';
    static const String immortalRobotLog   = '$entryUrl&p=immortal_robot_log';
    static const String chatDetails        = '$entryUrl&p=chatDetails';

  // 赔率介绍（独立页面）
    static const String rule = '$entryUrl&p=rule';

  // 抢包数字奖励
    static const String welfareNumbers = '$entryUrl&p=welfare_numbers';

  // 六合彩账单
    static const String liuhecaiRedlog = '$entryUrl&p=liuhecai_redlog';

  // 六合彩群设置
    static const String liuhecaiRoomInfo = '$entryUrl&p=liuhecai_room_info';

  // 六合彩分享群
    static const String liuhecaiShareGroup = '$entryUrl&p=liuhecai_share_group';

  // 六合彩群设置
    static const String liuhecaiRoomSetting = '$entryUrl&p=liuhecai_room_setting';

  // 六合彩群公告
    static const String liuhecaiRoomAnnouncement = '$entryUrl&p=liuhecai_room_announcement';

  // 六合彩赔率介绍
    static const String liuhecaiRule = '$entryUrl&p=liuhecai_rule';

  // 六合彩股东与代理
    static const String liuhecaiShareholderApply = '$entryUrl&p=liuhecai_shareholder_apply';

  // 六合彩下线列表
    static const String liuhecaiUnder = '$entryUrl&p=liuhecai_under';

  // 六合彩玩家返点设置
    static const String liuhecaiRebateSetting = '$entryUrl&p=liuhecai_rebate_setting';
}