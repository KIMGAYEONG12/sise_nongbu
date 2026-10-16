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
/// 비단잉어처럼 하늘거리는 지느러미, 무늬, 반짝이는 눈을 그린다.
class PondFishPainter extends CustomPainter {
  const PondFishPainter(this.t);
  final double t;

  // (바퀴 수, 시작 위치 0~1, 몸 크기 배율, 몸 색, 무늬 색)
  static const _fish = [
    (1, 0.00, 1.00, Color(0xFFFFFBF3), Color(0xFFF0442C)), // 흰 바탕에 빨간 무늬 (홍백)
    (-1, 0.40, 0.88, Color(0xFFFFC23A), Color(0xFFFF8A1F)), // 황금 잉어
    (2, 0.70, 0.74, Color(0xFFFF7A45), Color(0xFFFFFFFF)), // 주황 바탕에 흰 무늬
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width * .5, size.height * .44);
    final rx = size.width * .3, ry = size.height * .2; // 울타리 밖으로 나가지 않게 물 안쪽만 돈다
    final len = size.width * .17;

    for (var i = 0; i < _fish.length; i++) {
      final f = _fish[i];
      final a = (t * f.$1 + f.$2) * math.pi * 2;
      final dir = f.$1 < 0 ? -1.0 : 1.0;
      // 타원 위의 위치와 진행 방향
      final pos = c + Offset(rx * math.cos(a), ry * math.sin(a));
      final heading = math.atan2(dir * ry * math.cos(a), dir * -rx * math.sin(a));
      final wag = math.sin(t * math.pi * 2 * 14 + i * 2);
      _drawFish(canvas, pos, heading, len * f.$3, wag, f.$4, f.$5, i);
    }
  }

  void _drawFish(Canvas canvas, Offset pos, double heading, double len, double wag, Color body, Color spot, int kind) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    final w = wag * len * .1; // 꼬리 흔들림

    // 물 속 그림자
    canvas.drawOval(Rect.fromCenter(center: Offset(-len * .05, len * .3), width: len * 1.1, height: len * .3), Paint()..color = const Color(0x26003A66));

    final fin = Paint()..color = Color.lerp(spot == Colors.white ? body : spot, Colors.white, .35)!.withValues(alpha: .7);
    // 하늘거리는 꼬리 (두 갈래)
    final tail = Path()
      ..moveTo(-len * .34, 0)
      ..quadraticBezierTo(-len * .6, -len * .08 + w, -len * .86, -len * .3 + w * 1.6)
      ..quadraticBezierTo(-len * .7, -len * .04 + w, -len * .76, w * 1.2)
      ..quadraticBezierTo(-len * .7, len * .04 + w, -len * .86, len * .3 + w * 1.6)
      ..quadraticBezierTo(-len * .6, len * .08 + w, -len * .34, 0)
      ..close();
    canvas.drawPath(tail, fin);
    // 꼬리 줄무늬
    final ray = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..strokeWidth = len * .012
      ..style = PaintingStyle.stroke;
    for (final y in const [-.18, 0.0, .18]) {
      canvas.drawLine(Offset(-len * .42, 0), Offset(-len * .78, len * y + w * 1.3), ray);
    }
    // 가슴지느러미 (좌우로 살랑)
    final flap = wag * .25;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(len * .14, side * len * .12);
      canvas.rotate(side * (.7 + flap));
      canvas.drawOval(Rect.fromLTWH(-len * .2, -len * .05, len * .22, len * .1), fin);
      canvas.restore();
    }

    // 몸 (머리는 둥글고 꼬리 쪽으로 가늘어지는 물방울 모양)
    final bodyPath = Path()
      ..moveTo(len * .44, 0)
      ..cubicTo(len * .44, -len * .2, len * .12, -len * .23, -len * .1, -len * .17)
      ..cubicTo(-len * .26, -len * .12, -len * .36, -len * .05, -len * .4, 0)
      ..cubicTo(-len * .36, len * .05, -len * .26, len * .12, -len * .1, len * .17)
      ..cubicTo(len * .12, len * .23, len * .44, len * .2, len * .44, 0)
      ..close();
    final bounds = bodyPath.getBounds();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(body, Colors.white, .45)!, body, Color.lerp(body, Colors.black, .08)!]).createShader(bounds),
    );
    // 무늬는 몸 안에만
    canvas.save();
    canvas.clipPath(bodyPath);
    final sp = Paint()..color = spot.withValues(alpha: kind == 1 ? .55 : .92);
    if (kind == 0) {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .26, -len * .02), width: len * .26, height: len * .3), sp); // 머리 위 빨간 점
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .02, len * .04), width: len * .3, height: len * .26), sp);
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .26, -len * .03), width: len * .14, height: len * .12), sp);
    } else if (kind == 1) {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .02, -len * .1), width: len * .6, height: len * .12), sp); // 등줄기
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .06, -len * .06), width: len * .24, height: len * .18), sp);
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .22, len * .05), width: len * .16, height: len * .12), sp);
    }
    // 비늘 반짝임
    canvas.drawOval(Rect.fromCenter(center: Offset(len * .08, -len * .1), width: len * .4, height: len * .06), Paint()..color = Colors.white.withValues(alpha: .4));
    canvas.restore();
    canvas.drawPath(bodyPath, Paint()..style = PaintingStyle.stroke..strokeWidth = len * .015..color = Color.lerp(body, Colors.black, .25)!.withValues(alpha: .5));

    // 등지느러미
    final dorsal = Path()
      ..moveTo(len * .12, 0)
      ..quadraticBezierTo(-len * .02, -len * .03 + w * .3, -len * .2, 0)
      ..close();
    canvas.drawPath(dorsal, Paint()..color = fin.color..strokeWidth = len * .05..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // 눈 (양쪽) + 반짝이
    for (final side in const [-1.0, 1.0]) {
      final e = Offset(len * .32, side * len * .09);
      canvas.drawCircle(e, len * .045, Paint()..color = const Color(0xFF1C2B20));
      canvas.drawCircle(e + Offset(len * .012, -len * .012), len * .016, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PondFishPainter old) => old.t != t;
}
