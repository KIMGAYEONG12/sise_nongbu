import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 농장 연못에서 헤엄치는 비단잉어 세 마리 + 떠 있는 연잎·연꽃 + 퍼지는 물결.
/// 농장 그림(수채화 느낌)과 어울리도록 물고기는 물속에 살짝 잠긴 듯 부드럽게 그린다. 코드로 그려서 확대해도 선명하다.
/// [active]가 false이면(농장 탭이 아닐 때) 움직임을 멈춰서 배터리와 메모리를 아낀다.
class PondFish extends StatefulWidget {
  const PondFish({super.key, required this.active});
  final bool active;

  @override
  State<PondFish> createState() => _PondFishState();
}

class _PondFishState extends State<PondFish> with SingleTickerProviderStateMixin {
  /// 한 바퀴를 도는 시간 (천천히 여유롭게)
  static const lap = Duration(seconds: 26);

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

/// 연못 그림. [t]는 0~1 (한 바퀴). 물고기마다 도는 방향·속도·꼬리 흔들림이 다르다.
class PondFishPainter extends CustomPainter {
  const PondFishPainter(this.t);
  final double t;

  // (바퀴 수, 시작 위치 0~1, 몸 크기 배율, 몸 색, 무늬 색)
  static const _fish = [
    (1, 0.00, 1.00, Color(0xFFFFF6EC), Color(0xFFE8553E)), // 흰 바탕에 빨간 무늬 (홍백)
    (-1, 0.40, 0.86, Color(0xFFFFCB57), Color(0xFFF59A2E)), // 황금 잉어
    (2, 0.70, 0.74, Color(0xFFFF8E5E), Color(0xFFFFF3E6)), // 주황 바탕에 흰 무늬
  ];

  /// 그림 선과 같은 따뜻한 갈색 (물고기 테두리)
  static const _ink = Color(0xFF7A4A32);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width * .5, size.height * .44);
    final rx = size.width * .28, ry = size.height * .18; // 울타리 밖으로 나가지 않게 물 안쪽만 돈다
    final len = size.width * .15;

    _ripples(canvas, size);
    _lily(canvas, Offset(size.width * .2, size.height * .26), size.width * .085, 0.4, flower: true);
    _lily(canvas, Offset(size.width * .82, size.height * .66), size.width * .07, 2.2);

