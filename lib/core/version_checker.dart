import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionChecker {
  // 替换为你自己的域名
  static const String _checkApiUrl = 'https://jianxinchat.top/check_version.php';

  static Future<void> check(BuildContext context) async {
    try {
      // 1. 获取当前本机版本号
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // 例如 "1.0.0"

      // 2. 区分 iOS 和 Android
      String platform = Platform.isIOS ? 'ios' : 'android';

      // 3. 请求服务器
      final dio = Dio();
      final response = await dio.get(
        _checkApiUrl,
        queryParameters: {'platform': platform},
        options: Options(responseType: ResponseType.plain),
      );

      dynamic data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map && data['status'] == 1) {
        String latestVersion = data['result']['latest_version'];
        String updateDesc = data['result']['update_desc'];
        bool forceUpdate = data['result']['force_update'] == true;
        String downloadUrl = data['result']['download_url'];

        // 4. 比对版本号
        if (_isNewVersion(latestVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(
                context, latestVersion, updateDesc, forceUpdate, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [版本检查异常] $e');
    }
  }

  // 比较版本号：如果服务器的大于本地的，返回 true
  static bool _isNewVersion(String serverVersion, String localVersion) {
    if (serverVersion == localVersion) return false;
    List<String> serverParts = serverVersion.split('.');
    List<String> localParts = localVersion.split('.');
    int maxLength = serverParts.length > localParts.length
        ? serverParts.length
        : localParts.length;

    for (int i = 0; i < maxLength; i++) {
      int s = i < serverParts.length ? int.tryParse(serverParts[i]) ?? 0 : 0;
      int l = i < localParts.length ? int.tryParse(localParts[i]) ?? 0 : 0;
      if (s > l) return true;
      if (s < l) return false;
    }
    return false;
  }

  // 显示更新弹窗（自定义样式，完全贴合 App 风格）
  static void _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String updateDesc,
    bool forceUpdate,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate, // 强制更新时，点击背景无法关闭
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return PopScope(
          canPop: !forceUpdate, // 强制更新时，拦截物理返回键
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 顶部标题栏
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.system_update_rounded,
                          color: Color(0xFF007AFF),
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '发现新版本',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$latestVersion',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. 更新内容区（带滚动，防止内容太长撑爆）
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1, color: Color(0xFFF0F0F4)),
                          const SizedBox(height: 16),
                          const Text(
                            '更新内容：',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            updateDesc,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // 3. 底部按钮区
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Row(
                      children: [
                        // 暂不更新（非强制更新时才显示）
                        if (!forceUpdate) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '暂不更新',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // 立即更新
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(downloadUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } else {
                                debugPrint('无法打开链接: $downloadUrl');
                              }
                              if (!forceUpdate && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF007AFF),
                                    Color(0xFF0060DF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF007AFF)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '立即更新',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}