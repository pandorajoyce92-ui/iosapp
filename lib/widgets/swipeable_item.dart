import 'package:flutter/material.dart';

/// 左滑显示"隐藏"按钮
class SwipeableItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onHide;
  final VoidCallback? onTap;
  final double actionWidth;

  const SwipeableItem({
    super.key,
    required this.child,
    required this.onHide,
    this.onTap,
    this.actionWidth = 80,
  });

  @override
  State<SwipeableItem> createState() => _SwipeableItemState();
}

class _SwipeableItemState extends State<SwipeableItem> {
  double _offset = 0;
  double _startX = 0;
  double _startOffset = 0;

  void _onHorizontalDragStart(DragStartDetails d) {
    _startX = d.globalPosition.dx;
    _startOffset = _offset;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    final dx = d.globalPosition.dx - _startX;
    double next = _startOffset + dx;
    if (next > 0) next = 0;
    if (next < -widget.actionWidth) next = -widget.actionWidth;
    setState(() => _offset = next);
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_offset < -widget.actionWidth / 2) {
      setState(() => _offset = -widget.actionWidth);
    } else {
      setState(() => _offset = 0);
    }
  }

  void close() {
    setState(() => _offset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final opened = _offset != 0;
    // ★ 红块透明度 = 滑动进度，不滑时完全透明
    final progress = (-_offset / widget.actionWidth).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        if (opened) {
          close();
        } else {
          widget.onTap?.call();
        }
      },
      child: Stack(
        children: [
          // 底层：隐藏按钮（跟随滑动显示/隐藏）
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: widget.actionWidth,
            child: IgnorePointer(
              ignoring: progress == 0,
              child: Opacity(
                opacity: progress,
                child: GestureDetector(
                  onTap: widget.onHide,
                  child: Container(
                    color: const Color(0xFFE94848),
                    alignment: Alignment.center,
                    child: const Text(
                      '隐藏',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 上层：内容
          Transform.translate(
            offset: Offset(_offset, 0),
            child: GestureDetector(
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}