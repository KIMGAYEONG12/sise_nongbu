import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 농장 풍경 속 집. 그림 파일(흐릿한 AI 이미지) 대신 코드(벡터)로 그려서 아무리 키워도 선명하다.
/// 시안(ChatGPT 농장 화면)의 집을 따라 비스듬히 본 시골집: 왼쪽 회색 박공 벽, 가운데 흰 박공과 나무 문,
/// 오른쪽 날개, 큼직한 주황 기와지붕, 굴뚝 두 개, 지붕 채광창, 정원 꽃과 덤불.
/// 그림 속 집(원본 936×714 기준 약 175~625, 105~405) 위에 같은 자리로 덮어 그린다.
class FarmHouseArt extends StatelessWidget {
  const FarmHouseArt({super.key});

  /// 그림 원본(936×714) 좌표에서 집을 덮는 자리
  static const srcRect = Rect.fromLTRB(165, 95, 635, 410);

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: FarmHousePainter(), size: Size.infinite));
}

class FarmHousePainter extends CustomPainter {
  const FarmHousePainter();

  static const dw = 470.0, dh = 315.0; // 그리는 기준 크기

  /// 시안 집 그림의 좌표(가로 85~880, 세로 95~650)를 이 그림 크기로 옮긴다.
  static Offset o(double x, double y) => Offset(10 + (x - 85) * .567, (y - 95) * .567);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / dw, size.height / dh);
    _ground(canvas);
    _walls(canvas);
    _roofs(canvas);
    _chimneys(canvas);
    _windowsAndDoor(canvas);
    _garden(canvas);
    canvas.restore();
  }

  Paint _f(Color c) => Paint()..color = c;
  Paint _s(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c;

  Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  Path _pp(List<List<double>> v) => _poly([for (final a in v) o(a[0], a[1])]);

  // ───────────────────────── 땅 ─────────────────────────

  void _ground(Canvas canvas) {
    final mound = Rect.fromCenter(center: const Offset(235, 282), width: 470, height: 70);
    canvas.drawOval(mound, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9BD65A), Color(0xFF5FB04A)]).createShader(mound));
    for (var i = 0; i < 40; i++) {
      final x = 20.0 + (i * 53 % 430), y = 268.0 + (i * 17 % 30);
      canvas.drawLine(Offset(x, y), Offset(x - 2, y - 7), _s(const Color(0x553C8A2A), 1.4));
    }
  }

  // ───────────────────────── 벽 ─────────────────────────

  void _walls(Canvas canvas) {
    // 왼쪽 회색 박공 벽
    final left = _pp(const [[112, 400], [205, 285], [345, 470], [345, 625], [128, 630]]);
    canvas.drawPath(left, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFC4C2D2), Color(0xFFA9A7BB)]).createShader(const Rect.fromLTRB(0, 40, 200, 300)));
    canvas.drawPath(left, _s(const Color(0x66605878), 1.4));
    // 가운데 낮은 흰 벽 (큰 창)
    final mid = _pp(const [[345, 470], [545, 432], [560, 612], [345, 625]]);
    canvas.drawPath(mid, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFBF0), Color(0xFFF1E6CF)]).createShader(const Rect.fromLTRB(110, 190, 260, 305)));
    canvas.drawPath(mid, _s(const Color(0x66A9885A), 1.4));
    // 흰 박공 (문이 있는 앞으로 나온 부분)
    final gable = _pp(const [[540, 436], [630, 292], [704, 402], [706, 612], [558, 616]]);
    canvas.drawPath(gable, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFF3E8D2)]).createShader(const Rect.fromLTRB(250, 110, 360, 305)));
    canvas.drawPath(gable, _s(const Color(0x66A9885A), 1.4));
    // 오른쪽 날개 벽
    final right = _pp(const [[704, 402], [842, 386], [844, 520], [708, 560]]);
    canvas.drawPath(right, _f(const Color(0xFFF7EEDB)));
    canvas.drawPath(right, _s(const Color(0x66A9885A), 1.4));
    // 아래 기단 그림자
    canvas.drawPath(_pp(const [[130, 626], [345, 622], [560, 612], [708, 560], [844, 520], [844, 540], [708, 585], [560, 640], [345, 646], [130, 650]]), _f(const Color(0x22000000)));
  }

  // ───────────────────────── 지붕 ─────────────────────────

  void _roofs(Canvas canvas) {
    const roofColors = [Color(0xFFF59A5F), Color(0xFFE2653A), Color(0xFFC84A2C)];
    Paint roofPaint(Rect r) => Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: roofColors).createShader(r);

    // 뒤쪽(오른쪽) 지붕
    final back = _pp(const [[420, 207], [668, 152], [906, 364], [704, 402], [630, 296]]);
    canvas.drawPath(back, roofPaint(const Rect.fromLTRB(170, 70, 470, 200)));
    // 큰 앞쪽(왼쪽) 지붕
    final front = _pp(const [[84, 388], [212, 242], [482, 202], [632, 292], [542, 436], [346, 492]]);
    canvas.drawPath(front, roofPaint(const Rect.fromLTRB(0, 60, 300, 220)));
    // 계곡(두 지붕이 만나는 어두운 면)
    final valley = _pp(const [[482, 202], [632, 292], [542, 436], [488, 336]]);
    canvas.drawPath(valley, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9A4A2E), Color(0xFF7A3620)]).createShader(const Rect.fromLTRB(230, 60, 330, 190)));
    // 박공 앞 작은 지붕 (문 위)
    final porch = _pp(const [[536, 440], [630, 288], [712, 400], [700, 410], [630, 318], [556, 448]]);
    canvas.drawPath(porch, _f(const Color(0xFFDE5E34)));

    // 기와 줄무늬
    canvas.save();
    canvas.clipPath(front);
    for (var k = 0; k < 16; k++) {
      canvas.drawLine(o(84 + k * 33.0, 388 - k * 9.0), o(346 + k * 22.0, 492 - k * 26.0), _s(const Color(0x30A23A20), 1.2));
    }
    canvas.restore();
    canvas.save();
    canvas.clipPath(back);
    for (var k = 0; k < 14; k++) {
      canvas.drawLine(o(420 + k * 22.0, 207 - k * 3.0), o(704 + k * 12.0, 398 - k * 3.0), _s(const Color(0x30A23A20), 1.2));
    }
    canvas.restore();

    // 처마 선과 윤곽
    for (final p in [back, front, valley, porch]) {
      canvas.drawPath(p, _s(const Color(0xFF8E3420), 1.8));
    }
    canvas.drawLine(o(84, 388), o(346, 492), _s(const Color(0xFFB5442A), 4));
    canvas.drawLine(o(704, 398), o(884, 352), _s(const Color(0xFFB5442A), 4));
    // 지붕 채광창(하얀 창)
    for (final c in const [[385.0, 345.0], [715.0, 262.0]]) {
      final r = Rect.fromCenter(center: o(c[0], c[1]), width: 34, height: 26);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), _f(const Color(0xFFFFFBF0)));
      canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(3)), _f(const Color(0xFFBFE6FF)));
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), _s(const Color(0xFF8E3420), 1.4));
    }
  }

  // ───────────────────────── 굴뚝 ─────────────────────────

  void _chimney(Canvas canvas, List<List<double>> pts) {
    final p = _pp(pts);
    final r = p.getBounds();
    canvas.drawPath(p, Paint()..shader = const LinearGradient(colors: [Color(0xFFD27A58), Color(0xFFA9553C)]).createShader(r));
    canvas.drawPath(p, _s(const Color(0xFF6B3A2A), 1.4));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.left - 3, r.top - 3, r.right + 3, r.top + 6), const Radius.circular(3)), _f(const Color(0xFF7A4A38)));
    for (var y = r.top + 12; y < r.bottom - 4; y += 11) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), _s(const Color(0x44FFFFFF), 1.1));
    }
  }

  void _chimneys(Canvas canvas) {
    _chimney(canvas, const [[305, 170], [392, 165], [388, 256], [310, 262]]);
    _chimney(canvas, const [[630, 100], [716, 106], [712, 192], [640, 186]]);
  }

  // ───────────────────────── 창문과 문 ─────────────────────────

  void _win(Canvas canvas, Rect r, {bool arch = false}) {
    canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(3), Radius.circular(arch ? 9 : 3)), _f(const Color(0xFF7A4A28)));
    final glass = RRect.fromRectAndRadius(r, Radius.circular(arch ? 8 : 2));
    canvas.drawRRect(glass, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF3DFA8), Color(0xFFC9A55A)]).createShader(r));
    canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), _s(const Color(0xFF7A4A28), 1.8));
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), _s(const Color(0xFF7A4A28), 1.8));
  }

  void _windowsAndDoor(Canvas canvas) {
    // 왼쪽 회색 벽의 작은 창 세 개
    for (final c in const [[212.0, 372.0], [182.0, 500.0], [268.0, 520.0]]) {
      _win(canvas, Rect.fromCenter(center: o(c[0], c[1]), width: 15, height: 21));
    }
    // 가운데 낮은 벽의 가로 창
    _win(canvas, Rect.fromPoints(o(405, 505), o(500, 560)));
    // 박공 위 아치 창
    _win(canvas, Rect.fromCenter(center: o(630, 380), width: 22, height: 30), arch: true);
    // 오른쪽 날개 창
    _win(canvas, Rect.fromCenter(center: o(765, 450), width: 30, height: 34));
    // 나무 문 (박공 아래)
    final door = _pp(const [[570, 472], [666, 462], [668, 594], [576, 604]]);
    canvas.drawPath(door, Paint()..shader = const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFFD08A44), Color(0xFFA8651F)]).createShader(door.getBounds()));
    final glass = _pp(const [[590, 490], [650, 484], [652, 574], [594, 582]]);
    canvas.drawPath(glass, _f(const Color(0xFFE7CF86)));
    canvas.drawPath(glass, _s(const Color(0xFF6B3F18), 1.4));
    canvas.drawLine(o(620, 487), o(623, 578), _s(const Color(0xFF6B3F18), 1.4));
    canvas.drawPath(door, _s(const Color(0xFF5A3216), 2.2));
    // 현관 계단
    final step = _pp(const [[560, 604], [680, 594], [716, 628], [572, 640]]);
    canvas.drawPath(step, _f(const Color(0xFFE2CE9E)));
    canvas.drawPath(step, _s(const Color(0x66A9885A), 1.4));
  }

  // ───────────────────────── 정원 ─────────────────────────

  void _bush(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.45), radius: 1.0, colors: [Color(0xFF8FDB63), Color(0xFF2F8F3E)]).createShader(rect));
    canvas.drawCircle(c, r, _s(const Color(0x55216B2F), 1.2));
    canvas.drawArc(Rect.fromCircle(center: c.translate(-r * .1, -r * .1), radius: r * .6), math.pi * 1.1, math.pi * .6, false, _s(const Color(0x66E5FFC9), 1.6));
  }

  void _garden(Canvas canvas) {
    for (final b in [(o(205, 590), 26.0), (o(150, 640), 18.0), (o(470, 640), 16.0), (o(720, 620), 20.0), (o(800, 600), 18.0), (o(860, 560), 15.0)]) {
      _bush(canvas, b.$1, b.$2);
    }
    const petals = [Color(0xFFFF8A3D), Color(0xFFFFD34E), Color(0xFFE5483B), Color(0xFFFFFFFF), Color(0xFFFF8FB1)];
    var n = 0;
    for (final f in [o(380, 640), o(420, 650), o(520, 650), o(600, 660), o(690, 640), o(740, 650), o(790, 630), o(190, 660), o(560, 630)]) {
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        canvas.drawCircle(f + Offset(math.cos(a), math.sin(a)) * 3.4, 2.6, _f(petals[n % petals.length]));
      }
      canvas.drawCircle(f, 2, _f(const Color(0xFFFFB300)));
      n++;
    }
  }

  @override
  bool shouldRepaint(FarmHousePainter old) => false;
}
