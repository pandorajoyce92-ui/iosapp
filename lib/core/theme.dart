import 'package:flutter/material.dart';

/// 全局颜色（严格按 header.html 的 CSS 变量）
class AppColors {
  static const purple       = Color(0xFF7C5CFC);
  static const purpleLight  = Color(0xFFF0ECFF);
  static const purpleMid    = Color(0xFFC9BEFF);
  static const purpleDark   = Color(0xFF5B48B8);
  static const primary      = Color(0xFF6A55C9);

  static const bg           = Color(0xFFF5F5F7);
  static const bgCard       = Color(0xFFFFFFFF);
  static const border       = Color(0xFFF0F0F4);

  static const textPrimary   = Color(0xFF111111);
  static const textSecondary = Color(0xFF555555);
  static const textHint      = Color(0xFF999999);

  static const redStart = Color(0xFFFF7A38);
  static const redEnd   = Color(0xFFE94848);
}

/// 圆角尺寸
class AppRadius {
  static const double lg = 18;
  static const double md = 14;
  static const double sm = 8;
}