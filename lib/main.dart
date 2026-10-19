import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/http_client.dart';
import 'core/sound_player.dart';
import 'pages/login_page.dart';
import 'core/data_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    HttpClient.instance.init(),
    SoundPlayer.instance.init(),
    DataCache.init(),
  ]);

  runApp(const JianxinApp());
}

class JianxinApp extends StatelessWidget {
  const JianxinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ★★★ 挂载全局 Key ★★★
      navigatorKey: HttpClient.instance.navigatorKey,
      title: '简信红包',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: false,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      home: const LoginPage(),
    );
  }
}