import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 농장 연못에서 헤엄치는 물고기(잉어) 세 마리. 연못 물 위에 코드로 그려서 확대해도 선명하다.
/// [active]가 false이면(농장 탭이 아닐 때) 움직임을 멈춰서 배터리와 메모리를 아낀다.
class PondFish extends StatefulWidget {
  const PondFish({super.key, required this.active});
  final bool active;

  @override
  State<PondFish> createState() => _PondFishState();
}

class _PondFishState extends State<PondFish> with SingleTickerProviderStateMixin {
  /// 한 바퀴를 도는 시간 (천천히 여유롭게)
  static const lap = Duration(seconds: 24);

  late final AnimationController _c = AnimationController(vsync: this, duration: lap);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(PondFish old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: PondFishPainter(_c.value), size: Size.infinite),
        ),
      );
}

/// 물고기 그림. [t]는 0~1 (한 바퀴). 물고기마다 도는 방향·속도·꼬리 흔들림이 다르다.
class PondFishPainter extends CustomPainter {
  const PondFishPainter(this.t);
  final double t;

  // (바퀴 수, 시작 위치 0~1, 몸 크기 배율, 몸 색)
  static const _fish = [
    (1, 0.00, 1.00, Color(0xFFFF8A2B)),
    (-1, 0.40, 0.85, Color(0xFFFFB347)),
    (2, 0.70, 0.70, Color(0xFFFF6B3D)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width * .5, size.height * .52);
    final rx = size.width * .34, ry = size.height * .27;
    final len = size.width * .15;

    for (var i = 0; i < _fish.length; i++) {
      final f = _fish[i];
      final a = (t * f.$1 + f.$2) * math.pi * 2;
      final dir = f.$1 < 0 ? -1.0 : 1.0;
      // 타원 위의 위치와 진행 방향
      final pos = c + Offset(rx * math.cos(a), ry * math.sin(a));
      final heading = math.atan2(dir * ry * math.cos(a), dir * -rx * math.sin(a));
      final wag = math.sin(t * math.pi * 2 * 14 + i * 2);
      _drawFish(canvas, pos, heading, len * f.$3, wag, f.$4);
    }
  }

  void _drawFish(Canvas canvas, Offset pos, double heading, double len, double wag, Color body) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    // 물 속 그림자
    canvas.drawOval(Rect.fromCenter(center: Offset(len * .05, len * .32), width: len * .95, height: len * .34), Paint()..color = const Color(0x22003A66));
    // 꼬리
    final tail = Path()
      ..moveTo(-len * .38, 0)
      ..lineTo(-len * .82, -len * .3 + wag * len * .12)
      ..lineTo(-len * .72, wag * len * .12)
      ..lineTo(-len * .82, len * .3 + wag * len * .12)
      ..close();
    canvas.drawPath(tail, Paint()..color = body.withValues(alpha: .85));
    // 몸
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: len, height: len * .46);
    canvas.drawOval(bodyRect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(body, Colors.white, .35)!, body]).createShader(bodyRect));
    // 흰 무늬
    canvas.drawOval(Rect.fromCenter(center: Offset(-len * .08, -len * .04), width: len * .34, height: len * .2), Paint()..color = const Color(0xBBFFFFFF));
    // 눈
    canvas.drawCircle(Offset(len * .3, -len * .07), len * .045, Paint()..color = const Color(0xFF1C2B20));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PondFishPainter old) => old.t != t;
}
