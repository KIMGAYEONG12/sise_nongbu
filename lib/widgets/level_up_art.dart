import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart' show GirlAvatarPainter;

/// 레벨 업 창의 배경 그림이 어느 층인지.
/// back: 하늘·햇살·풀숲·소·농부 (색종이 뒤에 깔린다)
/// front: 나무 간판 "LEVEL UP!"과 "Lv.n" 리본 (색종이 앞에 놓여서 글자가 가려지거나 깨져 보이지 않는다)
enum LevelUpLayer { back, front }

/// 레벨 업 창의 그림 (농부 · 소 · 나무 간판 "LEVEL UP!" · 풀숲과 꽃).
/// 그림 파일이 아니라 코드(벡터)로 그려서 화면이 커져도 도트가 깨지지 않고 선명하다.
/// 좌표는 예전 시안 그림과 같은 354×486 기준이라, 위에 얹는 "Lv.n" 리본과 흰 안내 판 자리는 그대로다.
class LevelUpCardArt extends StatelessWidget {
  const LevelUpCardArt({super.key, this.layer = LevelUpLayer.back});
  final LevelUpLayer layer;

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: LevelUpCardPainter(layer: layer), size: Size.infinite));
}

/// 계속 떨어지는 색종이 (이모지 글자가 아니라 코드로 그린 별·조각·점이라 어떤 기기에서도 깨지지 않는다)
class LevelUpConfetti extends StatefulWidget {
  const LevelUpConfetti({super.key});
  @override
  State<LevelUpConfetti> createState() => _LevelUpConfettiState();
}

class _LevelUpConfettiState extends State<LevelUpConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _ConfettiPainter(_c), size: Size.infinite)));
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _colors = [Color(0xFFFFD34E), Color(0xFFFF8FB1), Color(0xFF5ED6C8), Color(0xFFFFFFFF), Color(0xFFFFA24C)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / LevelUpCardPainter.artW, size.height / LevelUpCardPainter.artH);
    for (var i = 0; i < 24; i++) {
      final v = (t.value + i * .043) % 1.0; // 0(위)~1(아래)
      final x = 8 + ((i * 53) % 100) / 100 * (LevelUpCardPainter.artW - 16) + math.sin(v * math.pi * 3 + i) * 8;
      final y = -12 + v * (LevelUpCardPainter.artH + 24);
      final alpha = (v < .08 ? v / .08 : (1 - v)).clamp(0.0, 1.0) * .95;
      final p = Paint()..color = _colors[i % _colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(v * 8 + i);
      switch (i % 4) {
        case 0:
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final r = k.isEven ? 6.5 : 2.8;
            final a = -math.pi / 2 + k * math.pi / 5;
            k == 0 ? star.moveTo(math.cos(a) * r, math.sin(a) * r) : star.lineTo(math.cos(a) * r, math.sin(a) * r);
          }
          canvas.drawPath(star..close(), p);
        case 1:
          canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -2.5, 10, 5), const Radius.circular(1.5)), p);
        case 2:
          canvas.drawCircle(Offset.zero, 3, p);
        default:
          canvas.drawPath(Path()..moveTo(0, -5)..lineTo(4, 0)..lineTo(0, 5)..lineTo(-4, 0)..close(), p);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

class LevelUpCardPainter extends CustomPainter {
  const LevelUpCardPainter({this.layer = LevelUpLayer.back});

  final LevelUpLayer layer;

  static const artW = 354.0, artH = 486.0;

