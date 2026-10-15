import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart';
import 'address_book_page.dart';
import 'service_page.dart';
import 'mine_page.dart';
import '../core/toast_util.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _index = 0;
  final Set<int> _visited = {0};

  DateTime? _lastExitWarning;
  Offset? _dragStartLocal;

  static const Color _activeColor = Color(0xFF007AFF);
  static const Color _inactiveColor = Color(0xFF8A8A8A);

  void _handleBack(String from) {
    debugPrint('🔙 _handleBack 被调用 from=$from, _index=$_index, last=$_lastExitWarning');

    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }

    final now = DateTime.now();
    if (_lastExitWarning != null &&
        now.difference(_lastExitWarning!).inSeconds <= 2) {
      debugPrint('🚪 SystemNavigator.pop()');
      SystemNavigator.pop();
      return;
    }

    _lastExitWarning = now;
    ToastUtil.show(context, '再滑动一次退出简信！');
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartLocal = details.localPosition;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0;
    final startY = _dragStartLocal?.dy ?? 0;
    _dragStartLocal = null;

    debugPrint('👉 onHorizontalDragEnd vx=$vx, startY=$startY');

    if (vx <= 300) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final bool inAllowedArea =
        _index == 0 || startY > screenHeight * 2 / 3;

    if (inAllowedArea) {
      _handleBack('horizontalDrag');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ★ 返回 false 表示"我自己处理，不让系统 pop"
      onWillPop: () async {
        _handleBack('willPop');
        return false;
      },
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: IndexedStack(
            index: _index,
            children: [
              const GamePage(),
              _visited.contains(1) ? const AddressBookPage() : const SizedBox(),
              _visited.contains(2) ? const ServicePage() : const SizedBox(),
              _visited.contains(3) ? const MinePage() : const SizedBox(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  _tabItem(0, CupertinoIcons.chat_bubble,
                      CupertinoIcons.chat_bubble_fill, '聊天'),
                  _tabItem(1, CupertinoIcons.person_2,
                      CupertinoIcons.person_2_fill, '通讯录'),
                  _tabItem(2, CupertinoIcons.compass,
                      CupertinoIcons.compass_fill, '客服'),
                  _tabItem(3, CupertinoIcons.person,
                      CupertinoIcons.person_fill, '我的'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _index == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _index = index;
            _visited.add(index);
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? _activeColor : _inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? _activeColor : _inactiveColor,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}