import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'core/http_client.dart';
import 'core/config.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当 APP 从后台切回前台
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 APP 唤醒，开始探活...');
      _checkSessionValid();
    }
  }

  Future<void> _checkSessionValid() async {
    try {
      // ★★★ 探活原理：向服务器发一个需要登录的请求 ★★★
      // 这里使用你微擎的通用入口（如果 entryUrl 是 /app/index.php）
      // 如果你找不到通用的，直接用红包的余额接口，或者六合彩的接口都可以。
      // 因为只要 Cookie 失效，后端一定会返回“请先登录”，从而触发 http_client 的拦截器。
      
      // 尝试请求通用的用户中心接口，或者退而求其次请求红包接口
      final String url = '${ApiConfig.redpackets}&op=getmymoney&roomid=1';
      
      await HttpClient.instance.dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          // 加上超时，防止一直卡在这里
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      debugPrint('✅ 探活请求完成，登录态有效');
    } catch (e) {
      // 如果是断网了，或者请求超时，这里会报错，什么都不做即可。
      // 如果是登录失效，http_client.dart 里的拦截器会自动帮你跳转到 LoginPage()
      debugPrint('探活网络异常: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}