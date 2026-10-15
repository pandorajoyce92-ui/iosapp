import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局数据缓存：内存 + shared_preferences 双写
class DataCache {
  static final Map<String, dynamic> _mem = {};
  static final Map<String, DateTime> _time = {};
  static SharedPreferences? _prefs;

  /// 在 main() 里调用一次
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 读缓存（同步，秒返回）
  static dynamic get(String key) {
    // 内存优先
    if (_mem.containsKey(key)) return _mem[key];

    // 磁盘兜底
    final raw = _prefs?.getString('cache_$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      _mem[key] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// 写缓存（异步磁盘，内存立即）
  static Future<void> set(String key, dynamic value) async {
    _mem[key] = value;
    _time[key] = DateTime.now();
    if (_prefs != null) {
      try {
        await _prefs!.setString('cache_$key', jsonEncode(value));
      } catch (_) {}
    }
  }

  /// 缓存写入时间
  static DateTime? getTime(String key) => _time[key];

  /// 是否在 TTL 内
  static bool isFresh(String key, Duration ttl) {
    final t = _time[key];
    if (t == null) return false;
    return DateTime.now().difference(t) < ttl;
  }

  /// 删指定 key
  static Future<void> remove(String key) async {
    _mem.remove(key);
    _time.remove(key);
    await _prefs?.remove('cache_$key');
  }

  /// 全清
  static Future<void> clear() async {
    _mem.clear();
    _time.clear();
    await _prefs?.clear();
  }
}