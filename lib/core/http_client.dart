import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';

/// 全局 HTTP 客户端（单例）
class HttpClient {
  HttpClient._internal();
  static final HttpClient instance = HttpClient._internal();

  // ★ 全局路由导航 Key，用于在任意位置跳转页面
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late Dio dio;
  late PersistCookieJar cookieJar;
  bool _inited = false;

  /// App 启动时调用一次
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 JianxinApp/1.0',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));

    // Cookie 持久化到 App 私有目录
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/.cookies'),
    );
    dio.interceptors.add(CookieManager(cookieJar));

    // 日志拦截器：仅在 Debug 模式下打印
    if (kDebugMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('📤 [HTTP] ${options.method} ${options.uri}');
          debugPrint('📤 [DATA] ${options.data}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('📥 [HTTP] ${response.statusCode}');
          debugPrint('📥 [BODY] ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('❌ [HTTP] ${error.type}');
          debugPrint('❌ [MSG] ${error.message}');
          if (error.response != null) {
            debugPrint('❌ [STATUS] ${error.response?.statusCode}');
            debugPrint('❌ [BODY] ${error.response?.data}');
          }
          handler.next(error);
        },
      ));
    }

    // ★★★ 新增：拦截未登录状态 ★★★
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        _checkResponse(response);
        handler.next(response);
      },
      onError: (error, handler) {
        if (error.response != null) {
          _checkResponse(error.response!);
        }
        handler.next(error);
      },
    ));
  }

  // ★★★ 新增：检查是否未登录并强制登出 ★★★
  bool _isLoggingOut = false;

  Future<void> _checkResponse(Response response) async {
    if (_isLoggingOut) return;

    dynamic data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return;
      }
    }

    if (data is Map) {
      // 根据你的后端返回，未登录通常 status 为 0 或 -1，msg 带有"请先登录"等字样
      final status = data['status']?.toString() ?? '1';
      final msg = data['msg']?.toString() ?? data['result']?.toString() ?? '';

      if (status == '0' || status == '-1') {
        if (msg.contains('请先登录') || msg.contains('登录已过期') || msg.contains('用户不存在')) {
          _forceLogout();
        }
      }
    }
  }

  // ★★★ 新增：执行强制登出 ★★★
  Future<void> _forceLogout() async {
    _isLoggingOut = true;
    try {
      // 1. 清空本地 Cookie
      await cookieJar.deleteAll();
      // 2. 清空其他缓存（如果有的话）

      // 3. 全局跳转到登录页，并清空所有历史页面
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('强制登出出错: $e');
    } finally {
      _isLoggingOut = false;
    }
  }
}