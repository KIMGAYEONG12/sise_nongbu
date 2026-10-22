import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/home_rules.dart';

/// 농장 하우스 → 아파트 그림 (시안: 1~4레벨 하우스 → 기본·중형·대형·프리미엄·럭셔리·스카이 아파트).
/// 모두 코드로 그린 벡터라 둘러보기 화면에서 크게 확대해도 선명하다.
/// 둥근 풀밭 섬 위에 건물·나무·울타리·꽃이 있고, [anim]이 있으면 굴뚝 연기·반짝임·나무가 살랑인다.
class HomeBuildingPainter extends CustomPainter {
  HomeBuildingPainter({required this.stage, this.anim}) : super(repaint: anim);

  /// 하우스 단계 (greenhouseStage). 1~4 하우스, 5~10 아파트, 그 위는 스카이 아파트
  final int stage;
  final Animation<double>? anim;

  static const _outline = Color(0xFF5A3A28);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim?.value ?? 0.0;
    final lv = homeLevelOf(stage);
    final apt = isApartmentStage(stage);
    final u = math.min(w, h);
    final sw = math.max(.8, u * .006);

    _island(canvas, w, h, apt);
    _backTrees(canvas, w, h, t, lv);
    if (apt) {
      _apartment(canvas, w, h, lv, t, sw);
    } else {
      _house(canvas, w, h, lv, t, sw);
    }
    _frontDecor(canvas, w, h, lv, apt, t);
    if (lv >= 8 || stage > homeLevels.length) _sparkles(canvas, w, h, t);
  }

  // ───────────────────────── 바닥 섬 ─────────────────────────

  void _island(Canvas canvas, double w, double h, bool apt) {
    final c = Offset(w * .5, h * .86);
    // 흙 두께 + 그림자
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, h * .045), width: w * .96, height: h * .2), Paint()..color = const Color(0x22000000));
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, h * .025), width: w * .94, height: h * .21), Paint()..color = const Color(0xFF9A6B3F));
    final top = Rect.fromCenter(center: c, width: w * .94, height: h * .21);
    canvas.drawOval(top, Paint()..shader = const RadialGradient(center: Alignment(-.2, -.4), radius: .9, colors: [Color(0xFFB4E27A), Color(0xFF7CC352), Color(0xFF5CA83E)], stops: [0, .6, 1]).createShader(top));
    // 아파트는 앞마당이 돌바닥 광장
    if (apt) {
      final plaza = Rect.fromCenter(center: c + Offset(0, h * .015), width: w * .58, height: h * .1);
      canvas.drawOval(plaza, Paint()..color = const Color(0xFFE9DFCB));
      canvas.drawOval(plaza, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(.8, w * .004)..color = const Color(0xFFC9B99A));
    }
  }

  // ───────────────────────── 나무 ─────────────────────────

  static void tree(Canvas canvas, Offset foot, double r, {double sway = 0, Color? blossom}) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: foot - Offset(0, r * .45), width: r * .28, height: r * .9), Radius.circular(r * .08)), Paint()..color = const Color(0xFF7A4E2A));
    final top = foot - Offset(-sway * r * .08, r * 1.35);
    final dark = blossom == null ? const Color(0xFF3E8E3A) : Color.lerp(blossom, Colors.black, .2)!;
    final mid = blossom ?? const Color(0xFF5DB04A);
    final lite = blossom == null ? const Color(0xFF8AD06A) : Color.lerp(blossom, Colors.white, .35)!;
    canvas.drawCircle(top + Offset(-r * .42, r * .25), r * .55, Paint()..color = dark);
    canvas.drawCircle(top + Offset(r * .45, r * .22), r * .55, Paint()..color = dark);
    canvas.drawCircle(top, r * .7, Paint()..color = mid);
    canvas.drawCircle(top + Offset(-r * .2, -r * .25), r * .38, Paint()..color = lite);
    canvas.drawCircle(top + Offset(r * .32, -r * .05), r * .22, Paint()..color = lite.withValues(alpha: .8));
  }

  void _backTrees(Canvas canvas, double w, double h, double t, int lv) {
    final s = math.sin(t * math.pi * 2);
    final pink = lv >= 5 ? const Color(0xFFF2A7C8) : null; // 아파트는 시안처럼 분홍 꽃나무
    tree(canvas, Offset(w * .12, h * .82), w * .085, sway: s);
    tree(canvas, Offset(w * .2, h * .76), w * .07, sway: -s, blossom: pink);
    tree(canvas, Offset(w * .86, h * .8), w * .085, sway: -s);
    tree(canvas, Offset(w * .79, h * .74), w * .065, sway: s, blossom: lv >= 7 ? pink : null);
  }

  // ───────────────────────── 하우스 (1~4) ─────────────────────────

  void _house(Canvas canvas, double w, double h, int lv, double t, double sw) {
    final i = lv - 1;
    final bw = w * const [.3, .33, .35, .36][i]; // 앞면 폭
    final side = w * const [.2, .22, .25, .26][i]; // 옆면 폭
    final wallH = h * const [.19, .21, .3, .32][i];
    final roofBlue = lv == 2 || lv == 4;
    final roofTop = roofBlue ? const Color(0xFF4F7FD6) : const Color(0xFFE5513F);
    final roofBot = roofBlue ? const Color(0xFF2F57A8) : const Color(0xFFB8352A);
    final base = h * .84;
    final x0 = w * .5 - (bw + side) / 2 - (lv == 4 ? w * .05 : 0);
    final dy = side * .38; // 옆면이 뒤로 갈수록 올라가는 높이
    final dv = Offset(side, -dy);
    final top = base - wallH;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..color = _outline;

    // 4단계: 옆에 붙은 유리 온실 (집 뒤쪽이라 먼저 그린다)
    if (lv == 4) _glassAnnex(canvas, Offset(x0 + bw + side * .35, base - dy * .35), w * .2, h * .15, sw);

    // 옆면 벽
    Offset sp(double uu, double vv) => Offset(x0 + bw + uu * side, base - uu * dy - vv * wallH);
    final sideWall = Path()..addPolygon([sp(0, 0), sp(1, 0), sp(1, 1), sp(0, 1)], true);
    canvas.drawPath(sideWall, Paint()..shader = const LinearGradient(colors: [Color(0xFFEBDDC3), Color(0xFFD9C6A4)]).createShader(sideWall.getBounds()));
    canvas.drawPath(sideWall, line);
    // 옆면 창문
    final sideWins = lv >= 3 ? [(.25, .58, .12, .42), (.25, .58, .6, .88)] : [(.3, .7, .3, .7)];
    for (final wv in sideWins) {
      _quadWindow(canvas, [sp(wv.$1, wv.$3), sp(wv.$2, wv.$3), sp(wv.$2, wv.$4), sp(wv.$1, wv.$4)], sw);
    }

    // 앞면 벽 + 박공
    final roofH = bw * .52;
    final apex = Offset(x0 + bw / 2, top - roofH);
    final front = Path()
      ..moveTo(x0, base)
      ..lineTo(x0, top)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(x0 + bw, top)
      ..lineTo(x0 + bw, base)
      ..close();
    canvas.drawPath(front, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF6E4), Color(0xFFF1E2C4)]).createShader(front.getBounds()));
    // 3단계부터는 나무 기둥 무늬(반목조)
    if (lv >= 3) {
      final beam = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 2.4
        ..color = const Color(0xFF8A5A33);
      canvas.drawLine(Offset(x0, top + wallH * .5), Offset(x0 + bw, top + wallH * .5), beam);
      canvas.drawLine(Offset(x0 + bw * .08, top), Offset(x0 + bw * .08, base), beam);
      canvas.drawLine(Offset(x0 + bw * .92, top), Offset(x0 + bw * .92, base), beam);
      canvas.drawLine(Offset(apex.dx, apex.dy + roofH * .25), Offset(apex.dx, top), beam);
    }
    canvas.drawPath(front, line);
    // 기초 돌
    canvas.drawRect(Rect.fromLTWH(x0, base - h * .018, bw, h * .018), Paint()..color = const Color(0xFFB9B3A8));
    canvas.drawRect(Rect.fromLTWH(x0, base - h * .018, bw, h * .018), line);

    // 옆 지붕 (오른쪽 경사면): 박공 꼭대기 → 처마
    final over = bw * .07;
    final eaveR = Offset(x0 + bw + over, top + h * .014);
    final eaveL = Offset(x0 - over, top + h * .014);
    final roof = Path()..addPolygon([apex, apex + dv, eaveR + dv, eaveR], true);
    canvas.drawPath(roof, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [roofTop, roofBot]).createShader(roof.getBounds()));
    // 기와 줄: 처마와 나란한 줄 + 비늘 무늬
    final tile = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * .8
      ..color = Color.lerp(roofBot, Colors.black, .25)!.withValues(alpha: .7);
    for (var k = 1; k < 6; k++) {
      final p = Offset.lerp(apex, eaveR, k / 6)!;
      canvas.drawLine(p, p + dv, tile);
      for (var m = 0; m < 6; m++) {
        final q = p + dv * ((m + .5) / 6);
        canvas.drawArc(Rect.fromCircle(center: q - Offset(0, h * .006), radius: side / 14), .2, math.pi - .4, false, tile);
      }
    }
    // 지붕 윗선 반짝임
    canvas.drawLine(apex + Offset(0, h * .006), apex + dv + Offset(0, h * .006), Paint()..strokeWidth = sw * 1.6..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: .35));
    canvas.drawPath(roof, line);
    // 앞 박공 처마 테두리 (지붕 색 띠)
    final trim = Path()
      ..moveTo(eaveL.dx, eaveL.dy)
      ..lineTo(apex.dx, apex.dy - h * .012)
      ..lineTo(eaveR.dx, eaveR.dy)
      ..lineTo(eaveR.dx - over * .3, eaveR.dy + h * .016)
      ..lineTo(apex.dx, apex.dy + h * .01)
      ..lineTo(eaveL.dx + over * .3, eaveL.dy + h * .016)
      ..close();
    canvas.drawPath(trim, Paint()..color = roofBot);
    canvas.drawPath(trim, line);

    // 지붕창 (2단계부터)
    Offset rp(double s, double tt) => apex + (eaveR - apex) * s + dv * tt;
    if (lv >= 2) _dormer(canvas, rp(.55, .45), bw * .22, roofTop, roofBot, sw);
    // 굴뚝 + 연기
    final chim = rp(.35, .78);
    final cw = w * .035, chH = h * .075;
    final chRect = Rect.fromLTWH(chim.dx - cw / 2, chim.dy - chH, cw, chH);
    canvas.drawRect(chRect, Paint()..color = const Color(0xFFB8664A));
    canvas.drawRect(chRect, line);
    canvas.drawRect(Rect.fromLTWH(chRect.left - cw * .15, chRect.top - h * .012, cw * 1.3, h * .014), Paint()..color = const Color(0xFF7E4632));
    for (var k = 0; k < 3; k++) {
      final p = ((t * 2 + k / 3) % 1.0);
      canvas.drawCircle(Offset(chRect.center.dx + math.sin(p * 6) * w * .012 + p * w * .03, chRect.top - h * .02 - p * h * .1), w * (.012 + p * .02), Paint()..color = Colors.white.withValues(alpha: .7 * (1 - p)));
    }

    // 앞면: 문 + 창문
    final doorW = bw * .24, doorH = math.min(wallH * (lv >= 3 ? .42 : .62), h * .12);
    final doorX = lv == 1 ? x0 + bw * .2 : x0 + bw / 2 - doorW / 2;
    _door(canvas, Rect.fromLTWH(doorX, base - doorH - h * .018, doorW, doorH), sw);
    if (lv == 1) {
      _window(canvas, Rect.fromLTWH(x0 + bw * .56, top + wallH * .25, bw * .3, wallH * .32), sw, flowers: true);
    } else {
      final wy = lv >= 3 ? top + wallH * .62 : top + wallH * .28;
      final wh = wallH * (lv >= 3 ? .2 : .3);
      _window(canvas, Rect.fromLTWH(x0 + bw * .1, wy, bw * .22, wh), sw, flowers: true);
      _window(canvas, Rect.fromLTWH(x0 + bw * .68, wy, bw * .22, wh), sw, flowers: true);
    }
    if (lv >= 3) {
      // 2층 창문 + 발코니
      _window(canvas, Rect.fromLTWH(x0 + bw * .18, top + wallH * .1, bw * .22, wallH * .22), sw);
      _window(canvas, Rect.fromLTWH(x0 + bw * .6, top + wallH * .1, bw * .22, wallH * .22), sw);
      _window(canvas, Rect.fromLTWH(apex.dx - bw * .08, top - roofH * .55, bw * .16, roofH * .32), sw, round: true);
      _balcony(canvas, Rect.fromLTWH(x0 + bw * .04, top + wallH * .34, bw * .92, wallH * .14), sw);
    } else {
      // 박공의 둥근 다락 창
      _window(canvas, Rect.fromLTWH(apex.dx - bw * .08, top - roofH * .62, bw * .16, roofH * .36), sw, round: true);
    }
  }

  /// 창문 (흰 창틀 + 십자 창살 + 하늘빛 유리 + 반짝임). [flowers]면 아래 꽃상자.
  static void _window(Canvas canvas, Rect r, double sw, {bool flowers = false, bool round = false}) {
    final frame = round ? RRect.fromRectAndCorners(r, topLeft: Radius.circular(r.width / 2), topRight: Radius.circular(r.width / 2)) : RRect.fromRectAndRadius(r, Radius.circular(r.width * .06));
    canvas.drawRRect(frame.inflate(r.width * .08), Paint()..color = Colors.white);
    canvas.drawRRect(frame.inflate(r.width * .08), Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = _outline);
    canvas.drawRRect(frame, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFBFE6FF), Color(0xFF6FB3E8)]).createShader(r));
    final bar = Paint()
      ..strokeWidth = math.max(.8, r.width * .07)
      ..color = Colors.white;
    canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), bar);
    canvas.drawLine(Offset(r.left, r.center.dy + (round ? r.height * .1 : 0)), Offset(r.right, r.center.dy + (round ? r.height * .1 : 0)), bar);
    canvas.drawLine(r.topLeft + Offset(r.width * .15, r.height * .55), r.topLeft + Offset(r.width * .4, r.height * .15), Paint()..strokeWidth = math.max(.8, r.width * .06)..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: .6));
    if (flowers) {
      final box = Rect.fromLTWH(r.left - r.width * .1, r.bottom + r.width * .06, r.width * 1.2, r.height * .2);
      canvas.drawRect(box, Paint()..color = const Color(0xFF9A6234));
      canvas.drawRect(box, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .8..color = _outline);
      for (var k = 0; k < 5; k++) {
        final c = Offset(box.left + box.width * (k + .5) / 5, box.top - box.height * .1);
        canvas.drawCircle(c, box.height * .55, Paint()..color = const Color(0xFF4FA043));
        canvas.drawCircle(c + Offset(0, -box.height * .2), box.height * .3, Paint()..color = k.isEven ? const Color(0xFFFF6F91) : Colors.white);
      }
    }
  }

  /// 기울어진 창문 (옆면용 네 점)
  static void _quadWindow(Canvas canvas, List<Offset> q, double sw) {
    final p = Path()..addPolygon(q, true);
    final outer = Path()..addPolygon([for (final o in q) o + (o - _center(q)) * .18], true);
    canvas.drawPath(outer, Paint()..color = Colors.white);
    canvas.drawPath(outer, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = _outline);
    canvas.drawPath(p, Paint()..shader = const LinearGradient(colors: [Color(0xFFA9D8F5), Color(0xFF5E9FD6)]).createShader(p.getBounds()));
    final bar = Paint()
      ..strokeWidth = sw * 1.2
      ..color = Colors.white;
    canvas.drawLine(Offset.lerp(q[0], q[1], .5)!, Offset.lerp(q[3], q[2], .5)!, bar);
    canvas.drawLine(Offset.lerp(q[0], q[3], .5)!, Offset.lerp(q[1], q[2], .5)!, bar);
  }

  static Offset _center(List<Offset> q) => q.fold(Offset.zero, (a, b) => a + b) / q.length.toDouble();

  static void _door(Canvas canvas, Rect r, double sw) {
    final d = RRect.fromRectAndCorners(r, topLeft: Radius.circular(r.width / 2), topRight: Radius.circular(r.width / 2));
    canvas.drawRRect(d.inflate(r.width * .08), Paint()..color = const Color(0xFF7A4A2A));
    canvas.drawRRect(d, Paint()..shader = const LinearGradient(colors: [Color(0xFFB27546), Color(0xFF8A5530)]).createShader(r));
    canvas.drawRRect(d, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = _outline);
    final plank = Paint()
      ..strokeWidth = sw * .7
      ..color = const Color(0xFF6E4024);
    canvas.drawLine(Offset(r.left + r.width / 3, r.top + r.width * .3), Offset(r.left + r.width / 3, r.bottom), plank);
    canvas.drawLine(Offset(r.left + r.width * 2 / 3, r.top + r.width * .3), Offset(r.left + r.width * 2 / 3, r.bottom), plank);
    // 작은 창 + 손잡이
    canvas.drawCircle(Offset(r.center.dx, r.top + r.width * .45), r.width * .16, Paint()..color = const Color(0xFFBFE6FF));
    canvas.drawCircle(Offset(r.right - r.width * .2, r.center.dy + r.height * .1), r.width * .07, Paint()..color = const Color(0xFFFFD34D));
    // 계단 돌
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left - r.width * .2, r.bottom, r.width * 1.4, r.height * .1), Radius.circular(r.width * .05)), Paint()..color = const Color(0xFFCFC8BC));
  }

  static void _dormer(Canvas canvas, Offset foot, double dw, Color roofTop, Color roofBot, double sw) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..color = _outline;
    final body = Rect.fromLTWH(foot.dx - dw / 2, foot.dy - dw * .8, dw, dw * .8);
    canvas.drawRect(body, Paint()..color = const Color(0xFFFFF3DC));
    canvas.drawRect(body, line);
    _window(canvas, body.deflate(dw * .2), sw);
    final cap = Path()
      ..moveTo(body.left - dw * .15, body.top + dw * .05)
      ..lineTo(body.center.dx, body.top - dw * .45)
      ..lineTo(body.right + dw * .15, body.top + dw * .05)
      ..close();
    canvas.drawPath(cap, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [roofTop, roofBot]).createShader(cap.getBounds()));
    canvas.drawPath(cap, line);
  }

  static void _balcony(Canvas canvas, Rect r, double sw) {
    final wood = Paint()..color = const Color(0xFF9A6234);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..color = _outline;
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - r.height * .2, r.width, r.height * .2), wood);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * .16), wood);
    for (var k = 0; k <= 10; k++) {
      final x = r.left + r.width * k / 10;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), Paint()..strokeWidth = math.max(.8, r.width * .012)..color = const Color(0xFF8A5530));
    }
    canvas.drawRect(r, line);
    // 난간 위 화분
    for (final fx in [.15, .85]) {
      final c = Offset(r.left + r.width * fx, r.top - r.height * .25);
      canvas.drawCircle(c, r.height * .45, Paint()..color = const Color(0xFF4FA043));
      canvas.drawCircle(c + Offset(r.height * .15, -r.height * .1), r.height * .2, Paint()..color = const Color(0xFFFF8FB1));
    }
  }

  /// 4단계 하우스 옆 유리 온실
  static void _glassAnnex(Canvas canvas, Offset foot, double gw, double gh, double sw) {
    final r = Rect.fromLTWH(foot.dx, foot.dy - gh, gw, gh);
    final glass = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFFDFF4FF).withValues(alpha: .95), const Color(0xFF8CCBE8).withValues(alpha: .9)]).createShader(r);
    canvas.drawRect(r, glass);
    final roof = Path()
      ..moveTo(r.left - gw * .04, r.top)
      ..lineTo(r.left + gw * .5, r.top - gh * .4)
      ..lineTo(r.right + gw * .04, r.top)
      ..close();
    canvas.drawPath(roof, glass);
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 1.2
      ..color = Colors.white;
    for (var k = 1; k < 4; k++) {
      final x = r.left + gw * k / 4;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), frame);
    }
    canvas.drawLine(Offset(r.left, r.top + gh * .5), Offset(r.right, r.top + gh * .5), frame);
    // 안의 초록 작물
    for (var k = 0; k < 4; k++) {
      canvas.drawCircle(Offset(r.left + gw * (k + .5) / 4, r.bottom - gh * .14), gw * .07, Paint()..color = const Color(0xFF5DB04A));
    }
    canvas.drawRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = const Color(0xFF4F6A78));
    canvas.drawPath(roof, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = const Color(0xFF4F6A78));
  }

  // ───────────────────────── 아파트 (5~10) ─────────────────────────

  void _apartment(Canvas canvas, double w, double h, int lv, double t, double sw) {
    final i = lv - firstApartmentLevel; // 0~5
    final sky = lv == homeLevels.length;
    final floors = const [4, 5, 6, 7, 8, 11][i];
    final fw = w * const [.34, .36, .38, .4, .42, .3][i];
    final side = w * const [.2, .21, .22, .23, .24, .2][i];
    final base = h * .84;
    final maxH = h * .74;
    final floorH = math.min(h * .075, maxH / (floors + .8));
    final bodyH = floorH * floors;
    final x0 = w * .5 - (fw + side) / 2;
    final dy = side * .38;
    final dv = Offset(side, -dy);
    final top = base - bodyH;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF4A4038);
    final wallA = sky ? const Color(0xFFDCEBFA) : const Color(0xFFF7EBD6);
    final wallB = sky ? const Color(0xFFB9D3EE) : const Color(0xFFE9D6B8);
    final trim = lv == 8 ? const Color(0xFFE98FA8) : const Color(0xFF4D6A94); // 프리미엄은 분홍 띠
    Offset sp(double uu, double vv) => Offset(x0 + fw + uu * side, base - uu * dy - vv * bodyH);

    // 옆면
    final sideWall = Path()..addPolygon([sp(0, 0), sp(1, 0), sp(1, 1), sp(0, 1)], true);
    canvas.drawPath(sideWall, Paint()..shader = LinearGradient(colors: [Color.lerp(wallB, Colors.black, .04)!, Color.lerp(wallB, Colors.black, .12)!]).createShader(sideWall.getBounds()));
    const sideCols = 2;
    for (var f = 0; f < floors; f++) {
      for (var cIdx = 0; cIdx < sideCols; cIdx++) {
        final u0 = .14 + cIdx * .44, u1 = u0 + .3;
        final v0 = (f + .25) / floors, v1 = (f + .75) / floors;
        _aptGlassQuad(canvas, [sp(u0, v0), sp(u1, v0), sp(u1, v1), sp(u0, v1)], sky, sw);
      }
    }
    canvas.drawPath(sideWall, line);

    // 앞면
    final front = Rect.fromLTWH(x0, top, fw, bodyH);
    canvas.drawRect(front, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [wallA, wallB]).createShader(front));
    if (sky) {
      // 스카이 아파트: 통유리 벽 + 비치는 하늘
      final g = front.deflate(fw * .06);
      canvas.drawRect(g, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9FD3FF), Color(0xFF3F86D6), Color(0xFF7FC0F5)], stops: [0, .6, 1]).createShader(g));
      final mul = Paint()
        ..strokeWidth = sw
        ..color = Colors.white.withValues(alpha: .8);
      for (var f = 1; f < floors; f++) {
        canvas.drawLine(Offset(g.left, g.top + g.height * f / floors), Offset(g.right, g.top + g.height * f / floors), mul);
      }
      for (var k = 1; k < 4; k++) {
        canvas.drawLine(Offset(g.left + g.width * k / 4, g.top), Offset(g.left + g.width * k / 4, g.bottom), mul);
      }
      // 반사 빛줄기 (천천히 지나간다)
      final rx = g.left + g.width * ((t * 1.3) % 1.4 - .2);
      canvas.save();
      canvas.clipRect(g);
      canvas.drawPath(
          Path()
            ..moveTo(rx, g.bottom)
            ..lineTo(rx + g.width * .25, g.bottom)
            ..lineTo(rx + g.width * .55, g.top)
            ..lineTo(rx + g.width * .3, g.top)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: .28));
      canvas.restore();
    } else {
      final cols = fw > w * .37 ? 4 : 3;
      for (var f = 0; f < floors; f++) {
        final fy = base - floorH * (f + 1);
        for (var cIdx = 0; cIdx < cols; cIdx++) {
          final cw = fw / cols;
          final r = Rect.fromLTWH(x0 + cw * cIdx + cw * .18, fy + floorH * .18, cw * .64, floorH * .56);
          if (f == 0 && (cIdx == cols ~/ 2 || (cols == 4 && cIdx == 1))) continue; // 1층 가운데는 현관
          _aptWindow(canvas, r, sw);
          // 발코니: 한 칸 건너 하나씩 난간 + 화분
          if (f > 0 && (cIdx + f).isEven) _aptBalcony(canvas, Rect.fromLTWH(r.left - cw * .08, r.bottom - floorH * .16, r.width + cw * .16, floorH * .22), sw, f % 3 == 0);
        }
        // 층 구분 띠
        canvas.drawLine(Offset(x0, fy), Offset(x0 + fw, fy), Paint()..strokeWidth = sw..color = const Color(0xFFD9C4A0));
      }
      // 현관: 파란 아치 차양 + 101 표지
      final ew = fw * (cols == 4 ? .42 : .3);
      final er = Rect.fromLTWH(x0 + fw / 2 - ew / 2, base - floorH * .95, ew, floorH * .95);
      canvas.drawRect(er, Paint()..color = const Color(0xFF6B8FB5));
      final gl = er.deflate(ew * .12);
      canvas.drawRect(Rect.fromLTWH(gl.left, gl.top + floorH * .1, gl.width, gl.height - floorH * .1), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFCFEAFF), Color(0xFF7DB7E2)]).createShader(gl));
      canvas.drawLine(Offset(gl.center.dx, gl.top + floorH * .1), Offset(gl.center.dx, gl.bottom), Paint()..strokeWidth = sw..color = Colors.white);
      final canopy = Path()
        ..moveTo(er.left - ew * .12, er.top + floorH * .05)
        ..quadraticBezierTo(er.center.dx, er.top - floorH * .38, er.right + ew * .12, er.top + floorH * .05)
        ..close();
      canvas.drawPath(canopy, Paint()..color = trim);
      canvas.drawPath(canopy, line);
      _label(canvas, '101', Offset(er.center.dx, er.top - floorH * .08), floorH * .2, const Color(0xFFFFE9A8));
      canvas.drawRect(er, line);
    }
    canvas.drawRect(front, line);

    // 옥상: 지붕 띠(코니스) + 윗면
    final roofTopPath = Path()..addPolygon([Offset(x0, top), Offset(x0 + fw, top), Offset(x0 + fw, top) + dv, Offset(x0, top) + dv], true);
    canvas.drawPath(roofTopPath, Paint()..color = sky ? const Color(0xFFCAD7E3) : const Color(0xFFD8D2C6));
    canvas.drawPath(roofTopPath, line);
    final cornice = Rect.fromLTWH(x0 - fw * .03, top - floorH * .14, fw * 1.06, floorH * .18);
    canvas.drawRect(cornice, Paint()..color = trim);
    canvas.drawRect(cornice, line);
    final corniceSide = Path()..addPolygon([cornice.topRight, cornice.topRight + dv, cornice.bottomRight + dv, cornice.bottomRight], true);
    canvas.drawPath(corniceSide, Paint()..color = Color.lerp(trim, Colors.black, .25)!);
    canvas.drawPath(corniceSide, line);
    Offset rp(double a, double b) => Offset(x0 + fw * a, top - floorH * .14) + dv * b;

    if (lv == 9) {
      // 럭셔리: 옥상 수영장 + 파라솔
      final pool = Path()..addPolygon([rp(.12, .25), rp(.6, .25), rp(.6, .75), rp(.12, .75)], true);
      canvas.drawPath(pool, Paint()..shader = const LinearGradient(colors: [Color(0xFF7FE0F5), Color(0xFF2DA7D8)]).createShader(pool.getBounds()));
      canvas.drawPath(pool, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * 1.4..color = Colors.white);
      final um = rp(.8, .5);
      canvas.drawLine(um, um - Offset(0, floorH * .7), Paint()..strokeWidth = sw..color = const Color(0xFF6B6B6B));
      canvas.drawPath(
          Path()
            ..moveTo(um.dx - floorH * .45, um.dy - floorH * .55)
            ..quadraticBezierTo(um.dx, um.dy - floorH * 1.05, um.dx + floorH * .45, um.dy - floorH * .55)
            ..close(),
          Paint()..color = const Color(0xFFFF7A6B));
    }
    if (lv >= 8 && lv <= 9) {
      // 옥상 정원 덤불
      for (final p in [rp(.05, .15), rp(.95, .2), rp(.9, .85), rp(.1, .9)]) {
        canvas.drawCircle(p - Offset(0, floorH * .12), floorH * .2, Paint()..color = const Color(0xFF5DB04A));
        canvas.drawCircle(p - Offset(floorH * .06, floorH * .2), floorH * .1, Paint()..color = const Color(0xFF8AD06A));
      }
    }
    if (sky) {
      // 헬리패드 + 안테나 깜빡임
      final hp = rp(.5, .5);
      final pad = Rect.fromCenter(center: hp, width: fw * .55, height: fw * .22);
      canvas.drawOval(pad, Paint()..color = const Color(0xFF3F9E7A));
      canvas.drawOval(pad.deflate(fw * .03), Paint()..style = PaintingStyle.stroke..strokeWidth = sw * 1.2..color = Colors.white);
      _label(canvas, 'H', hp - Offset(0, pad.height * .02), pad.height * .55, Colors.white);
      final ant = rp(.9, .8);
      canvas.drawLine(ant, ant - Offset(0, floorH * 1.4), Paint()..strokeWidth = sw * 1.3..color = const Color(0xFF6B7A88));
      canvas.drawCircle(ant - Offset(0, floorH * 1.4), floorH * .1, Paint()..color = Color.lerp(const Color(0xFFFF4D4D), const Color(0xFF7A1E1E), (math.sin(t * math.pi * 8) + 1) / 2)!);
    } else if (lv < 9) {
      // 옥상 계단실 (작은 상자)
      final a = rp(.62, .55);
      final bx = Rect.fromLTWH(a.dx - fw * .12, a.dy - floorH * .55, fw * .24, floorH * .55);
      canvas.drawRect(bx, Paint()..color = const Color(0xFFEFE4D2));
      canvas.drawRect(bx, line);
      canvas.drawRect(Rect.fromLTWH(bx.left - fw * .02, bx.top - floorH * .1, bx.width + fw * .04, floorH * .12), Paint()..color = trim);
    }
  }

  static void _aptWindow(Canvas canvas, Rect r, double sw) {
    canvas.drawRect(r.inflate(r.width * .07), Paint()..color = Colors.white);
    canvas.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFC9EBFF), Color(0xFF5C9FD8)]).createShader(r));
    canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), Paint()..strokeWidth = math.max(.7, r.width * .06)..color = Colors.white);
    canvas.drawRect(r.inflate(r.width * .07), Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .8..color = const Color(0xFF6A6058));
  }

  static void _aptGlassQuad(Canvas canvas, List<Offset> q, bool sky, double sw) {
    final p = Path()..addPolygon(q, true);
    canvas.drawPath(p, Paint()..shader = LinearGradient(colors: sky ? const [Color(0xFF8CC6F5), Color(0xFF3C7FC8)] : const [Color(0xFFB4DDF7), Color(0xFF5E98CC)]).createShader(p.getBounds()));
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .8..color = Colors.white);
  }

  static void _aptBalcony(Canvas canvas, Rect r, double sw, bool plant) {
    canvas.drawRect(r, Paint()..color = Colors.white.withValues(alpha: .45));
    final rail = Paint()
      ..strokeWidth = math.max(.7, sw * .9)
      ..color = const Color(0xFF55606B);
    canvas.drawLine(r.topLeft, r.topRight, rail);
    canvas.drawLine(r.bottomLeft, r.bottomRight, rail);
    for (var k = 0; k <= 6; k++) {
      final x = r.left + r.width * k / 6;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), rail);
    }
    if (plant) {
      canvas.drawCircle(Offset(r.left + r.width * .2, r.top - r.height * .15), r.height * .55, Paint()..color = const Color(0xFF4FA043));
      canvas.drawCircle(Offset(r.left + r.width * .3, r.top - r.height * .3), r.height * .25, Paint()..color = const Color(0xFFFF8FB1));
    }
  }

  static void _label(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  // ───────────────────────── 앞쪽 꾸밈 ─────────────────────────

  void _frontDecor(Canvas canvas, double w, double h, int lv, bool apt, double t) {
    // 돌길 (문 앞 → 섬 앞쪽)
    if (!apt) {
      for (var k = 0; k < 4; k++) {
        final c = Offset(w * (.45 - k * .012), h * (.865 + k * .025));
        canvas.drawOval(Rect.fromCenter(center: c, width: w * .07, height: h * .02), Paint()..color = const Color(0xFFD9D2C4));
      }
    }
    // 나무 울타리 (양옆)
    final post = Paint()..color = const Color(0xFFB98552);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, w * .003)
      ..color = const Color(0xFF6E4524);
    for (final seg in [(.1, .34, .9), (.6, .86, .905)]) {
      final y = h * seg.$3;
      canvas.drawRect(Rect.fromLTWH(w * seg.$1, y - h * .03, w * (seg.$2 - seg.$1), h * .008), post);
      canvas.drawRect(Rect.fromLTWH(w * seg.$1, y - h * .016, w * (seg.$2 - seg.$1), h * .008), post);
      for (var x = seg.$1; x <= seg.$2 + 1e-6; x += .04) {
        final r = Rect.fromLTWH(w * x, y - h * .045, w * .016, h * .045);
        canvas.drawRect(r, post);
        canvas.drawRect(r, edge);
      }
    }
    // 덤불과 꽃
    for (final b in [(.08, .87), (.36, .93), (.64, .93), (.92, .86)]) {
      final c = Offset(w * b.$1, h * b.$2);
      canvas.drawCircle(c, w * .04, Paint()..color = const Color(0xFF4E9E3E));
      canvas.drawCircle(c + Offset(w * .03, h * .004), w * .03, Paint()..color = const Color(0xFF66B552));
      for (var k = 0; k < 3; k++) {
        canvas.drawCircle(c + Offset(w * (k * .02 - .015), -h * .012 + k % 2 * h * .01), w * .008, Paint()..color = k == 1 ? const Color(0xFFFFD43B) : Colors.white);
      }
    }
    // 가로등 (3단계부터, 은은하게 깜빡인다)
    if (apt || lv >= 3) {
      final lamp = Offset(w * .3, h * .9);
      canvas.drawLine(lamp, lamp - Offset(0, h * .12), Paint()..strokeWidth = math.max(1, w * .006)..color = const Color(0xFF3F4A55));
      canvas.drawCircle(lamp - Offset(0, h * .125), w * .03, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .25 + .15 * math.sin(t * math.pi * 4)));
      canvas.drawCircle(lamp - Offset(0, h * .125), w * .014, Paint()..color = const Color(0xFFFFE9A8));
    }
    // 아파트: 벤치 · 파란 자동차(6단계부터)
    if (apt) {
      final bench = Rect.fromLTWH(w * .66, h * .875, w * .1, h * .015);
      canvas.drawRect(bench, Paint()..color = const Color(0xFF9A6234));
      canvas.drawRect(bench.translate(0, -h * .02), Paint()..color = const Color(0xFF9A6234));
      if (lv >= 6) _car(canvas, Offset(w * .8, h * .93), w * .12);
    }
  }

  static void _car(Canvas canvas, Offset c, double cw) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: cw, height: cw * .32), Radius.circular(cw * .1));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF3D7FD6));
    final cab = RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - cw * .28, c.dy - cw * .36, cw * .5, cw * .24), Radius.circular(cw * .08));
    canvas.drawRRect(cab, Paint()..color = const Color(0xFF3D7FD6));
    canvas.drawRRect(cab.deflate(cw * .04), Paint()..color = const Color(0xFFCFEAFF));
    for (final dx in [-.3, .3]) {
      canvas.drawCircle(c + Offset(cw * dx, cw * .15), cw * .1, Paint()..color = const Color(0xFF2B2B2B));
      canvas.drawCircle(c + Offset(cw * dx, cw * .15), cw * .045, Paint()..color = const Color(0xFFBDBDBD));
    }
  }

  void _sparkles(Canvas canvas, double w, double h, double t) {
    for (final s in [(.2, .2, 0.0), (.82, .14, .33), (.74, .4, .66)]) {
      final a = (math.sin((t + s.$3) * math.pi * 2) + 1) / 2;
      final r = w * (.018 + .014 * a);
      final c = Offset(w * s.$1, h * s.$2);
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .5 + .5 * a));
    }
  }

  @override
  bool shouldRepaint(HomeBuildingPainter old) => old.stage != stage || old.anim != anim;
}

