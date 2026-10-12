import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 농장 풍경 속 집. 그림 파일(흐릿한 AI 이미지) 대신 코드(벡터)로 그려서 아무리 키워도 선명하다.
/// 시안처럼 주황 기와지붕 · 굴뚝 · 지붕창 · 흰 벽 · 나무 문 · 창문과 꽃 화분이 있는 아담한 시골집.
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

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / dw, size.height / dh);
    _ground(canvas);
    _walls(canvas);
    _chimney(canvas);
    _roof(canvas);
    _gable(canvas);
    _dormer(canvas);
    _windowsAndDoor(canvas);
    _bushes(canvas);
    canvas.restore();
  }

  Paint _f(Color c) => Paint()..color = c;
  Paint _s(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c;

  // ───────────────────────── 땅 ─────────────────────────

  void _ground(Canvas canvas) {
    // 집 아래 풀 언덕 (옛 집의 아랫부분을 자연스럽게 덮는다)
    final mound = Rect.fromCenter(center: const Offset(235, 278), width: 470, height: 78);
    canvas.drawOval(mound, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9BD65A), Color(0xFF5FB04A)]).createShader(mound));
    // 풀잎 결
    for (var i = 0; i < 40; i++) {
      final x = 20.0 + (i * 53 % 430), y = 262.0 + (i * 17 % 36);
      canvas.drawLine(Offset(x, y), Offset(x - 2, y - 7), _s(const Color(0x553C8A2A), 1.4));
    }
    // 현관 앞 돌길
    final path = Path()
      ..moveTo(228, 266)
      ..lineTo(268, 266)
      ..lineTo(300, 312)
      ..lineTo(196, 312)
      ..close();
    canvas.drawPath(path, _f(const Color(0xFFE6D3A8)));
    for (final r in const [Rect.fromLTWH(222, 276, 26, 9), Rect.fromLTWH(252, 282, 30, 9), Rect.fromLTWH(214, 292, 30, 9), Rect.fromLTWH(250, 300, 34, 9)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), _f(const Color(0xFFF3E6C4)));
    }
  }

  // ───────────────────────── 벽 ─────────────────────────

  void _walls(Canvas canvas) {
    const body = Rect.fromLTRB(26, 140, 440, 266);
    // 기단 그림자
    canvas.drawRect(Rect.fromLTRB(36, 258, 436, 272), _f(const Color(0x33000000)));
    canvas.drawRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF8EA), Color(0xFFF1E6CF)]).createShader(body));
    // 오른쪽 날개는 조금 어둡게 (집이 꺾여 보이게)
    canvas.drawRect(const Rect.fromLTRB(296, 140, 440, 266), _f(const Color(0x1A8A6A3A)));
    canvas.drawLine(const Offset(296, 140), const Offset(296, 266), _s(const Color(0x338A6A3A), 2));
    // 돌 기단
    const base = Rect.fromLTRB(26, 246, 440, 266);
    canvas.drawRect(base, _f(const Color(0xFFB9A98C)));
    for (var x = 26.0; x < 440; x += 26) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 248, 22, 16), const Radius.circular(3)), _f(((x ~/ 26) % 2 == 0) ? const Color(0xFFCDBFA3) : const Color(0xFFC2B397)));
    }
    // 나무 벽 장식 선
    canvas.drawLine(const Offset(42, 188), const Offset(430, 188), _s(const Color(0x22A9885A), 1.2));
    canvas.drawRect(body, _s(const Color(0x66A9885A), 1.6));
  }

  // ───────────────────────── 굴뚝 ─────────────────────────

  void _chimney(Canvas canvas) {
    const r = Rect.fromLTRB(142, 6, 190, 90);
    canvas.drawRect(r, Paint()..shader = const LinearGradient(colors: [Color(0xFFC96F52), Color(0xFFA9553C)]).createShader(r));
    for (var y = 14.0; y < 88; y += 11) {
      canvas.drawLine(Offset(142, y), Offset(190, y), _s(const Color(0x44FFFFFF), 1.2));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(136, 0, 196, 14), const Radius.circular(3)), _f(const Color(0xFF7A4A38)));
    canvas.drawRect(r, _s(const Color(0xFF6B3A2A), 1.4));
  }

  // ───────────────────────── 지붕 ─────────────────────────

  void _roof(Canvas canvas) {
    final roof = Path()
      ..moveTo(6, 156)
      ..lineTo(84, 20)
      ..lineTo(372, 20)
      ..lineTo(464, 156)
      ..close();
    const box = Rect.fromLTRB(6, 20, 462, 156);
    canvas.drawPath(roof, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0845A), Color(0xFFE2603B), Color(0xFFC84A2C)]).createShader(box));
    canvas.save();
    canvas.clipPath(roof);
    // 기와 줄무늬 (가로) + 어긋난 세로 이음
    for (var y = 34.0; y < 156; y += 13) {
      canvas.drawLine(Offset(0, y), Offset(470, y), _s(const Color(0x40A23A20), 1.4));
      final odd = ((y - 34) ~/ 13).isOdd;
      for (var x = odd ? 16.0 : 4.0; x < 470; x += 24) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 13), _s(const Color(0x2AA23A20), 1.1));
      }
    }
    // 햇빛 받는 윗면 / 그림자 오른쪽
    canvas.drawRect(const Rect.fromLTRB(0, 20, 470, 52), _f(const Color(0x22FFFFFF)));
    canvas.drawPath(Path()..moveTo(372, 20)..lineTo(464, 156)..lineTo(390, 156)..lineTo(330, 20)..close(), _f(const Color(0x18000000)));
    canvas.restore();
    // 처마 끝 두꺼운 선과 그림자
    canvas.drawPath(Path()..moveTo(6, 156)..lineTo(462, 156), _s(const Color(0xFF9E3B22), 5));
    canvas.drawRect(const Rect.fromLTRB(10, 158, 458, 168), _f(const Color(0x33000000)));
    // 마루(맨 위 선)
    canvas.drawLine(const Offset(84, 20), const Offset(372, 20), _s(const Color(0xFF9E3B22), 5));
    canvas.drawPath(roof, _s(const Color(0xFF8E3420), 2));
  }

  /// 오른쪽에 앞으로 튀어나온 박공(삼각 지붕): 시안처럼 집이 ㄱ자로 보이게 한다.
  void _gable(Canvas canvas) {
    // 박공 아래 벽(앞으로 나온 쪽은 더 밝게)
    final wall = Path()
      ..moveTo(252, 262)
      ..lineTo(252, 176)
      ..lineTo(330, 100)
      ..lineTo(424, 176)
      ..lineTo(424, 262)
      ..close();
    canvas.drawPath(wall, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFBF0), Color(0xFFF3E8D2)]).createShader(const Rect.fromLTRB(252, 100, 424, 262)));
    canvas.drawPath(wall, _s(const Color(0x66A9885A), 1.6));
    // 박공 지붕(주황 테두리 두 줄)
    final roofL = Path()..moveTo(236, 182)..lineTo(330, 88)..lineTo(330, 100)..lineTo(252, 182)..close();
    final roofR = Path()..moveTo(330, 88)..lineTo(440, 182)..lineTo(424, 182)..lineTo(330, 100)..close();
    for (final p in [roofL, roofR]) {
      canvas.drawPath(p, _f(const Color(0xFFE2603B)));
      canvas.drawPath(p, _s(const Color(0xFF8E3420), 1.8));
    }
    canvas.drawLine(const Offset(236, 182), const Offset(330, 88), _s(const Color(0xFFB9482A), 4));
    canvas.drawLine(const Offset(330, 88), const Offset(440, 182), _s(const Color(0xFFB9482A), 4));
    // 박공 안의 둥근 창
    canvas.drawCircle(const Offset(330, 140), 15, _f(const Color(0xFF6B4423)));
    final glass = Rect.fromCircle(center: const Offset(330, 140), radius: 12);
    canvas.drawOval(glass, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD6F0FF), Color(0xFF7FC4EE)]).createShader(glass));
    canvas.drawLine(const Offset(330, 128), const Offset(330, 152), _s(const Color(0xFFFFF8EA), 2));
    canvas.drawLine(const Offset(318, 140), const Offset(342, 140), _s(const Color(0xFFFFF8EA), 2));
    // 박공 아래 처마 그림자
    canvas.drawRect(const Rect.fromLTRB(252, 178, 424, 186), _f(const Color(0x22000000)));
  }

  /// 지붕창: 작은 삼각 지붕이 달린 창
  void _dormer(Canvas canvas) {
    const cx = 232.0;
    final wall = RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 26, 70, cx + 26, 118), const Radius.circular(3));
    canvas.drawRRect(wall, _f(const Color(0xFFFFF8EA)));
    canvas.drawRRect(wall, _s(const Color(0xFFA9885A), 1.6));
    final glass = RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 18, 80, cx + 18, 114), const Radius.circular(2));
    canvas.drawRRect(glass, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBFE6FF), Color(0xFF7CC3F0)]).createShader(glass.outerRect));
    canvas.drawLine(const Offset(cx, 80), const Offset(cx, 114), _s(Colors.white, 2));
    canvas.drawLine(const Offset(cx - 18, 97), const Offset(cx + 18, 97), _s(Colors.white, 2));
    canvas.drawRRect(glass, _s(const Color(0xFF7A4A28), 2));
    // 작은 삼각 지붕
    final cap = Path()
      ..moveTo(cx - 34, 74)
      ..lineTo(cx, 46)
      ..lineTo(cx + 34, 74)
      ..close();
    canvas.drawPath(cap, _f(const Color(0xFFD95B36)));
    canvas.drawPath(cap, _s(const Color(0xFF8E3420), 2));
    canvas.drawLine(Offset(cx - 22, 66), Offset(cx + 22, 66), _s(const Color(0x44FFFFFF), 1.4));
  }

  // ───────────────────────── 창문과 문 ─────────────────────────

  void _window(Canvas canvas, Rect r) {
    // 덧창(초록 갈색)
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.left - 12, r.top, r.left - 2, r.bottom), const Radius.circular(2)), _f(const Color(0xFF8A5A33)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.right + 2, r.top, r.right + 12, r.bottom), const Radius.circular(2)), _f(const Color(0xFF8A5A33)));
    // 틀과 유리
    canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(3)), _f(const Color(0xFF6B4423)));
    final glass = RRect.fromRectAndRadius(r, const Radius.circular(2));
    canvas.drawRRect(glass, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD6F0FF), Color(0xFF7FC4EE)]).createShader(r));
    canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), _s(const Color(0xFFFFF8EA), 2.4));
    canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), _s(const Color(0xFFFFF8EA), 2.4));
    canvas.drawPath(Path()..moveTo(r.left + 3, r.top + 12)..lineTo(r.left + 14, r.top + 3), _s(const Color(0x99FFFFFF), 2));
    // 꽃 화분
    final box = Rect.fromLTRB(r.left - 6, r.bottom + 4, r.right + 6, r.bottom + 15);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)), _f(const Color(0xFF8A5A33)));
    const colors = [Color(0xFFE5483B), Color(0xFFFFD34E), Color(0xFFFF8FB1), Color(0xFFFFFFFF)];
    for (var i = 0; i < 6; i++) {
      final x = box.left + 5 + i * (box.width - 10) / 5;
      canvas.drawCircle(Offset(x, box.top - 2), 4, _f(const Color(0xFF3FA33A)));
      canvas.drawCircle(Offset(x, box.top - 5), 3.2, _f(colors[i % colors.length]));
    }
  }

  void _windowsAndDoor(Canvas canvas) {
    _window(canvas, const Rect.fromLTRB(78, 172, 118, 214));
    _window(canvas, const Rect.fromLTRB(150, 172, 190, 214));
    _window(canvas, const Rect.fromLTRB(284, 196, 320, 232));
    _window(canvas, const Rect.fromLTRB(352, 196, 388, 232));

    // 나무 문 (위가 둥근 아치) + 문 위 작은 차양
    const door = Rect.fromLTRB(226, 190, 272, 262);
    final arch = Path()
      ..moveTo(door.left, door.bottom)
      ..lineTo(door.left, door.top + 20)
      ..quadraticBezierTo(door.left, door.top, door.center.dx, door.top)
      ..quadraticBezierTo(door.right, door.top, door.right, door.top + 20)
      ..lineTo(door.right, door.bottom)
      ..close();
    canvas.drawPath(arch.shift(const Offset(0, 0)), Paint()..shader = const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFFB56A30), Color(0xFF8A4A1E)]).createShader(door));
    // 널빤지 선
    for (final x in const [238.0, 249.0, 260.0]) {
      canvas.drawLine(Offset(x, door.top + 10), Offset(x, door.bottom), _s(const Color(0x44301808), 1.2));
    }
    // 문 작은 창
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(238, 204, 260, 224), const Radius.circular(3)), _f(const Color(0xFFBFE6FF)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(238, 204, 260, 224), const Radius.circular(3)), _s(const Color(0xFF5A3216), 1.6));
    canvas.drawCircle(const Offset(264, 232), 2.6, _f(const Color(0xFFFFD34E))); // 손잡이
    canvas.drawPath(arch, _s(const Color(0xFF4A2810), 2.4));
    // 문 차양
    final awning = Path()
      ..moveTo(214, 192)
      ..quadraticBezierTo(249, 168, 284, 192)
      ..lineTo(278, 198)
      ..quadraticBezierTo(249, 178, 220, 198)
      ..close();
    canvas.drawPath(awning, _f(const Color(0xFFD95B36)));
    canvas.drawPath(awning, _s(const Color(0xFF8E3420), 1.6));
    // 계단
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(218, 262, 280, 272), const Radius.circular(3)), _f(const Color(0xFFD9C79F)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(210, 270, 288, 280), const Radius.circular(3)), _f(const Color(0xFFE6D6B0)));
  }

  // ───────────────────────── 덤불과 꽃 ─────────────────────────

  void _bush(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.45), radius: 1.0, colors: [Color(0xFF8FDB63), Color(0xFF2F8F3E)]).createShader(rect));
    canvas.drawCircle(c, r, _s(const Color(0x55216B2F), 1.2));
    canvas.drawArc(Rect.fromCircle(center: c.translate(-r * .1, -r * .1), radius: r * .6), math.pi * 1.1, math.pi * .6, false, _s(const Color(0x66E5FFC9), 1.6));
  }

  void _bushes(Canvas canvas) {
    for (final b in const [(Offset(34, 262), 24.0), (Offset(66, 274), 20.0), (Offset(438, 262), 24.0), (Offset(404, 276), 20.0), (Offset(190, 282), 14.0), (Offset(296, 284), 14.0)]) {
      _bush(canvas, b.$1, b.$2);
    }
    const petals = [Color(0xFFFF8FB1), Color(0xFFFFFFFF), Color(0xFFFFD34E), Color(0xFFE5483B)];
    var n = 0;
    for (final f in const [Offset(26, 252), Offset(52, 268), Offset(444, 254), Offset(414, 270), Offset(188, 276), Offset(300, 278)]) {
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
