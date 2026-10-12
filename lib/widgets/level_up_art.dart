import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart' show GirlAvatarPainter;

/// 레벨 업 창의 배경 그림 (농부 · 나무 간판 "LEVEL UP!" · 풀숲과 꽃).
/// 그림 파일이 아니라 코드(벡터)로 그려서 화면이 커져도 도트가 깨지지 않고 선명하다.
/// 좌표는 예전 시안 그림과 같은 354×486 기준이라, 위에 얹는 "Lv.n" 리본과 흰 안내 판 자리는 그대로다.
class LevelUpCardArt extends StatelessWidget {
  const LevelUpCardArt({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: LevelUpCardPainter(), size: Size.infinite));
}

class LevelUpCardPainter extends CustomPainter {
  const LevelUpCardPainter();

  static const artW = 354.0, artH = 486.0;

  /// 위에 얹는 "Lv.n" 리본 몸통 자리 (이 자리에는 화면이 직접 글자를 얹는다)
  static const ribbonBody = Rect.fromLTRB(106, 226, 252, 264);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / artW, size.height / artH);
    canvas.clipRect(const Rect.fromLTWH(0, 0, artW, artH));
    _sky(canvas);
    _confetti(canvas);
    _bushes(canvas);
    _girl(canvas);
    _sign(canvas);
    _ribbon(canvas);
    canvas.restore();
  }

  // ───────────────────────── 하늘과 햇살 ─────────────────────────

  void _sky(Canvas canvas) {
    const full = Rect.fromLTWH(0, 0, artW, artH);
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC3F0), Color(0xFFB4E5FA), Color(0xFFE3F6DE), Color(0xFF9ED67A)],
          stops: [0, .42, .62, 1],
        ).createShader(full),
    );
    // 가운데에서 퍼지는 햇살 줄기
    const c = Offset(177, 130);
    final ray = Paint()..color = const Color(0x40FFFFFF);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a0 = i * 2 * math.pi / n;
      const spread = math.pi / n * .8;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a0) * 560, c.dy + math.sin(a0) * 560)
        ..lineTo(c.dx + math.cos(a0 + spread) * 560, c.dy + math.sin(a0 + spread) * 560)
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.drawCircle(
      c,
      170,
      Paint()..shader = const RadialGradient(colors: [Color(0xCCFFF3B8), Color(0x00FFF3B8)]).createShader(Rect.fromCircle(center: c, radius: 170)),
    );
    // 멀리 보이는 푸른 산
    final hills = Path()
      ..moveTo(0, 300)
      ..quadraticBezierTo(60, 262, 120, 292)
      ..quadraticBezierTo(180, 318, 240, 284)
      ..quadraticBezierTo(300, 258, 354, 296)
      ..lineTo(354, 340)
      ..lineTo(0, 340)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0x6671C4B8));
  }

  // ───────────────────────── 반짝이와 색종이 ─────────────────────────

  static const _confettiSpots = <(double, double, int, int)>[
    (34, 44, 0, 0), (62, 96, 1, 1), (22, 140, 2, 2), (312, 40, 0, 1), (288, 92, 2, 0), (332, 132, 1, 2),
    (96, 30, 2, 1), (258, 28, 1, 0), (48, 188, 1, 2), (318, 186, 0, 0), (140, 14, 0, 2), (208, 18, 1, 1),
    (80, 150, 2, 0), (276, 150, 2, 2),
  ];
  static const _confettiColors = [Color(0xFFFFD34E), Color(0xFFFF8FB1), Color(0xFF5ED6C8)];

  void _confetti(Canvas canvas) {
    for (var i = 0; i < _confettiSpots.length; i++) {
      final (x, y, kind, col) = _confettiSpots[i];
      final p = Paint()..color = _confettiColors[col];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i * .7);
      switch (kind) {
        case 0: // 별
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final r = k.isEven ? 8.0 : 3.4;
            final a = -math.pi / 2 + k * math.pi / 5;
            k == 0 ? star.moveTo(math.cos(a) * r, math.sin(a) * r) : star.lineTo(math.cos(a) * r, math.sin(a) * r);
          }
          canvas.drawPath(star..close(), p);
          break;
        case 1: // 색종이 조각
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -3, 12, 6), const Radius.circular(1.5)), p);
          break;
        default: // 반짝이는 점
          canvas.drawCircle(Offset.zero, 3.4, p);
          canvas.drawCircle(Offset.zero, 6, Paint()..color = p.color.withValues(alpha: .25));
      }
      canvas.restore();
    }
  }

  // ───────────────────────── 풀숲과 꽃 ─────────────────────────

  void _bush(Canvas canvas, Offset c, double r, int tone) {
    const dark = [Color(0xFF2F8F3E), Color(0xFF3FA044), Color(0xFF278A45)];
    const light = [Color(0xFF7ED35A), Color(0xFF8FDB63), Color(0xFF6BCB6A)];
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(center: const Alignment(-.35, -.45), radius: 1.0, colors: [light[tone % 3], dark[tone % 3]]).createShader(rect),
    );
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55216B2F));
    // 잎맥 같은 하이라이트
    canvas.drawArc(Rect.fromCircle(center: c.translate(-r * .1, -r * .1), radius: r * .6), math.pi * 1.1, math.pi * .6, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x66E5FFC9));
  }

  void _flower(Canvas canvas, Offset c, double r, Color petal) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * .9, r * .62, Paint()..color = petal);
    }
    canvas.drawCircle(c, r * .5, Paint()..color = const Color(0xFFFFD34E));
    canvas.drawCircle(c.translate(-r * .12, -r * .12), r * .16, Paint()..color = const Color(0x88FFFFFF));
  }

  void _bushes(Canvas canvas) {
    // 아래 풀밭 언덕
    final field = Path()
      ..moveTo(0, 360)
      ..quadraticBezierTo(90, 332, 177, 346)
      ..quadraticBezierTo(264, 332, 354, 360)
      ..lineTo(354, artH)
      ..lineTo(0, artH)
      ..close();
    canvas.drawPath(field, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8FDB63), Color(0xFF3F9E3F)]).createShader(const Rect.fromLTWH(0, 330, artW, 160)));

    // 왼쪽 · 오른쪽 풀숲 (가운데는 흰 안내 판이 덮는다)
    const left = <(double, double, double, int)>[
      (6, 254, 26, 0), (30, 292, 30, 1), (4, 330, 34, 2), (34, 372, 32, 0), (6, 410, 36, 1), (30, 452, 34, 2), (4, 480, 30, 0),
    ];
    for (final b in left) {
      _bush(canvas, Offset(b.$1, b.$2), b.$3, b.$4);
      _bush(canvas, Offset(artW - b.$1, b.$2), b.$3, b.$4 + 1);
    }
    // 꽃
    const blooms = <(double, double, double, int)>[
      (22, 304, 7, 0), (40, 352, 6, 1), (14, 392, 7, 2), (36, 428, 6, 0), (20, 466, 7, 1),
    ];
    const petals = [Color(0xFFFF8FB1), Color(0xFFFFFFFF), Color(0xFFFFB347)];
    for (final f in blooms) {
      _flower(canvas, Offset(f.$1, f.$2), f.$3, petals[f.$4]);
      _flower(canvas, Offset(artW - f.$1, f.$2 + 6), f.$3, petals[(f.$4 + 1) % 3]);
    }
  }

  // ───────────────────────── 농부 ─────────────────────────

  void _girl(Canvas canvas) {
    // 큰 밀짚모자 농부 아이 (간판 위로 얼굴과 모자만 보인다)
    const s = 184.0;
    canvas.save();
    canvas.translate(177 - s / 2, 6);
    canvas.clipRect(const Rect.fromLTWH(-30, 0, s + 60, 170));
    // 뒤에서 비치는 따뜻한 빛
    canvas.drawCircle(const Offset(s / 2, 92), 86, Paint()..shader = const RadialGradient(colors: [Color(0xAAFFF8D0), Color(0x00FFF8D0)]).createShader(Rect.fromCircle(center: const Offset(s / 2, 92), radius: 86)));
    canvas.save();
    const GirlAvatarPainter().paint(canvas, const Size(s, s));
    canvas.restore();
    canvas.restore();
  }

  // ───────────────────────── 나무 간판 "LEVEL UP!" ─────────────────────────

  void _sign(Canvas canvas) {
    final board = RRect.fromRectAndRadius(const Rect.fromLTRB(40, 160, 314, 228), const Radius.circular(16));
    // 그림자
    canvas.drawRRect(board.shift(const Offset(0, 4)), Paint()..color = const Color(0x55000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // 나무판
    canvas.drawRRect(board, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD99A52), Color(0xFFB87638), Color(0xFF8E5528)]).createShader(board.outerRect));
    // 나뭇결
    canvas.save();
    canvas.clipRRect(board);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0x336B3F1D);
    for (var y = 172.0; y < 228; y += 12) {
      final p = Path()..moveTo(40, y);
      for (var x = 40.0; x <= 314; x += 22) {
        p.quadraticBezierTo(x + 11, y + (((x - 40) ~/ 22).isEven ? -2.5 : 2.5), x + 22, y);
      }
      canvas.drawPath(p, grain);
    }
    canvas.drawRect(const Rect.fromLTRB(40, 160, 314, 172), Paint()..color = const Color(0x33FFFFFF));
    canvas.restore();
    canvas.drawRRect(board, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..color = const Color(0xFF6B3F1D));
    // 못
    for (final x in const [54.0, 300.0]) {
      for (final y in const [174.0, 214.0]) {
        canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = const Color(0xFFE9D3A2));
        canvas.drawCircle(Offset(x - .8, y - .8), 1.2, Paint()..color = Colors.white);
      }
    }

    // 금빛 글씨 "LEVEL UP!"
    const style = TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1, fontFamily: 'Roboto');
    TextPainter tp(Paint? fg, Color? color) => TextPainter(
          text: TextSpan(text: 'LEVEL UP!', style: style.copyWith(foreground: fg, color: fg == null ? color : null)),
          textDirection: TextDirection.ltr,
        )..layout();
    final stroke = tp(Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF7A3E0B), null);
    const fillShader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0A0), Color(0xFFFFC73A), Color(0xFFF08A1E)], stops: [0, .55, 1]);
    final w = stroke.width, h = stroke.height;
    final fill = tp(Paint()..shader = fillShader.createShader(Rect.fromLTWH(0, 0, w, h)), null);
    // 글씨가 판보다 넓어지지 않게 맞춘다
    final k = math.min(1.0, 236 / w);
    canvas.save();
    canvas.translate(177, 194);
    canvas.scale(k);
    final o = Offset(-w / 2, -h / 2);
    stroke.paint(canvas, o.translate(0, 2.5)); // 아래 그림자 느낌
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
    canvas.restore();
  }

  // ───────────────────────── "Lv.n" 리본의 양쪽 꼬리 ─────────────────────────

  void _ribbon(Canvas canvas) {
    const body = ribbonBody;
    final tailPaint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9892A), Color(0xFFC96516)]).createShader(const Rect.fromLTRB(80, 230, 280, 272));
    final dark = Paint()..color = const Color(0xFF9E4F10);
    // 왼쪽
    final l = Path()
      ..moveTo(body.left + 2, body.top + 6)
      ..lineTo(84, body.top + 6)
      ..lineTo(94, (body.top + body.bottom) / 2 + 3)
      ..lineTo(84, body.bottom + 6)
      ..lineTo(body.left + 2, body.bottom + 6)
      ..close();
    canvas.drawPath(l, tailPaint);
    canvas.drawPath(Path()..moveTo(body.left, body.bottom)..lineTo(body.left + 8, body.bottom + 6)..lineTo(body.left, body.bottom + 6)..close(), dark);
    // 오른쪽
    final r = Path()
      ..moveTo(body.right - 2, body.top + 6)
      ..lineTo(270, body.top + 6)
      ..lineTo(260, (body.top + body.bottom) / 2 + 3)
      ..lineTo(270, body.bottom + 6)
      ..lineTo(body.right - 2, body.bottom + 6)
      ..close();
    canvas.drawPath(r, tailPaint);
    canvas.drawPath(Path()..moveTo(body.right, body.bottom)..lineTo(body.right - 8, body.bottom + 6)..lineTo(body.right, body.bottom + 6)..close(), dark);
    // 리본 몸통: 아래 그림자 → 주황 몸통 (화면이 그 위에 "Lv.n"을 얹는다)
    canvas.drawRRect(RRect.fromRectAndRadius(body.shift(const Offset(0, 3)), const Radius.circular(6)), Paint()..color = const Color(0x44000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    final bodyR = RRect.fromRectAndRadius(body, const Radius.circular(6));
    canvas.drawRRect(bodyR, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFDA82D), Color(0xFFF08A1E)]).createShader(body));
    canvas.drawRRect(bodyR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC96516));
  }

  @override
  bool shouldRepaint(LevelUpCardPainter old) => false;
}