    for (var i = 0; i < _fish.length; i++) {
      final f = _fish[i];
      final a = (t * f.$1 + f.$2) * math.pi * 2;
      final dir = f.$1 < 0 ? -1.0 : 1.0;
      // 타원 위의 위치와 진행 방향 (조금씩 위아래로 흔들리며 헤엄친다)
      final pos = c + Offset(rx * math.cos(a), ry * math.sin(a) + math.sin(a * 3 + i) * ry * .08);
      final heading = math.atan2(dir * ry * math.cos(a), dir * -rx * math.sin(a));
      final wag = math.sin(t * math.pi * 2 * 16 + i * 2);
      _drawFish(canvas, pos, heading, len * f.$3, wag, f.$4, f.$5, i);
    }
  }

  /// 물 위에 천천히 퍼지는 동그란 물결 세 개
  void _ripples(Canvas canvas, Size size) {
    const spots = [(.36, .58, 0.0), (.66, .3, .33), (.5, .72, .66)];
    for (final s in spots) {
      final p = (t * 3 + s.$3) % 1.0; // 한 바퀴에 세 번
      final r = size.width * (.03 + .09 * p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, size.width * .006)
        ..color = Colors.white.withValues(alpha: .45 * (1 - p));
      canvas.drawOval(Rect.fromCenter(center: Offset(size.width * s.$1, size.height * s.$2), width: r * 2, height: r * 1.1), paint);
    }
  }

  /// 갈라진 동그란 연잎 (+ 분홍 연꽃)
  void _lily(Canvas canvas, Offset c, double r, double rot, {bool flower = false}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot + math.sin(t * math.pi * 2) * .06);
    canvas.scale(1, .62); // 물 위에 누워 있는 모양
    final leaf = Path()
      ..moveTo(0, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), -1.25, math.pi * 2 - .5, false)
      ..close();
    canvas.drawPath(leaf.shift(Offset(r * .06, r * .12)), Paint()..color = const Color(0x33004466));
    canvas.drawPath(leaf, Paint()..shader = const RadialGradient(colors: [Color(0xFF9AD164), Color(0xFF5E9E3A)]).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, r * .05)
      ..color = const Color(0x664A7A2A);
    for (final a in const [0.6, 1.6, 2.6, 3.6, 4.6]) {
      canvas.drawLine(Offset.zero, Offset(math.cos(a) * r * .8, math.sin(a) * r * .8), vein);
    }
    canvas.restore();
    if (flower) {
      final f = c + Offset(r * .25, -r * .25);
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3;
        canvas.drawOval(Rect.fromCenter(center: f + Offset(math.cos(a) * r * .22, math.sin(a) * r * .14), width: r * .34, height: r * .22), Paint()..color = const Color(0xFFF7A8C4));
      }
      canvas.drawCircle(f, r * .12, Paint()..color = const Color(0xFFFFE07A));
    }
  }

  void _drawFish(Canvas canvas, Offset pos, double heading, double len, double wag, Color body, Color spot, int kind) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    final w = wag * len * .1; // 꼬리 흔들림

    // 물속 그림자 (바닥에 비친 그림자는 살짝 아래로)
    canvas.drawOval(Rect.fromCenter(center: Offset(-len * .05, len * .26), width: len * 1.05, height: len * .32), Paint()..color = const Color(0x22003A66));

    final finColor = Color.lerp(spot == const Color(0xFFFFF3E6) ? body : spot, Colors.white, .45)!;
    final fin = Paint()..color = finColor.withValues(alpha: .62);
    // 하늘거리는 부채꼬리
    final tail = Path()
      ..moveTo(-len * .3, 0)
      ..quadraticBezierTo(-len * .55, -len * .1 + w, -len * .8, -len * .28 + w * 1.6)
      ..quadraticBezierTo(-len * .7, w * 1.1, -len * .8, len * .28 + w * 1.6)
      ..quadraticBezierTo(-len * .55, len * .1 + w, -len * .3, 0)
      ..close();
    canvas.drawPath(tail, fin);
    final ray = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..strokeWidth = len * .012
      ..style = PaintingStyle.stroke;
    for (final y in const [-.16, 0.0, .16]) {
      canvas.drawLine(Offset(-len * .38, 0), Offset(-len * .72, len * y + w * 1.3), ray);
    }
    // 둥근 가슴지느러미 (좌우로 살랑)
    final flap = wag * .3;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(len * .12, side * len * .13);
      canvas.rotate(side * (.8 + flap));
      canvas.drawOval(Rect.fromLTWH(-len * .2, -len * .06, len * .22, len * .12), fin);
      canvas.restore();
    }

    // 몸: 머리가 둥글고 통통한 귀여운 잉어
    final bodyPath = Path()
      ..moveTo(len * .4, 0)
      ..cubicTo(len * .42, -len * .2, len * .14, -len * .24, -len * .08, -len * .18)
      ..cubicTo(-len * .24, -len * .13, -len * .34, -len * .05, -len * .36, 0)
      ..cubicTo(-len * .34, len * .05, -len * .24, len * .13, -len * .08, len * .18)
      ..cubicTo(len * .14, len * .24, len * .42, len * .2, len * .4, 0)
      ..close();
    final bounds = bodyPath.getBounds();
    canvas.drawPath(
      bodyPath,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(body, Colors.white, .5)!, body, Color.lerp(body, const Color(0xFF2A6E9E), .18)!]).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(bodyPath);
    final sp = Paint()..color = spot.withValues(alpha: kind == 1 ? .5 : .9);
    if (kind == 0) {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .24, 0), width: len * .24, height: len * .26), sp); // 머리 위 빨간 점 (단정)
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .04, len * .05), width: len * .28, height: len * .24), sp);
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .24, -len * .03), width: len * .12, height: len * .1), sp);
    } else if (kind == 1) {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .02, -len * .1), width: len * .58, height: len * .11), sp); // 등줄기
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(len * .06, -len * .06), width: len * .22, height: len * .17), sp);
      canvas.drawOval(Rect.fromCenter(center: Offset(-len * .2, len * .05), width: len * .15, height: len * .11), sp);
    }
    // 비늘 반짝임
    canvas.drawOval(Rect.fromCenter(center: Offset(len * .08, -len * .1), width: len * .36, height: len * .055), Paint()..color = Colors.white.withValues(alpha: .55));
    // 꼬리 쪽은 물에 살짝 잠겨 푸르스름하게
    canvas.drawRect(Rect.fromLTWH(-len * .4, -len * .3, len * .3, len * .6), Paint()..shader = const LinearGradient(colors: [Color(0x553A9AD0), Color(0x003A9AD0)]).createShader(Rect.fromLTWH(-len * .4, 0, len * .3, 1)));
    canvas.restore();
    // 그림 선과 같은 따뜻한 갈색 테두리 (농장 그림과 어울리게)
    canvas.drawPath(bodyPath, Paint()..style = PaintingStyle.stroke..strokeWidth = len * .02..strokeJoin = StrokeJoin.round..color = _ink.withValues(alpha: .55));

    // 등지느러미
    final dorsal = Path()
      ..moveTo(len * .12, 0)
      ..quadraticBezierTo(-len * .02, -len * .03 + w * .3, -len * .18, 0);
    canvas.drawPath(dorsal, Paint()..color = finColor.withValues(alpha: .8)..strokeWidth = len * .05..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // 동글동글한 눈 + 반짝이
    for (final side in const [-1.0, 1.0]) {
      final e = Offset(len * .3, side * len * .09);
      canvas.drawCircle(e, len * .05, Paint()..color = const Color(0xFF2B2420));
      canvas.drawCircle(e + Offset(len * .014, -len * .014), len * .019, Paint()..color = Colors.white);
    }
    // 볼터치
    canvas.drawCircle(Offset(len * .22, len * .13), len * .035, Paint()..color = const Color(0x55FF7A8A));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PondFishPainter old) => old.t != t;
}
