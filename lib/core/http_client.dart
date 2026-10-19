import 'dart:convert';
import 'dart:io';
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
        'X-App-Client': 'JianxinApp', // App专属标识，用于后端拦截H5
      },
    ));

    // Cookie 持久化到 App 私有目录
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/.cookies'),
    );
    dio.interceptors.add(CookieManager(cookieJar));

    // ★★★ 核心新增：iOS 首次网络授权自动重试拦截器 ★★★
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        // 判断是否是首次安装时，iOS 网络权限弹窗未出现导致的连接错误
        bool isNetworkPermissionError = (error.error is SocketException) ||
                                        (error.type == DioExceptionType.connectionError) ||
                                        (error.type == DioExceptionType.connectionTimeout) ||
                                        (error.type == DioExceptionType.unknown);

        // 检查是否已经重试过（防止死循环）
        bool hasRetried = error.requestOptions.extra['has_retried'] == true;

        if (isNetworkPermissionError && !hasRetried) {
          debugPrint('⚠️ 捕获到首次网络请求异常，可能是 iOS 权限拦截，等待 1.5 秒后自动重试...');

          // 等待 1.5 秒，给用户时间点击“允许网络”弹窗
          await Future.delayed(const Duration(milliseconds: 1500));

          try {
            // 标记为已重试
            error.requestOptions.extra['has_retried'] = true;

            // 使用相同的配置重新发起请求
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response); // 重试成功，返回正确数据
          } catch (e) {
            // 如果重试还失败，就走原来的报错逻辑
            return handler.next(error);
          }
        }

        // 其他错误正常抛出
        return handler.next(error);
      },
    ));
    // ★★★ 新增结束 ★★★

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

    // 拦截未登录状态
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

  // 检查是否未登录并强制登出
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
      final status = data['status']?.toString() ?? '1';
      final msg = data['msg']?.toString() ?? data['result']?.toString() ?? '';

      if (status == '0' || status == '-1') {
        if (msg.contains('请先登录') || msg.contains('登录已过期') || msg.contains('用户不存在')) {
          _forceLogout();
        }
      }
    }
  }

  // 执行强制登出
  Future<void> _forceLogout() async {
    _isLoggingOut = true;
    try {
      await cookieJar.deleteAll();
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