  /// 위에 얹는 "Lv.n" 리본 몸통 자리 (이 자리에는 화면이 직접 글자를 얹는다)
  static const ribbonBody = Rect.fromLTRB(106, 226, 252, 264);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / artW, size.height / artH);
    canvas.clipRect(const Rect.fromLTWH(0, 0, artW, artH));
    if (layer == LevelUpLayer.back) {
      _sky(canvas);
      _sparkles(canvas);
      _bushes(canvas);
      _cow(canvas);
      _girl(canvas);
    } else {
      _sign(canvas);
      _ribbon(canvas);
    }
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

  // ───────────────────────── 반짝이는 별과 잎 (시안처럼 위쪽을 화려하게) ─────────────────────────

  void _sparkles(Canvas canvas) {
    // 네 갈래 반짝이
    for (final sp in const [(34.0, 52.0, 9.0), (320.0, 60.0, 10.0), (58.0, 110.0, 6.0), (298.0, 118.0, 7.0), (262.0, 22.0, 6.0), (92.0, 24.0, 6.0)]) {
      final c = Offset(sp.$1, sp.$2), r = sp.$3;
      final star = Path()
        ..moveTo(c.dx, c.dy - r * 1.7)
        ..quadraticBezierTo(c.dx + r * .22, c.dy - r * .22, c.dx + r * 1.7, c.dy)
        ..quadraticBezierTo(c.dx + r * .22, c.dy + r * .22, c.dx, c.dy + r * 1.7)
        ..quadraticBezierTo(c.dx - r * .22, c.dy + r * .22, c.dx - r * 1.7, c.dy)
        ..quadraticBezierTo(c.dx - r * .22, c.dy - r * .22, c.dx, c.dy - r * 1.7)
        ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xEEFFF6C2));
    }
    // 반짝이는 큰 잎 (왼쪽 초록, 오른쪽 주황)
    void leaf(Offset at, double angle, double len, Color a, Color b) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * .5, -len * .5, len, 0)
        ..quadraticBezierTo(len * .5, len * .42, 0, 0)
        ..close();
      final rect = Rect.fromLTWH(0, -len * .5, len, len * .9);
      canvas.drawPath(path, Paint()..shader = LinearGradient(colors: [a, b]).createShader(rect));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x55FFFFFF));
      canvas.drawLine(Offset.zero, Offset(len * .9, 0), Paint()
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF));
      canvas.restore();
    }

    leaf(const Offset(10, 70), -.5, 34, const Color(0xFF8FE05A), const Color(0xFF3FA33A));
    leaf(const Offset(344, 84), math.pi + .6, 34, const Color(0xFFFFC85A), const Color(0xFFF08A1E));
    leaf(const Offset(12, 156), -.1, 26, const Color(0xFFB7F07A), const Color(0xFF4DB04A));
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

  // ───────────────────────── 소 (시안 왼쪽 아래에서 빼꼼) ─────────────────────────

  void _cow(Canvas canvas) {
    const c = Offset(46, 136);
    // 귀
    for (final dx in const [-27.0, 27.0]) {
      canvas.drawOval(Rect.fromCenter(center: c.translate(dx, -10), width: 20, height: 12), Paint()..color = const Color(0xFFF3F3F3));
      canvas.drawOval(Rect.fromCenter(center: c.translate(dx, -10), width: 12, height: 6), Paint()..color = const Color(0xFFFFB6C1));
    }
    // 뿔
    for (final dx in const [-11.0, 11.0]) {
      canvas.drawOval(Rect.fromCenter(center: c.translate(dx, -26), width: 8, height: 14), Paint()..color = const Color(0xFFF5E6B8));
    }
    // 얼굴
    final face = Rect.fromCenter(center: c, width: 54, height: 50);
    canvas.drawOval(face, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFE6E6E6)]).createShader(face));
    canvas.drawOval(face, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF8A8A8A));
    // 검은 얼룩
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawOval(Rect.fromCenter(center: c.translate(-14, -10), width: 26, height: 22), Paint()..color = const Color(0xFF3A3A3A));
    canvas.restore();
    // 눈
    for (final dx in const [-10.0, 10.0]) {
      canvas.drawCircle(c.translate(dx, -4), 3.4, Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(c.translate(dx - .9, -5), 1.1, Paint()..color = Colors.white);
    }
    // 코와 웃는 입
    final muzzle = Rect.fromCenter(center: c.translate(0, 13), width: 30, height: 20);
    canvas.drawOval(muzzle, Paint()..color = const Color(0xFFFFB6C1));
    for (final dx in const [-5.0, 5.0]) {
      canvas.drawOval(Rect.fromCenter(center: c.translate(dx, 11), width: 4, height: 6), Paint()..color = const Color(0xFFC96B7A));
    }
    canvas.drawArc(Rect.fromCenter(center: c.translate(0, 15), width: 12, height: 8), .2, math.pi - .4, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFA24C5A));
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
    // 시안처럼 어깨 아래로 길게 내려오는 갈색 머리 (얼굴 뒤에 깔린다)
    final hair = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9A5A2E), Color(0xFF6E3C1A)]).createShader(const Rect.fromLTWH(0, 40, s, 140));
    for (final side in const [-1.0, 1.0]) {
      final x0 = s / 2 + side * 46; // 얼굴 옆
      final lock = Path()
        ..moveTo(x0, 70)
        ..cubicTo(x0 + side * 26, 96, x0 + side * 22, 134, x0 + side * 34, 172)
        ..lineTo(x0 - side * 18, 172)
        ..cubicTo(x0 - side * 4, 130, x0 - side * 8, 100, x0 - side * 6, 78)
        ..close();
      canvas.drawPath(lock, hair);
      canvas.drawPath(lock, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x554A260F));
      // 머리결 하이라이트
      canvas.drawPath(Path()..moveTo(x0 + side * 8, 92)..quadraticBezierTo(x0 + side * 14, 120, x0 + side * 12, 150), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55FFC48A));
    }
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
  bool shouldRepaint(LevelUpCardPainter old) => old.layer != layer;
}
