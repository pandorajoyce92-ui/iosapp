import 'dart:async';
import 'package:flutter/material.dart';

/// 屏幕中央提示（替代 SnackBar）
class ToastUtil {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String msg,
      {Duration duration = const Duration(milliseconds: 2000)}) {
    // 先关掉上一个（连续弹时用最新的）
    _entry?.remove();
    _entry = null;
    _timer?.cancel();

    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(   // 不挡点击
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, () {
      _entry?.remove();
      _entry = null;
    });
  }
}