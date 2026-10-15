import 'package:flutter/material.dart';

// ====================================================================
//                    ①  拆红包弹窗
// ====================================================================
class RedPacketOpenDialog extends StatelessWidget {
  final String nickname;
  final String avatar;
  final String message;
  final bool canOpen;

  const RedPacketOpenDialog({
    super.key,
    required this.nickname,
    required this.avatar,
    required this.message,
    required this.canOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: 310,
        height: 536, // 卡片 430 + 关闭按钮 70 + 36
        child: Stack(
          children: [
            // ---- 卡片主体 ----
            Positioned(
              top: 0, left: 0, right: 0,
              height: 430,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE24E3D),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 40,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: Stack(
                                                children: [
                                                  // 上部弧形浅红 + 底部金色分隔线
                                                  Positioned(
                                                    top: -150, left: -40, right: -40, height: 440,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFFF65C4C), Color(0xFFF44C3C)],
                                                          begin: Alignment.topCenter,
                                                          end: Alignment.bottomCenter,
                                                        ),
                                                        borderRadius: BorderRadius.circular(9999),
                                                        border: const Border(
                                                          bottom: BorderSide(color: Color(0xFFFAD290), width: 2),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                      // 内容
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: _avatarWidget(avatar, 52),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                nickname.isEmpty ? '红包' : '$nickname的红包',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF8E1AA),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                message.isEmpty ? '恭喜发财,大吉大利' : message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 圆按钮
                      Positioned(
                        left: 0, right: 0, bottom: 70,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop('open'),
                            child: Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFE299), Color(0xFFEDB95D)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '领取',
                                style: TextStyle(
                                  color: Color(0xFFA75B1C),
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // "看看手气" 链接（只在不能领取时显示）
                      if (!canOpen)
                        Positioned(
                          left: 0, right: 0, bottom: 25,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop('detail'),
                            child: const Center(
                              child: Text(
                                '看看大家的手气 >',
                                style: TextStyle(color: Color(0xFFF8E1AA), fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // ---- 关闭按钮 ----
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop('close'),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '×',
                      style: TextStyle(color: Colors.white, fontSize: 22, height: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarWidget(String url, double size) {
    if (url.isEmpty) {
      return Container(
        width: size, height: size,
        color: Colors.white24,
        alignment: Alignment.center,
        child: Icon(Icons.person, color: Colors.white.withOpacity(0.6), size: size * 0.55),
      );
    }
    return Image.network(
      url,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        color: Colors.white24,
        alignment: Alignment.center,
        child: Icon(Icons.person, color: Colors.white.withOpacity(0.6), size: size * 0.55),
      ),
    );
  }
}

// ====================================================================
//                    ②  红包详情面板
// ====================================================================
class RedPacketDetailPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpenReport;

  const RedPacketDetailPanel({
    super.key,
    required this.data,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = data['avatar']?.toString() ?? '';
    final nickname = data['nickname']?.toString() ?? '';
    final gold = data['gold']?.toString() ?? '0';
    final nums = data['nums']?.toString() ?? '0';
    final boom = data['boom']?.toString() ?? '';
    final selfMoney = data['self_money']?.toString() ?? '0.00';
    final getedtime = data['getedtime']?.toString() ?? '';
    final list = (data['list'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final selfMoneyNum = double.tryParse(selfMoney) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 顶部红色 header
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              height: 54 + MediaQuery.of(context).padding.top,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE94848), Color(0xFFD43C3C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      '关闭',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '红包领取详情',
                        style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onOpenReport,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Text(
                        '红包记录',
                        style: TextStyle(
                          color: Color(0xFFFFD670), fontSize: 14, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 内容
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 摘要框
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _avatarWidget(avatar, 56),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          nickname.isEmpty ? '红包' : '$nickname 的红包',
                          style: const TextStyle(fontSize: 15, color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selfMoneyNum > 0 ? '抢到 $selfMoney 元' : '未领取',
                          style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFE94848),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$gold-$nums-[$boom]',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 摘要行
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      '$nums个，${getedtime.isEmpty ? '未抢完' : '$getedtime抢完'}，共$gold元，雷点:$boom',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ),
                  const SizedBox(height: 1),
                  // 列表
                  if (list.isEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: const Text(
                        '暂无领取记录',
                        style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                      ),
                    )
                  else
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: List.generate(list.length, (i) {
                          return _buildItem(list[i], isLast: i == list.length - 1);
                        }),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, {required bool isLast}) {
    final avatar = item['avatar']?.toString() ?? '';
    final nickname = item['nickname']?.toString() ?? '';
    final money = item['money']?.toString() ?? '0';
    final time = item['addtime']?.toString() ?? '';
    final isboom = int.tryParse(item['isboom']?.toString() ?? '0') ?? 0;
    final isone = int.tryParse(item['isone']?.toString() ?? '0') ?? 0;
    final ismax = int.tryParse(item['ismax']?.toString() ?? '0') ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _avatarWidget(avatar, 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isEmpty ? '未知' : nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$money 元',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
              ),
              if (isboom == 1 && isone != 1)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '💣 中雷',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE94848)),
                  ),
                ),
              if (ismax == 1)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '👑 手气最佳',
                    style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarWidget(String url, double size) {
    if (url.isEmpty) {
      return Container(
        width: size, height: size,
        color: const Color(0xFFF0ECFF),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: const Color(0xFF5B48B8), size: size * 0.5),
      );
    }
    return Image.network(
      url,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        color: const Color(0xFFF0ECFF),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: const Color(0xFF5B48B8), size: size * 0.5),
      ),
    );
  }
}

// ====================================================================
//                    ③  我抢到的红包记录
// ====================================================================
class RedReportPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const RedReportPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final avatar = data['avatar']?.toString() ?? '';
    final nickname = data['nickname']?.toString() ?? '';
    final allmoney = data['allmoney']?.toString() ?? '0';
    final allcount = data['allcount']?.toString() ?? '0';
    final list = (data['list'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 顶部橙黄 header
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              height: 54 + MediaQuery.of(context).padding.top,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('关闭', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '抢到的红包',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _avatarWidget(avatar, 56),
                        ),
                        const SizedBox(height: 10),
                        Text(nickname, style: const TextStyle(fontSize: 15, color: Color(0xFF111111))),
                        const SizedBox(height: 8),
                        Text(
                          allmoney,
                          style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '共抢到 $allcount 个红包 (最近24小时)',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Text(
                      '记录明细',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ),
                  const SizedBox(height: 1),
                  if (list.isEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: const Text(
                        '暂无记录',
                        style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                      ),
                    )
                  else
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: List.generate(list.length, (i) {
                          final item = list[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: i == list.length - 1
                                  ? null
                                  : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['setnickname']?.toString() ?? '未知',
                                        style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111111),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['addtime']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${item['money']?.toString() ?? '0'} 元',
                                  style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE94848),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarWidget(String url, double size) {
    if (url.isEmpty) {
      return Container(
        width: size, height: size,
        color: const Color(0xFFF0ECFF),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: const Color(0xFF5B48B8), size: size * 0.5),
      );
    }
    return Image.network(
      url,
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        color: const Color(0xFFF0ECFF),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: const Color(0xFF5B48B8), size: size * 0.5),
      ),
    );
  }
}