import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../core/config.dart';
import '../core/http_client.dart';
import '../core/toast_util.dart';

class LunpanPage extends StatefulWidget {
  final int roomid;
  const LunpanPage({super.key, required this.roomid});

  @override
  State<LunpanPage> createState() => _LunpanPageState();
}

class _LunpanPageState extends State<LunpanPage>
    with TickerProviderStateMixin {
  bool _loading = true;

  List<String> _prizes = [];
  int _remainTimes = 0;
  int _threshold = 0;

  bool _isRotating = false;
  double _currentDeg = 0;

  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;
  late AnimationController _lampCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0).animate(_ctrl);

    _lampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _loadData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _lampCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.lunpan}&roomid=${widget.roomid}',
        data: {'op': 'get_data', 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }
      if (data is Map && data['status'] == 1 && data['result'] is Map) {
        final r = Map<String, dynamic>.from(data['result']);
        final prizes = (r['prizes'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        if (mounted) {
          setState(() {
            _prizes = prizes;
            _remainTimes = int.tryParse(r['remain_times']?.toString() ?? '0') ?? 0;
            _threshold = int.tryParse(r['threshold']?.toString() ?? '0') ?? 0;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [lunpan get_data] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSpin() async {
    if (_isRotating) return;
    if (_remainTimes <= 0) {
      _toast('暂无抽奖次数，继续游戏可获得次数哦');
      return;
    }

    setState(() => _isRotating = true);

    try {
      final res = await HttpClient.instance.dio.post(
        '${ApiConfig.lunpan}&roomid=${widget.roomid}',
        data: {'op': 'havewawelfare', 'roomid': widget.roomid},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      dynamic data = res.data;
      if (data is String) {
        try { data = jsonDecode(data); } catch (_) {}
      }

      int? prizeIndex;
      if (data is Map) {
        if (data['index'] != null) {
          prizeIndex = int.tryParse(data['index'].toString());
        } else if (data['result'] != null) {
          final r = data['result'];
          if (r is num) {
            prizeIndex = r.toInt();
          } else if (r is Map && r['index'] != null) {
            prizeIndex = int.tryParse(r['index'].toString());
          }
        }
      }

      debugPrint('📦 lunpan 返回: $data, index=$prizeIndex');

      final status = data is Map ? data['status']?.toString() : null;
      if (status != null && status != '0' && prizeIndex != null &&
          _prizes.isNotEmpty && prizeIndex >= 0 && prizeIndex < _prizes.length) {
        setState(() => _remainTimes = (_remainTimes - 1).clamp(0, 9999));
        _startRotate(prizeIndex, _prizes[prizeIndex]);
      } else {
        final errMsg = data is Map
            ? (data['msg'] ?? data['result'] ?? '抽奖失败，请稍后重试').toString()
            : '抽奖失败，请稍后重试';
        _toast(errMsg);
        if (mounted) setState(() => _isRotating = false);
      }
    } catch (e) {
      debugPrint('❌ [lunpan] $e');
      _toast('网络错误，请稍后重试');
      if (mounted) setState(() => _isRotating = false);
    }
  }

  void _startRotate(int index, String prizeText) {
    final arc = 360.0 / _prizes.length;
    final targetDeg = 270.0 - (index * arc + arc / 2);

    double targetAbs = targetDeg;
    while (targetAbs < _currentDeg + 5 * 360) {
      targetAbs += 360;
    }
    final extraRounds = math.Random().nextInt(3);
    final endDeg = targetAbs + extraRounds * 360;

    _rotateAnim = Tween<double>(begin: _currentDeg, end: endDeg).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.reset();
    _ctrl.forward().then((_) {
      if (!mounted) return;
      _currentDeg = endDeg;
      setState(() => _isRotating = false);
      _toast('🎊 恭喜您获得了 $prizeText元 🎊');
    });
  }

    void _toast(String msg) {
      if (!mounted) return;
      ToastUtil.show(context, msg, duration: const Duration(milliseconds: 2500));
    }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDBEAFE), Color(0xFFDCF5E8), Color(0xFFDCFCE7)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ★ 修正：顶部栏只放返回按钮 + 标题
  Widget _buildHeader() {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 40,
              height: 44,
              child: Icon(CupertinoIcons.back, color: Colors.black, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '幸运抽奖',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimesBoard(),
          const SizedBox(height: 12),
          _buildWheelCard(),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 0, 6),
            child: Text(
              '活动规则',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500),
            ),
          ),
          _buildRules(),
        ],
      ),
    );
  }

  Widget _buildTimesBoard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A55C9), Color(0xFF5B48B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B48B8).withOpacity(0.25),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '剩余抽奖机会',
            style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            '$_remainTimes',
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFFFDA66),
              shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '次',
            style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 转盘
                AnimatedBuilder(
                  animation: _rotateAnim,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _rotateAnim.value * math.pi / 180,
                      child: CustomPaint(
                        size: const Size.square(516),
                        painter: _WheelPainter(
                          prizes: _prizes,
                          lampAnim: _lampCtrl,
                        ),
                      ),
                    );
                  },
                ),
                // 中心指针（点击抽奖）★ 去掉 const
                GestureDetector(
                  onTap: _isRotating ? null : _onSpin,
                  child: AnimatedScale(
                    scale: _isRotating ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _PointerPainter(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRules() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ruleLine([
            const TextSpan(text: '1. 发包或者抢包流水达到 '),
            TextSpan(
              text: '$_threshold',
              style: const TextStyle(color: Color(0xFF5B48B8), fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' 元就可以抽取一次。'),
          ]),
          const SizedBox(height: 8),
          _ruleLine(const [TextSpan(text: '2. 每获取一次机会，即可拨动一次大转盘参与抽奖。')]),
          const SizedBox(height: 8),
          _ruleLine(const [TextSpan(text: '3. 所中金额会自动发放到账户，请至【余额明细】查询，如有疑问请联系客服。')]),
        ],
      ),
    );
  }

  Widget _ruleLine(List<TextSpan> spans) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.6),
        children: spans,
      ),
    );
  }
}

