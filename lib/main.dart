import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';   // ★ 新增
import 'core/http_client.dart';
import 'core/sound_player.dart';
import 'pages/login_page.dart';
import 'core/data_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HttpClient.instance.init();
  await SoundPlayer.instance.init();
  await DataCache.init();
  runApp(const JianxinApp());
}

class JianxinApp extends StatelessWidget {
  const JianxinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简信红包',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: false,
      ),
      // ★★★ 新增：中文本地化 ★★★
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),   // 强制中文
      // ★★★ 结束 ★★★
      home: const LoginPage(),
    );
  }
}