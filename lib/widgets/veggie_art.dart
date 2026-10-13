import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_rules.dart' show cropOf;

/// 배추 말고 다른 작물(무·양파·사과·토마토·감자)을 코드로 그린 벡터 그림.
/// 이모지가 아니라서 어떤 크기에서도 선명하고, 작물마다 모양이 확실히 다르다.
class VeggiePainter extends CustomPainter {
  const VeggiePainter(this.code, {this.scale = 1});
  final String code;

  /// 칸 안에서 차지하는 크기 비율 (어린 작물은 작게)
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * .42 * scale;
    final c = Offset(size.width / 2, size.height * (.54 + (1 - scale) * .12));
    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * .92), width: r * 1.6, height: r * .3), Paint()..color = const Color(0x30000000));
    switch (code) {
      case 'RADISH':
        _radish(canvas, c, r);
      case 'ONION':
        _onion(canvas, c, r);
      case 'APPLE':
        _apple(canvas, c, r);
      case 'TOMATO':
        _tomato(canvas, c, r);
      case 'POTATO':
        _potato(canvas, c, r);
      case 'FIG':
        _fig(canvas, c, r);
      default:
        _emoji(canvas, c, r);
    }
  }

  /// 직접 그린 그림이 없는 작물은 그 작물의 이모지를 크게 그린다 (이모지를 모르면 초록 동그라미)
  void _emoji(Canvas canvas, Offset c, double r) {
    String? emoji;
    try {
      emoji = cropOf(code).emoji;
    } catch (_) {}
    if (emoji == null) {
      canvas.drawCircle(c, r * .6, Paint()..color = const Color(0xFF6DAA3F));
      return;
    }
    final tp = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: r * 1.75, height: 1)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// 무화과: 보랏빛 물방울 모양 열매 + 줄기 + 작은 잎 + 아래쪽 꽃눈
  void _fig(Canvas canvas, Offset c, double r) {
    final body = Path()
      // 윗부분은 좁고 아래로 갈수록 통통해지는 배(눈물) 모양 — 둥근 양파·마늘과 구별된다
      ..moveTo(c.dx, c.dy - r * .86)
      ..cubicTo(c.dx + r * .16, c.dy - r * .86, c.dx + r * .26, c.dy - r * .5, c.dx + r * .58, c.dy - r * .1)
      ..cubicTo(c.dx + r * .98, c.dy + r * .38, c.dx + r * .8, c.dy + r * .94, c.dx, c.dy + r * .94)
      ..cubicTo(c.dx - r * .8, c.dy + r * .94, c.dx - r * .98, c.dy + r * .38, c.dx - r * .58, c.dy - r * .1)
      ..cubicTo(c.dx - r * .26, c.dy - r * .5, c.dx - r * .16, c.dy - r * .86, c.dx, c.dy - r * .86)
      ..close();
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(body, _grad(rect, const [Color(0xFFB77CCB), Color(0xFF6B3A86), Color(0xFF3F1F58)]));
    canvas.drawPath(body, _line(const Color(0xFF2E1642), math.max(1, r * .05)));
    // 빛 반사
    canvas.drawOval(Rect.fromCenter(center: c.translate(-r * .32, -r * .12), width: r * .28, height: r * .5), Paint()..color = const Color(0x55FFFFFF));
    // 세로 결
    for (final dx in const [-.3, 0.0, .3]) {
      canvas.drawLine(Offset(c.dx + r * dx, c.dy - r * .3), Offset(c.dx + r * dx * 1.2, c.dy + r * .62), _line(const Color(0x33FFFFFF), math.max(.8, r * .03)));
    }
    // 꽃눈
    canvas.drawCircle(c.translate(0, r * .82), r * .09, Paint()..color = const Color(0xFFE9B8D8));
    // 줄기와 잎
    canvas.drawLine(Offset(c.dx, c.dy - r * .84), Offset(c.dx + r * .06, c.dy - r * 1.04), _line(const Color(0xFF5A8F2E), math.max(2.5, r * .12)));
    _leafBlade(canvas, Offset(c.dx + r * .06, c.dy - r * 1.0), -.7, r * .5, r * .22, const [Color(0xFF7FC450), Color(0xFF3F8F2E)]);
  }

  Paint _grad(Rect rect, List<Color> colors, {Alignment begin = Alignment.topLeft, Alignment end = Alignment.bottomRight}) =>
      Paint()..shader = LinearGradient(begin: begin, end: end, colors: colors).createShader(rect);

  Paint _line(Color color, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _leafBlade(Canvas canvas, Offset base, double angle, double len, double wid, List<Color> colors) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(-wid, -len * .3, -wid * .8, -len * .8, 0, -len)
      ..cubicTo(wid * .8, -len * .8, wid, -len * .3, 0, 0)
      ..close();
    final rect = Rect.fromLTRB(-wid, -len, wid, 0);
    canvas.drawPath(path, _grad(rect, colors, begin: Alignment.bottomCenter, end: Alignment.topCenter));
    canvas.drawPath(path, _line(const Color(0xFF2F7A26), math.max(1, wid * .12)));
    canvas.drawLine(Offset.zero, Offset(0, -len * .85), _line(const Color(0x88E9F8C8), math.max(.8, wid * .08)));
    canvas.restore();
  }

  // 무: 하얗고 길쭉한 뿌리 + 위에 초록 잎
  void _radish(Canvas canvas, Offset c, double r) {
    final top = c.translate(0, -r * .1);
    for (final a in const [-.55, 0.0, .55]) {
      _leafBlade(canvas, top, a, r * (a == 0 ? 1.0 : .88), r * .2, const [Color(0xFF3F8F2E), Color(0xFF8CCB55)]);
    }
    final root = Path()
      ..moveTo(c.dx - r * .34, c.dy - r * .08)
      ..cubicTo(c.dx - r * .46, c.dy + r * .35, c.dx - r * .18, c.dy + r * .78, c.dx, c.dy + r * .9)
      ..cubicTo(c.dx + r * .18, c.dy + r * .78, c.dx + r * .46, c.dy + r * .35, c.dx + r * .34, c.dy - r * .08)
      ..cubicTo(c.dx + r * .2, c.dy - r * .2, c.dx - r * .2, c.dy - r * .2, c.dx - r * .34, c.dy - r * .08)
      ..close();
    final rect = Rect.fromLTRB(c.dx - r * .5, c.dy - r * .2, c.dx + r * .5, c.dy + r * .9);
    canvas.drawPath(root, _grad(rect, const [Color(0xFFFFFFFF), Color(0xFFE9EEF2), Color(0xFFCBD5DD)], begin: Alignment.topLeft, end: Alignment.bottomRight));
    canvas.drawPath(root, _line(const Color(0xFF9FB0BC), r * .03));
    // 연두색 목 부분
    canvas.drawArc(Rect.fromCenter(center: c.translate(0, -r * .1), width: r * .68, height: r * .3), math.pi, math.pi, false, _line(const Color(0xFF9CCF63), r * .09));
    canvas.drawCircle(c.translate(-r * .14, r * .1), r * .05, Paint()..color = const Color(0x99FFFFFF));
  }

  // 양파: 황갈색 둥근 몸통 + 뾰족한 윗부분 + 초록 싹 + 잔뿌리
  void _onion(Canvas canvas, Offset c, double r) {
    for (final a in const [-.28, .0, .28]) {
      _leafBlade(canvas, c.translate(0, -r * .62), a, r * .62, r * .1, const [Color(0xFF4F9A34), Color(0xFF9AD562)]);
    }
    final body = Path()
      ..moveTo(c.dx, c.dy - r * .78)
      ..cubicTo(c.dx + r * .16, c.dy - r * .52, c.dx + r * .86, c.dy - r * .34, c.dx + r * .78, c.dy + r * .22)
      ..cubicTo(c.dx + r * .7, c.dy + r * .68, c.dx + r * .3, c.dy + r * .84, c.dx, c.dy + r * .84)
      ..cubicTo(c.dx - r * .3, c.dy + r * .84, c.dx - r * .7, c.dy + r * .68, c.dx - r * .78, c.dy + r * .22)
      ..cubicTo(c.dx - r * .86, c.dy - r * .34, c.dx - r * .16, c.dy - r * .52, c.dx, c.dy - r * .78)
      ..close();
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(body, _grad(rect, const [Color(0xFFF3C77A), Color(0xFFD9993F), Color(0xFFB87424)]));
    canvas.drawPath(body, _line(const Color(0xFF8C5A1C), r * .035));
    for (final k in const [-.42, -.2, .2, .42]) {
      final p = Path()
        ..moveTo(c.dx + r * k * .12, c.dy - r * .66)
        ..quadraticBezierTo(c.dx + r * k * 1.7, c.dy + r * .05, c.dx + r * k * .8, c.dy + r * .8);
      canvas.drawPath(p, _line(const Color(0x66FFF1C8), r * .03));
    }
    // 잔뿌리
    for (final k in const [-.16, -.05, .06, .17]) {
      canvas.drawLine(c.translate(r * k, r * .84), c.translate(r * k * 1.7, r * .98), _line(const Color(0xFFF5E6C8), r * .025));
    }
    canvas.drawCircle(c.translate(-r * .3, -r * .1), r * .07, Paint()..color = const Color(0x99FFFFFF));
  }

  // 사과: 빨간 둥근 열매 + 위쪽 홈 + 갈색 꼭지 + 초록 잎
  void _apple(Canvas canvas, Offset c, double r) {
    final body = Path()
      ..moveTo(c.dx, c.dy - r * .52)
      ..cubicTo(c.dx + r * .3, c.dy - r * .86, c.dx + r * 1.0, c.dy - r * .5, c.dx + r * .86, c.dy + r * .18)
      ..cubicTo(c.dx + r * .76, c.dy + r * .72, c.dx + r * .34, c.dy + r * .92, c.dx, c.dy + r * .82)
      ..cubicTo(c.dx - r * .34, c.dy + r * .92, c.dx - r * .76, c.dy + r * .72, c.dx - r * .86, c.dy + r * .18)
      ..cubicTo(c.dx - r * 1.0, c.dy - r * .5, c.dx - r * .3, c.dy - r * .86, c.dx, c.dy - r * .52)
      ..close();
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(body, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), radius: 1.0, colors: [Color(0xFFFF9A8A), Color(0xFFC81E3A), Color(0xFF8E1230)], stops: [0, .55, 1]).createShader(rect));
    // 사과는 아래쪽이 노랗게 물든 후지 사과 → 토마토(주황빛 빨강)와 한눈에 구별된다
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(Rect.fromLTWH(c.dx - r, c.dy + r * .15, r * 2, r * .85), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFD34E), Color(0xCCFFD34E)]).createShader(Rect.fromLTWH(c.dx - r, c.dy + r * .15, r * 2, r * .85)));
    canvas.restore();
    canvas.drawPath(body, _line(const Color(0xFF7A1230), r * .035));
    canvas.drawLine(c.translate(0, -r * .5), c.translate(r * .08, -r * .92), _line(const Color(0xFF7A4A21), r * .08));
    _leafBlade(canvas, c.translate(r * .1, -r * .78), 1.05, r * .5, r * .17, const [Color(0xFF3F8F2E), Color(0xFF8CCB55)]);
    canvas.drawOval(Rect.fromCenter(center: c.translate(-r * .38, -r * .22), width: r * .22, height: r * .34), Paint()..color = const Color(0x88FFFFFF));
  }

  // 토마토: 살짝 납작한 빨간 열매 + 초록 별 모양 꼭지
  void _tomato(Canvas canvas, Offset c, double r) {
    final body = Rect.fromCenter(center: c.translate(0, r * .08), width: r * 1.8, height: r * 1.55);
    canvas.drawOval(body, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.45), radius: 1.0, colors: [Color(0xFFFF8A55), Color(0xFFF03C1C), Color(0xFFC22A10)], stops: [0, .55, 1]).createShader(body));
    canvas.drawOval(body, _line(const Color(0xFF8E1713), r * .035));
    // 꼭지(초록 별)
    final star = Path();
    final sc = c.translate(0, -r * .62);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final tip = sc + Offset(math.cos(a) * r * .5, math.sin(a) * r * .34);
      final l = sc + Offset(math.cos(a - .5) * r * .12, math.sin(a - .5) * r * .08);
      final rr = sc + Offset(math.cos(a + .5) * r * .12, math.sin(a + .5) * r * .08);
      star
        ..moveTo(l.dx, l.dy)
        ..quadraticBezierTo(tip.dx * .6 + sc.dx * .4, tip.dy * .6 + sc.dy * .4 - r * .08, tip.dx, tip.dy)
        ..quadraticBezierTo(tip.dx * .6 + sc.dx * .4, tip.dy * .6 + sc.dy * .4 + r * .1, rr.dx, rr.dy)
        ..close();
    }
    canvas.drawPath(star, Paint()..color = const Color(0xFF3F9E35));
    canvas.drawPath(star, _line(const Color(0xFF2A7425), r * .02));
    canvas.drawLine(sc, sc.translate(0, -r * .26), _line(const Color(0xFF3B8A2E), r * .07));
    canvas.drawOval(Rect.fromCenter(center: c.translate(-r * .5, -r * .12), width: r * .26, height: r * .4), Paint()..color = const Color(0x88FFFFFF));
  }

  // 감자: 황갈색 울퉁불퉁한 덩이 두 개 + 눈(점)
  void _potato(Canvas canvas, Offset c, double r) {
    void spud(Offset at, double w, double h, double rot) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(rot);
      final path = Path()
        ..moveTo(-w * .5, 0)
        ..cubicTo(-w * .5, -h * .62, -w * .12, -h * .56, w * .1, -h * .52)
        ..cubicTo(w * .5, -h * .48, w * .62, -h * .08, w * .5, h * .2)
        ..cubicTo(w * .42, h * .58, w * .05, h * .56, -w * .2, h * .5)
        ..cubicTo(-w * .5, h * .42, -w * .5, h * .2, -w * .5, 0)
        ..close();
      final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawPath(path, _grad(rect, const [Color(0xFFE7C58A), Color(0xFFC9975A), Color(0xFFA9763C)]));
      canvas.drawPath(path, _line(const Color(0xFF7C5226), r * .035));
      for (final e in const [(-.2, -.12), (.2, .08), (-.05, .26), (.28, -.26)]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(w * e.$1, h * e.$2), width: w * .1, height: h * .07), Paint()..color = const Color(0xFF8C6030));
      }
      canvas.restore();
    }

    spud(c.translate(-r * .24, r * .3), r * 1.18, r * .86, -.18);
    spud(c.translate(r * .34, -r * .04), r * 1.0, r * .76, .3);
    canvas.drawOval(Rect.fromCenter(center: c.translate(-r * .5, r * .12), width: r * .2, height: r * .1), Paint()..color = const Color(0x66FFFFFF));
  }

  @override
  bool shouldRepaint(VeggiePainter old) => old.code != code || old.scale != scale;
}
