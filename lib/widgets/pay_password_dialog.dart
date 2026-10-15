import 'package:flutter/material.dart';

class PayPasswordDialog extends StatefulWidget {
  final double amount;
  const PayPasswordDialog({super.key, required this.amount});

  @override
  State<PayPasswordDialog> createState() => _PayPasswordDialogState();
}

class _PayPasswordDialogState extends State<PayPasswordDialog> {
  final List<String> _digits = ['', '', '', '', '', ''];
  int _cursor = 0;

  void _input(String d) {
    if (_cursor >= 6) return;
    setState(() {
      _digits[_cursor] = d;
      _cursor++;
    });
    if (_cursor == 6) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).pop(_digits.join());
      });
    }
  }

  void _delete() {
    if (_cursor <= 0) return;
    setState(() {
      _cursor--;
      _digits[_cursor] = '';
    });
  }

  void _clear() {
    setState(() {
      for (int i = 0; i < 6; i++) _digits[i] = '';
      _cursor = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 54,
            child: Stack(
              children: [
                Positioned(
                  left: 16, top: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Center(
                      child: Text(
                        '×',
                        style: TextStyle(fontSize: 24, color: Color(0xFF888888), height: 1),
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    '输入支付密码',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 20),
          const Text('简信红包', style: TextStyle(fontSize: 14, color: Color(0xFF111111))),
          const SizedBox(height: 8),
          Text(
            '￥${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFE94848)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _cursor;
              return Container(
                width: 44, height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFD),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                alignment: Alignment.center,
                child: filled
                    ? Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFF111111),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            }),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              _kbRow(['1', '2', '3']),
              _kbDivider(),
              _kbRow(['4', '5', '6']),
              _kbDivider(),
              _kbRow(['7', '8', '9']),
              _kbDivider(),
              _kbRow(['clear', '0', 'del']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kbDivider() => Container(height: 1, color: const Color(0xFFEEEEEE));

  Widget _kbRow(List<String> keys) =>
      Row(children: keys.map((k) => Expanded(child: _kbKey(k))).toList());

  Widget _kbKey(String key) {
    String label = key;
    bool grey = false;
    VoidCallback onTap;

    if (key == 'clear') {
      label = '清空';
      grey = true;
      onTap = _clear;
    } else if (key == 'del') {
      label = '删除';
      grey = true;
      onTap = _delete;
    } else {
      onTap = () => _input(key);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        color: grey ? const Color(0xFFF5F5F7) : Colors.white,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: grey ? 16 : 24,
            fontWeight: grey ? FontWeight.w400 : FontWeight.w500,
            color: grey ? const Color(0xFF666666) : const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}