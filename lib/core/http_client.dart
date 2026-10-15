import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// 全局 HTTP 客户端（单例）
class HttpClient {
  HttpClient._internal();
  static final HttpClient instance = HttpClient._internal();

  late Dio dio;
  late PersistCookieJar cookieJar;
  bool _inited = false;

  /// App 启动时调用一次
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 JianxinApp/1.0',
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

    // ===== 日志拦截器 =====
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
}