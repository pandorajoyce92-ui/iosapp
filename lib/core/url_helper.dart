import 'config.dart';

/// 统一处理头像/图片 URL
/// 兼容以下后端返回格式：
///   - https://xxx.png 或 http://xxx.png（完整 URL）
///   - /attachment/xxx、/static/xxx、/addons/xxx（服务器绝对路径）
///   - ../addons/sz_yi/...（模板相对路径）
///   - attachment/xxx.png（带 attachment 前缀）
///   - images/1/2026/06/xxx.png（不带 attachment 前缀的附件）
///   - xxx.png（纯文件名）
String fullUrl(String raw) {
  final a = raw.trim();
  if (a.isEmpty) return '';

  // 1. 完整 URL
  if (a.startsWith('http://')) return a.replaceFirst('http://', 'https://');
  if (a.startsWith('https://')) return a;

  // 2. 服务器绝对路径
  if (a.startsWith('/')) return '${ApiConfig.baseUrl}$a';

  // 3. ../xxx 模板相对路径
  if (a.startsWith('../')) {
    return '${ApiConfig.baseUrl}/${a.substring(3)}';
  }

  // 4. 已经带 attachment/ 前缀 → 不重复加
  if (a.startsWith('attachment/')) {
    return '${ApiConfig.baseUrl}/$a';
  }

  // 5. images/... 或纯文件名 → 补 /attachment/
  return '${ApiConfig.baseUrl}/attachment/$a';
}