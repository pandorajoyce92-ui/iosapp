import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_cache_manager.dart'; // ★ 引入全局缓存
import 'package:flutter/cupertino.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/http_client.dart';
import '../models/user_info.dart';
import 'install_page.dart';
import 'gonggao_page.dart';
import 'recharge_page.dart';
import 'personaldata_page.dart';
import 'withdrawal_page.dart';
import 'redlog_page.dart';
import 'webview_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  UserInfo? _user;
  bool _loading = true;

  static const LinearGradient _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color _cardBg = Color(0x26FFFFFF);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final res = await HttpClient.instance.dio.get(
        '${ApiConfig.mine}&op=get_user_info',
        options: Options(responseType: ResponseType.plain),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final user = UserInfo.fromJson(Map<String, dynamic>.from(data['result']));
        if (mounted) {
          setState(() {
            _user = user;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [mine get_user_info] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

    void _openWeb(String url, String title) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => WebViewPage(url: url, title: title)), // ★ 修正为 WebViewPage
      );
    }

    void _goPersonalData() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const PersonalDataPage()),
      ).then((changed) {
        if (changed == true) _loadUser();
      });
    }

    void _goWithdrawal() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const WithdrawalPage()),
      );
    }

    void _goRedlog() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const RedlogPage()), // ★ 修正为 RedlogPage
      );
    }

    void _goRecharge() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const RechargePage()), // ★ 修正为 RechargePage
      );
    }

    void _goGonggao() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const GonggaoPage()), // ★ 修正为 GonggaoPage
      );
    }

    void _goInstall() {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const InstallPage()), // ★ 修正为 InstallPage
      );
    }

  void _goDownload() => _openWeb(ApiConfig.downloadPage, '系统更新');

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView( // ★ 直接展示页面，不要判断 _loading
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 SizedBox(height: MediaQuery.of(context).padding.top + 12),
                 _buildProfileCard(), // 这里面会做骨架屏处理
                 const SizedBox(height: 12),
                      // ★ 暂时下线：账户余额 / 提现 / 余额明细（需要时取消注释即可）
                      // _buildGroup([
                      //   _Row(
                      //     icon: Icons.account_balance_wallet_outlined,
                      //     iconColor: const Color(0xFF007AFF),
                      //     label: '账户余额',
                      //     trailing: _user?.goldmoney.isNotEmpty == true
                      //         ? _user!.goldmoney
                      //         : '0.00',
                      //     onTap: _goRecharge,
                      //   ),
                      //   _Row(
                      //     icon: Icons.arrow_circle_up_outlined,
                      //     iconColor: const Color(0xFF07C160),
                      //     label: '提现',
                      //     onTap: _goWithdrawal,
                      //   ),
                      //   _Row(
                      //     icon: Icons.receipt_long_outlined,
                      //     iconColor: const Color(0xFFFF9500),
                      //     label: '余额明细',
                      //     onTap: _goRedlog,
                      //     isLast: true,
                      //   ),
                      // ]),
                      // const SizedBox(height: 12),
                      _buildGroup([
                        _Row(
                          icon: Icons.notifications_none,
                          iconColor: const Color(0xFFFFCC00),
                          label: '消息中心',
                          onTap: _goGonggao,
                        ),
                        _Row(
                          icon: Icons.system_update_alt,
                          iconColor: const Color(0xFF5AC8FA),
                          label: '系统更新',
                          onTap: _goDownload,
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _buildGroup([
                        _Row(
                          icon: Icons.settings_outlined,
                          iconColor: const Color(0xFF8E8E93),
                          label: '设置',
                          onTap: _goInstall,
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // =================== 顶部用户信息卡 ===================
  Widget _buildProfileCard() {
    final user = _user;
    final avatar = user?.avatarUrl ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _goPersonalData,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
                        // 头像
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: avatar.isEmpty
                                          ? Container(
                                              width: 64, height: 64,
                                              color: const Color(0xFFF0ECFF),
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.person, size: 32, color: AppColors.purple),
                                            )
                                          : Image(
                                              // ★ 1. 使用 Provider 代替组件，直接请求底层缓存
                                              image: CachedNetworkImageProvider(
                                                avatar,
                                                cacheManager: AppCacheManager.instance, // 使用持久化缓存
                                              ),
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,

                                              // ★ 2. 终极防闪烁：帧构建器
                                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                                // 如果是同步从本地加载出来的，直接返回 child，连一帧都不等
                                                if (wasSynchronouslyLoaded) return child;
                                                // 如果是网络下载的，直接返回 child，不做渐入动画
                                                return child;
                                              },

                                              // ★ 3. 加载中显示占位图（只有真正没缓存、在下载时才会显示）
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  width: 64, height: 64,
                                                  color: const Color(0xFFF0ECFF),
                                                  alignment: Alignment.center,
                                                  child: const Icon(Icons.person, size: 32, color: AppColors.purple),
                                                );
                                              },

                                              // ★ 4. 错误兜底
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 64, height: 64,
                                                  color: const Color(0xFFF0ECFF),
                                                  alignment: Alignment.center,
                                                  child: const Icon(Icons.person, size: 32, color: AppColors.purple),
                                                );
                                              },
                                            ),
                                    ),
            const SizedBox(width: 14),
            // 昵称 + 推广号
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (user?.nickname.isNotEmpty == true) ? user!.nickname : '简信用户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600,
                      color: Color(0xFF111111), height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '推广号：${user?.id ?? 0}',
                    style: const TextStyle(
                      fontSize: 13, color: Color(0xFF999999), height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            // 二维码图标
            GestureDetector(
              onTap: () {
                // 直接跳个人资料页（那里有二维码名片）
                _goPersonalData();
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.qr_code, size: 22, color: Color(0xFF333333)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================== 分组列表 ===================
  Widget _buildGroup(List<_Row> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          return _buildRow(row, isLast: i == rows.length - 1);
        }),
      ),
    );
  }

  Widget _buildRow(_Row row, {required bool isLast}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
          ),
          child: Row(
            children: [
              Icon(row.icon, size: 22, color: row.iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  row.label,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w400,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              if (row.trailing != null && row.trailing!.isNotEmpty)
                Text(
                  row.trailing!,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF999999)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final bool isLast;

  _Row({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    required this.onTap,
    this.isLast = false,
  });
}