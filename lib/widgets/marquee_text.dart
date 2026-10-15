import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration; // 单段滚完的时间

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(seconds: 12),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  bool _started = false;

  /// 两段文字之间的间隔
  static const double _gap = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopAutoScroll();
      _started = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
    }
  }

  void _startAutoScroll() {
    if (!mounted || _started) return;
    if (!_controller.hasClients) return;

    final maxExtent = _controller.position.maxScrollExtent;
    if (maxExtent <= 0) return; // 文字比容器短，不滚
    _started = true;

    // ★ 循环周期 = 第一段文字 + 一个间隔的宽度
    //   布局 = [Text][Gap][Text][Gap]
    //   总宽 = 2 * (Text + Gap) → 单段周期 = 总宽 / 2
    //   视口宽 = viewportDimension
    //   maxScrollExtent = 总宽 - 视口宽
    //   → 单段周期 = (maxScrollExtent + viewport) / 2
    final viewport = _controller.position.viewportDimension;
    final loopExtent = (maxExtent + viewport) / 2;

    final seconds = widget.duration.inSeconds;
    final step = loopExtent / seconds / 10; // 每 100ms 滚一次

    double offset = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || !_controller.hasClients) {
        t.cancel();
        return;
      }
      offset += step;
      if (offset >= loopExtent) {
        offset -= loopExtent; // 无缝跳回，视觉上看不出
      }
      _controller.jumpTo(offset);
    });
  }

  void _stopAutoScroll() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            // ★ 文字渲染两份
            Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
            const SizedBox(width: _gap),
            Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
            const SizedBox(width: _gap),
          ],
        ),
      ),
    );
  }
}