import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/http_client.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final bool hideAppBar;

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
    this.hideAppBar = false,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (error) {
          debugPrint('❌ WebView 错误: ${error.description} | code=${error.errorCode}');
        },
        // ★★★ 关键：拦截所有导航请求 ★★★
        onNavigationRequest: (request) {
          final url = request.url;
          // 把 http 强制改成 https
          if (url.startsWith('http://jianxinchat.top')) {
            final httpsUrl = url.replaceFirst('http://', 'https://');
            debugPrint('🔒 拦截 http 跳转 → $httpsUrl');
            _controller.loadRequest(
              Uri.parse(httpsUrl),
              headers: {'Cookie': _lastCookieHeader},
            );
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _setupAndLoad();
  }

  String _lastCookieHeader = '';

  Future<void> _setupAndLoad() async {
    Map<String, String> headers = {};
    try {
      await _controller.clearCache();
      await _controller.clearLocalStorage();
      debugPrint('🧹 已清空 WebView 缓存');

      final uri = Uri.parse(
          'https://jianxinchat.top/app/index.php?i=1&c=entry&do=member&m=sz_yi&p=game');
      final cookies = await HttpClient.instance.cookieJar.loadForRequest(uri);
      debugPrint('🍪 准备写入 ${cookies.length} 个 Cookie');

      final cookieManager = WebViewCookieManager();
      for (final c in cookies) {
        debugPrint('🍪 写入: ${c.name}=${c.value}');
        try {
          await cookieManager.setCookie(WebViewCookie(
            name: c.name,
            value: c.value,
            domain: 'jianxinchat.top',
            path: '/',
          ));
        } catch (e) {
          debugPrint('🍪 写入失败 ${c.name}: $e');
        }
      }

      if (cookies.isNotEmpty) {
        _lastCookieHeader =
            cookies.map((c) => '${c.name}=${c.value}').join('; ');
        headers['Cookie'] = _lastCookieHeader;
      }
    } catch (e) {
      debugPrint('🍪 准备异常: $e');
    }

    String targetUrl = widget.url;
    if (targetUrl.startsWith('http://')) {
      targetUrl = targetUrl.replaceFirst('http://', 'https://');
      debugPrint('🔒 初始 URL 改为 https: $targetUrl');
    }

    debugPrint('🌐 加载 URL: $targetUrl');
    await _controller.loadRequest(Uri.parse(targetUrl), headers: headers);
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );

    if (widget.hideAppBar) {
      return Scaffold(body: SafeArea(child: body));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF6A55C9),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}