/// 움직이는 하우스·아파트 그림. [active]가 false면 멈춰서 배터리를 아낀다. 크기는 부모가 정한다 (정사각형이 가장 보기 좋다).
class HomeBuildingView extends StatefulWidget {
  const HomeBuildingView({super.key, required this.stage, this.active = true});
  final int stage;
  final bool active;

  @override
  State<HomeBuildingView> createState() => _HomeBuildingViewState();
}

class _HomeBuildingViewState extends State<HomeBuildingView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(HomeBuildingView old) {
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
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: HomeBuildingPainter(stage: widget.stage, anim: _c)));
}

/// 둘러보기 화면의 넓은 배경: 하늘·해·흘러가는 구름·먼 언덕·밭 (하우스는 들판, 아파트는 먼 도시 실루엣)
class HomeSceneryPainter extends CustomPainter {
  HomeSceneryPainter({required this.apartment, this.anim}) : super(repaint: anim);
  final bool apartment;
  final Animation<double>? anim;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim?.value ?? 0.0;
    final sky = Offset.zero & size;
    canvas.drawRect(sky, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7CC7F2), Color(0xFFBFE6FA), Color(0xFFE8F6E0)], stops: [0, .55, .75]).createShader(sky));
    // 해
    final sun = Offset(w * .82, h * .13);
    canvas.drawCircle(sun, w * .1, Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: .5));
    canvas.drawCircle(sun, w * .06, Paint()..color = const Color(0xFFFFE07A));
    // 구름 (천천히 오른쪽으로)
    for (final c in [(.1, .12, .16, 0.0), (.55, .22, .12, .4), (.3, .32, .1, .7)]) {
      final x = ((c.$1 + t * .25 + c.$4) % 1.3 - .15) * w;
      final y = h * c.$2, r = w * c.$3 * .5;
      final p = Paint()..color = Colors.white.withValues(alpha: .92);
      canvas.drawCircle(Offset(x, y), r, p);
      canvas.drawCircle(Offset(x + r * .9, y + r * .15), r * .75, p);
      canvas.drawCircle(Offset(x - r * .9, y + r * .2), r * .65, p);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - r * 1.5, y + r * .1, r * 3.1, r * .7), Radius.circular(r)), p);
    }
    // 먼 도시 실루엣 (아파트)
    if (apartment) {
      final city = Paint()..color = const Color(0xFFA9C4DA);
      var x = 0.0;
      var k = 0;
      while (x < w) {
        final bw = w * (.05 + (k * 37 % 5) * .012);
        final bh = h * (.12 + (k * 53 % 7) * .025);
        canvas.drawRect(Rect.fromLTWH(x, h * .62 - bh, bw, bh), city);
        x += bw + w * .01;
        k++;
      }
    }
    // 먼 언덕 두 겹
    final hill1 = Path()
      ..moveTo(0, h * .6)
      ..quadraticBezierTo(w * .25, h * .48, w * .5, h * .58)
      ..quadraticBezierTo(w * .78, h * .66, w, h * .54)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill1, Paint()..color = const Color(0xFF9ED27C));
    final hill2 = Path()
      ..moveTo(0, h * .68)
      ..quadraticBezierTo(w * .4, h * .6, w * .7, h * .67)
      ..quadraticBezierTo(w * .88, h * .71, w, h * .66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill2, Paint()..color = const Color(0xFF7CC35A));
    // 밭 줄무늬
    final field = Rect.fromLTWH(0, h * .72, w, h * .28);
    canvas.drawRect(field, Paint()..color = const Color(0xFF6DB34C));
    for (var k = 0; k < 7; k++) {
      final y = h * (.74 + k * .04);
      canvas.drawLine(Offset(0, y), Offset(w, y + h * .01), Paint()..strokeWidth = h * .006..color = const Color(0xFF5A9E3E));
    }
  }

  @override
  bool shouldRepaint(HomeSceneryPainter old) => old.apartment != apartment || old.anim != anim;
}