// ==================== 转盘绘制 ====================
class _WheelPainter extends CustomPainter {
  final List<String> prizes;
  final Animation<double> lampAnim;

  _WheelPainter({required this.prizes, required this.lampAnim})
      : super(repaint: lampAnim);

  @override
  void paint(Canvas canvas, Size size) {
    if (prizes.isEmpty) return;

    const baseSize = 516.0;
    final scale = size.width / baseSize;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    const outerRingR = 254.0;
    const innerRingR = 222.0;
    const textR = 165.0;
    const insideR = 65.0;

    final count = prizes.length;
    final arc = 2 * math.pi / count;

    // ---- 1. 金色外环 ----
    final goldRect = Rect.fromCircle(center: center, radius: outerRingR * scale);
    final ringPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRingR * scale))
      ..addOval(Rect.fromCircle(center: center, radius: innerRingR * scale))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      ringPath,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF1B0),
            Color(0xFFE0B64A),
            Color(0xFFFFF1B0),
            Color(0xFFE0B64A),
            Color(0xFFFFF1B0),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(goldRect),
    );

            // ---- 2. 灯珠（高亮饱和 + 白光心 + 强光晕）----
            const lampCount = 21;   // ★ 21 颗，正好彩虹 3 轮
            final lampR = (outerRingR + innerRingR) / 2;
            final t = lampAnim.value;

            // ★ 高亮彩虹色池（纯饱和，不发灰）
            const rainbow = [
              Color(0xFFFF1744), // 亮红
              Color(0xFFFF9100), // 亮橙
              Color(0xFFFFEA00), // 亮黄
              Color(0xFF00E676), // 亮绿
              Color(0xFF00E5FF), // 亮青
              Color(0xFF2979FF), // 亮蓝
              Color(0xFFD500F9), // 亮紫
            ];

            for (int i = 0; i < lampCount; i++) {
              final a = (i / lampCount) * 2 * math.pi - math.pi / 2;
              final p = Offset(
                cx + math.cos(a) * lampR * scale,
                cy + math.sin(a) * lampR * scale,
              );

              final baseColor = rainbow[i % rainbow.length];

              // 跑马灯相位
              final phase = i / lampCount;
              final wave = (math.sin((t + phase) * 2 * math.pi) + 1) / 2; // 0~1
              final brightness = 0.55 + wave * 0.45; // 0.55~1.0（保持高亮）

              // ---- (1) 强光晕：大、亮、模糊 ----
              canvas.drawCircle(
                p,
                (9.0 + wave * 3.0) * scale,
                Paint()
                  ..color = baseColor.withOpacity(0.35 + wave * 0.45)
                  ..maskFilter = MaskFilter.blur(
                    BlurStyle.normal,
                    (2.0 + wave * 2.0) * scale,
                  ),
              );

              // ---- (2) 灯泡彩色圆（实心，纯色，不混白）----
              canvas.drawCircle(
                p,
                6.0 * scale,
                Paint()..color = baseColor,
              );

              // ---- (3) 内嵌白色高光心（做"灯泡"的高亮感）----
              canvas.drawCircle(
                p,
                (6.0 * scale) * 0.48 * (0.8 + brightness * 0.35),
                Paint()..color = Colors.white.withOpacity(0.75 + wave * 0.25),
              );

              // ---- (4) 灯珠暗色描边（勾边更清晰）----
              canvas.drawCircle(
                p,
                6.0 * scale,
                Paint()
                  ..color = Color.lerp(baseColor, Colors.black, 0.45)!
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.0 * scale,
              );
            }

    // ---- 3. 扇形 ----
    final dividerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFE0C070)
      ..strokeWidth = 1.2 * scale;

    for (int i = 0; i < count; i++) {
      final a0 = i * arc;
      final a1 = a0 + arc;

      final path = Path()
        ..moveTo(
          cx + math.cos(a0) * innerRingR * scale,
          cy + math.sin(a0) * innerRingR * scale,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRingR * scale),
          a0,
          arc,
          false,
        )
        ..lineTo(
          cx + math.cos(a1) * insideR * scale,
          cy + math.sin(a1) * insideR * scale,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: insideR * scale),
          a1,
          -arc,
          false,
        )
        ..close();

      final isEven = i % 2 == 0;
      canvas.drawPath(
        path,
        Paint()..color = isEven ? const Color(0xFFF4F1FF) : Colors.white,
      );
      canvas.drawPath(path, dividerPaint);

      final midAngle = a0 + arc / 2;
      final tx = cx + math.cos(midAngle) * textR * scale;
      final ty = cy + math.sin(midAngle) * textR * scale;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(midAngle + math.pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: '${prizes[i]}元',
          style: TextStyle(
            fontSize: 26 * scale,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF5B48B8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, 45 * scale));
      canvas.restore();
    }

    // ---- 4. 内圈金描边 ----
    canvas.drawCircle(
      center,
      insideR * scale,
      Paint()
        ..color = const Color(0xFFE0C070)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // ---- 5. 扇区与金环交界白线 ----
    canvas.drawCircle(
      center,
      innerRingR * scale,
      Paint()
        ..color = const Color(0xFFFFF8E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.prizes != prizes;
  }
}

// ==================== 中心指针 ====================
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;               // ★ 按钮回到组件正中央

    final buttonR = w * 0.36;        // 按钮半径

    // ★ 指针：短小三角，只从按钮顶部伸出 7px
    final pointerTipY = cy - buttonR - 7;     // 尖端
    final pointerBaseY = cy - buttonR + 6;    // 底边（伸进按钮内部）
    final pointerHalfW = w * 0.10;            // 半宽约 11px

    // ---- 1. 指针阴影 ----
    final pointerPath = Path()
      ..moveTo(cx, pointerTipY)
      ..lineTo(cx - pointerHalfW, pointerBaseY)
      ..lineTo(cx + pointerHalfW, pointerBaseY)
      ..close();

    canvas.drawPath(
      pointerPath.shift(const Offset(0, 1.5)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // ---- 2. 指针主体（金→红渐变）----
    canvas.drawPath(
      pointerPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFE94848)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(
          cx - pointerHalfW, pointerTipY,
          cx + pointerHalfW, pointerBaseY,
        )),
    );
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = const Color(0xFFB98B2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ---- 3. 按钮阴影 ----
    canvas.drawCircle(
      Offset(cx, cy + 3),
      buttonR - 2,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ---- 4. 按钮白底 ----
    canvas.drawCircle(Offset(cx, cy), buttonR, Paint()..color = Colors.white);

    // ---- 5. 金色外环 ----
    final goldR = buttonR - 3;
    final goldRect = Rect.fromCircle(center: Offset(cx, cy), radius: goldR);
    canvas.drawCircle(
      Offset(cx, cy),
      goldR,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF1B0),
            Color(0xFFE0B64A),
            Color(0xFFFFF1B0),
            Color(0xFFE0B64A),
            Color(0xFFFFF1B0),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(goldRect),
    );

    // ---- 6. 内层橙红按钮 ----
    final btnR = buttonR - 10;
    canvas.drawCircle(
      Offset(cx, cy),
      btnR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFF8C42),
            Color(0xFFE94848),
          ],
          stops: [0.0, 0.55, 1.0],
          center: Alignment(-0.2, -0.35),
          radius: 1.0,
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: btnR),
        ),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      btnR,
      Paint()
        ..color = const Color(0xFFB98B2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ---- 7. "抽奖"文字 ----
    final tp = TextPainter(
      text: const TextSpan(
        text: '抽奖',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: 1.0,
          shadows: [
            Shadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 1.5)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}