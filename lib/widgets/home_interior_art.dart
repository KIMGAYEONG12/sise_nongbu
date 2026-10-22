import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/home_rules.dart';

/// 집 안 그림: 시안의 "아파트 인테리어 미리보기"처럼 앞쪽 두 벽을 걷어 낸 방을 비스듬히 위에서 내려다본다.
/// 바닥(마름모) + 뒤쪽 두 벽 + 창문(밖 풍경) + 가구. 단계가 높을수록 가구가 늘고 더 고급스러워진다.
/// 모두 코드로 그려서 확대해도 선명하다. [anim]이 있으면 TV·조명·물결·식물이 살짝 움직인다.
class HomeInteriorPainter extends CustomPainter {
  HomeInteriorPainter({required this.stage, required this.room, this.anim}) : super(repaint: anim);
  final int stage;
  final HomeRoom room;
  final Animation<double>? anim;

  @override
  void paint(Canvas canvas, Size size) {
    final iso = _Iso(size);
    final t = anim?.value ?? 0.0;
    final lv = homeLevelOf(stage);
    final apt = isApartmentStage(stage);
    final sky = lv == homeLevels.length;
    // 단계별 벽·바닥 색 (하우스는 따뜻한 나무, 아파트는 밝은 크림, 스카이는 하늘빛)
    final wallL = sky ? const Color(0xFFE6F0FA) : (apt ? const Color(0xFFFFF4E2) : const Color(0xFFF6E7CC));
    final wallR = sky ? const Color(0xFFD3E3F3) : (apt ? const Color(0xFFF2E3C9) : const Color(0xFFEBD6B2));
    final floorA = room == HomeRoom.balcony
        ? const Color(0xFFC79A6A)
        : room == HomeRoom.greenhouse
            ? const Color(0xFFCFC8BC)
            : (lv >= 8 ? const Color(0xFFE9DCC6) : const Color(0xFFD9A86C));
    final floorB = Color.lerp(floorA, Colors.black, .14)!;

    // 바닥 판 두께
    iso.box(canvas, 0, 0, -.04, 1, 1, .04, top: floorA, left: const Color(0xFFB98A5A), right: const Color(0xFFA67848));
    // 바닥 무늬: 나무 마루(줄) / 대리석(격자)
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, iso.a * .004)
      ..color = floorB.withValues(alpha: .6);
    for (var k = 1; k < 8; k++) {
      canvas.drawLine(iso.p(k / 8, 0, 0), iso.p(k / 8, 1, 0), seam);
      if (lv >= 8 || room == HomeRoom.greenhouse) canvas.drawLine(iso.p(0, k / 8, 0), iso.p(1, k / 8, 0), seam);
    }

    if (room == HomeRoom.balcony) {
      _balcony(canvas, iso, lv, apt, sky, t);
      return;
    }
    if (room == HomeRoom.greenhouse) {
      _greenhouse(canvas, iso, t);
      return;
    }

    // 뒤쪽 두 벽 (왼쪽 벽 x=0, 오른쪽 벽 y=0)
    iso.wallLeft(canvas, wallL);
    iso.wallRight(canvas, wallR);
    // 걸레받이
    canvas.drawPath(iso.quad([iso.p(0, 0, 0), iso.p(0, 1, 0), iso.p(0, 1, .03), iso.p(0, 0, .03)]), Paint()..color = Colors.white);
    canvas.drawPath(iso.quad([iso.p(0, 0, 0), iso.p(1, 0, 0), iso.p(1, 0, .03), iso.p(0, 0, .03)]), Paint()..color = Colors.white);
    // 왼쪽 벽의 큰 창 (밖 풍경)
    iso.windowLeft(canvas, .2, .8, .3, .82, apt: apt, sky: sky, t: t);

    switch (room) {
      case HomeRoom.living:
        _living(canvas, iso, lv, t);
      case HomeRoom.kitchen:
        _kitchen(canvas, iso, lv, t);
      case HomeRoom.bedroom:
        _bedroom(canvas, iso, lv, t);
      case HomeRoom.balcony:
      case HomeRoom.greenhouse:
        break;
    }
    // 높은 단계: 천장 샹들리에
    if (lv >= 8) _chandelier(canvas, iso, t);
  }

  // ───────────────────────── 방마다 가구 ─────────────────────────

  void _living(Canvas canvas, _Iso iso, int lv, double t) {
    // 러그
    iso.box(canvas, .25, .3, 0, .5, .45, .006, top: lv >= 5 ? const Color(0xFFF3D3D8) : const Color(0xFFE8C08A), left: const Color(0xFFD9A9B0), right: const Color(0xFFCB9AA2));
    // TV 장 + TV (오른쪽 벽)
    iso.box(canvas, .3, .02, 0, .42, .1, .12, top: const Color(0xFFFFFFFF), left: const Color(0xFFE7E2DA), right: const Color(0xFFD6CFC3));
    final tvGlow = .75 + .25 * math.sin(t * math.pi * 6);
    canvas.drawPath(iso.quad([iso.p(.33, .01, .16), iso.p(.69, .01, .16), iso.p(.69, .01, .4), iso.p(.33, .01, .4)]), Paint()..color = const Color(0xFF26313D));
    canvas.drawPath(iso.quad([iso.p(.35, .01, .18), iso.p(.67, .01, .18), iso.p(.67, .01, .38), iso.p(.35, .01, .38)]),
        Paint()..shader = LinearGradient(colors: [const Color(0xFF7FD3F5).withValues(alpha: tvGlow), const Color(0xFF4A8BD6).withValues(alpha: tvGlow)]).createShader(Rect.fromPoints(iso.p(.35, .01, .38), iso.p(.67, .01, .18))));
    // 소파 (왼쪽 앞, 등받이 + 앉는 자리 + 팔걸이)
    final sofa = lv >= 5 ? const Color(0xFFF7F3EC) : const Color(0xFF8BB8D8);
    final sofaS = Color.lerp(sofa, Colors.black, .12)!, sofaR = Color.lerp(sofa, Colors.black, .2)!;
    iso.box(canvas, .3, .78, 0, .45, .16, .1, top: sofa, left: sofaS, right: sofaR);
    iso.box(canvas, .3, .9, .1, .45, .06, .14, top: sofa, left: sofaS, right: sofaR);
    iso.box(canvas, .26, .78, 0, .05, .18, .16, top: sofa, left: sofaS, right: sofaR);
    iso.box(canvas, .74, .78, 0, .05, .18, .16, top: sofa, left: sofaS, right: sofaR);
    // 쿠션
    iso.box(canvas, .36, .86, .1, .1, .04, .08, top: const Color(0xFFFF9FB5), left: const Color(0xFFE8869C), right: const Color(0xFFD97790));
    iso.box(canvas, .58, .86, .1, .1, .04, .08, top: const Color(0xFFFFD36B), left: const Color(0xFFE8BC55), right: const Color(0xFFD4A944));
    // 커피 테이블 + 찻잔
    iso.box(canvas, .4, .45, 0, .22, .16, .08, top: const Color(0xFFB27546), left: const Color(0xFF9A6234), right: const Color(0xFF8A5530));
    canvas.drawCircle(iso.p(.5, .52, .09), iso.a * .018, Paint()..color = Colors.white);
    // 화분 (오른쪽 앞 구석)
    _plant(canvas, iso, .9, .12, lv >= 5 ? .36 : .26, t);
    // 책장 (3단계부터, 왼쪽 벽 뒤)
    if (lv >= 3) {
      iso.box(canvas, .02, .05, 0, .1, .12, .5, top: const Color(0xFFB27546), left: const Color(0xFF9A6234), right: const Color(0xFF8A5530));
      for (var k = 0; k < 3; k++) {
        final z = .1 + k * .14;
        for (var b = 0; b < 3; b++) {
          const colors = [Color(0xFFE5513F), Color(0xFF4F7FD6), Color(0xFFFFC93C)];
          canvas.drawPath(iso.quad([iso.p(.12, .06 + b * .035, z), iso.p(.12, .09 + b * .035, z), iso.p(.12, .09 + b * .035, z + .1), iso.p(.12, .06 + b * .035, z + .1)]), Paint()..color = colors[(b + k) % 3]);
        }
      }
    }
    // 바닥 조명 (5단계부터)
    if (lv >= 5) _floorLamp(canvas, iso, .1, .8, t);
    // 벽 액자
    iso.frameRight(canvas, .78, .95, .45, .65, const Color(0xFF9ED27C));
  }

  void _kitchen(Canvas canvas, _Iso iso, int lv, double t) {
    final counter = lv >= 5 ? const Color(0xFFFFFFFF) : const Color(0xFFF2E3C9);
    final cabinet = lv >= 8 ? const Color(0xFF6B8FB5) : (lv >= 5 ? const Color(0xFFE3EDF5) : const Color(0xFFB98552));
    final cabS = Color.lerp(cabinet, Colors.black, .12)!, cabR = Color.lerp(cabinet, Colors.black, .22)!;
    // 오른쪽 벽을 따라 조리대
    iso.box(canvas, .05, .02, 0, .7, .16, .2, top: counter, left: cabS, right: cabR);
    // 서랍 손잡이
    for (var k = 0; k < 4; k++) {
      final x = .12 + k * .17;
      canvas.drawLine(iso.p(x, .18, .14), iso.p(x + .06, .18, .14), Paint()..strokeWidth = math.max(1, iso.a * .006)..strokeCap = StrokeCap.round..color = const Color(0xFF8A8A8A));
    }
    // 가스레인지 + 냄비 김
    canvas.drawPath(iso.quad([iso.p(.48, .04, .201), iso.p(.66, .04, .201), iso.p(.66, .15, .201), iso.p(.48, .15, .201)]), Paint()..color = const Color(0xFF2E2E2E));
    iso.box(canvas, .52, .06, .2, .08, .07, .06, top: const Color(0xFFE5513F), left: const Color(0xFFC9443A), right: const Color(0xFFB03A30));
    for (var k = 0; k < 2; k++) {
      final p = (t * 1.5 + k * .5) % 1.0;
      canvas.drawCircle(iso.p(.56, .09, .28 + p * .2), iso.a * (.015 + p * .02), Paint()..color = Colors.white.withValues(alpha: .7 * (1 - p)));
    }
    // 개수대
    canvas.drawPath(iso.quad([iso.p(.15, .05, .201), iso.p(.33, .05, .201), iso.p(.33, .14, .201), iso.p(.15, .14, .201)]), Paint()..color = const Color(0xFFB8C4CE));
    // 위쪽 수납장
    iso.box(canvas, .05, .01, .5, .7, .1, .22, top: cabinet, left: cabS, right: cabR);
    // 냉장고 (오른쪽 끝)
    iso.box(canvas, .78, .02, 0, .18, .17, .62, top: const Color(0xFFE9EEF2), left: const Color(0xFFD3DAE0), right: const Color(0xFFBFC8D0));
    canvas.drawLine(iso.p(.82, .19, .25), iso.p(.82, .19, .45), Paint()..strokeWidth = math.max(1, iso.a * .008)..color = const Color(0xFF8A96A0));
    // 식탁 + 의자 두 개 + 과일 그릇 (뒤쪽 의자 → 식탁 → 앞쪽 의자 순서로 그려야 겹침이 맞다)
    iso.box(canvas, .3, .55, 0, .07, .12, .11, top: const Color(0xFFFFD36B), left: const Color(0xFFE8BC55), right: const Color(0xFFD4A944));
    for (final leg in [(.4, .5), (.67, .5), (.4, .71), (.67, .71)]) {
      iso.box(canvas, leg.$1, leg.$2, 0, .025, .025, .18, top: const Color(0xFF9A6234), left: const Color(0xFF8A5530), right: const Color(0xFF7A4A2A));
    }
    iso.box(canvas, .38, .48, .18, .32, .26, .03, top: const Color(0xFFC98E5A), left: const Color(0xFFB27546), right: const Color(0xFF9A6234));
    iso.box(canvas, .74, .55, 0, .07, .12, .11, top: const Color(0xFFFFD36B), left: const Color(0xFFE8BC55), right: const Color(0xFFD4A944));
    final bowl = iso.p(.54, .61, .22);
    canvas.drawOval(Rect.fromCenter(center: bowl, width: iso.a * .1, height: iso.a * .04), Paint()..color = Colors.white);
    for (final f in [(-.02, const Color(0xFFE5483B)), (.015, const Color(0xFFFFC93C)), (0.0, const Color(0xFF7CCB5B))]) {
      canvas.drawCircle(bowl + Offset(iso.a * f.$1, -iso.a * .02), iso.a * .018, Paint()..color = f.$2);
    }
    // 펜던트 조명
    final lamp = iso.p(.54, .61, .82);
    canvas.drawLine(iso.p(.54, .61, 1.0), lamp, Paint()..strokeWidth = 1..color = const Color(0xFF5E5E5E));
    canvas.drawPath(
        Path()
          ..moveTo(lamp.dx - iso.a * .05, lamp.dy + iso.a * .04)
          ..quadraticBezierTo(lamp.dx, lamp.dy - iso.a * .04, lamp.dx + iso.a * .05, lamp.dy + iso.a * .04)
          ..close(),
        Paint()..color = const Color(0xFFFFC93C));
    canvas.drawCircle(lamp + Offset(0, iso.a * .05), iso.a * .05, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .25 + .1 * math.sin(t * math.pi * 4)));
    if (lv >= 3) _plant(canvas, iso, .1, .9, .22, t);
  }

  void _bedroom(Canvas canvas, _Iso iso, int lv, double t) {
    final blanket = lv >= 5 ? const Color(0xFFF7B6C2) : const Color(0xFF9CC7E8);
    // 러그
    iso.box(canvas, .2, .25, 0, .6, .6, .006, top: const Color(0xFFF6EEDF), left: const Color(0xFFE2D6C0), right: const Color(0xFFD6C8AE));
    // 침대: 머리판(오른쪽 벽) + 매트리스 + 이불 + 베개
    final size = lv >= 5 ? .5 : .4;
    iso.box(canvas, .3, .02, 0, size, .06, .32, top: const Color(0xFFB27546), left: const Color(0xFF9A6234), right: const Color(0xFF8A5530));
    iso.box(canvas, .3, .08, 0, size, .55, .12, top: Colors.white, left: const Color(0xFFE7E2DA), right: const Color(0xFFD6CFC3));
    iso.box(canvas, .3, .3, .12, size, .33, .025, top: blanket, left: Color.lerp(blanket, Colors.black, .12)!, right: Color.lerp(blanket, Colors.black, .2)!);
    iso.box(canvas, .33, .1, .12, size * .4, .1, .05, top: const Color(0xFFFFFBF2), left: const Color(0xFFEDE7DC), right: const Color(0xFFDDD5C8));
    iso.box(canvas, .3 + size * .55, .1, .12, size * .4, .1, .05, top: const Color(0xFFFFFBF2), left: const Color(0xFFEDE7DC), right: const Color(0xFFDDD5C8));
    // 협탁 + 스탠드
    iso.box(canvas, .3 + size + .04, .04, 0, .12, .12, .16, top: const Color(0xFFC98E5A), left: const Color(0xFFB27546), right: const Color(0xFF9A6234));
    final lamp = iso.p(.3 + size + .1, .1, .26);
    canvas.drawLine(iso.p(.3 + size + .1, .1, .16), lamp, Paint()..strokeWidth = math.max(1, iso.a * .006)..color = const Color(0xFF8A7A6A));
    canvas.drawPath(
        Path()
          ..moveTo(lamp.dx - iso.a * .035, lamp.dy)
          ..lineTo(lamp.dx + iso.a * .035, lamp.dy)
          ..lineTo(lamp.dx + iso.a * .022, lamp.dy - iso.a * .05)
          ..lineTo(lamp.dx - iso.a * .022, lamp.dy - iso.a * .05)
          ..close(),
        Paint()..color = const Color(0xFFFFE9A8));
    canvas.drawCircle(lamp - Offset(0, iso.a * .02), iso.a * .06, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .2 + .08 * math.sin(t * math.pi * 2)));
    // 옷장 (왼쪽 벽, 2단계부터 두 칸짜리)
    iso.box(canvas, .02, .55, 0, .12, lv >= 2 ? .35 : .22, .56, top: const Color(0xFFF2E3C9), left: const Color(0xFFE2CFAE), right: const Color(0xFFD1BC98));
    // 화분
    _plant(canvas, iso, .88, .85, .24, t);
    iso.frameRight(canvas, .06, .24, .4, .62, const Color(0xFFFFC3D1));
  }

  void _balcony(Canvas canvas, _Iso iso, int lv, bool apt, bool sky, double t) {
    // 밖 풍경을 벽 대신 뒤에 크게: 하늘 + (하우스: 들판 / 아파트: 도시)
    iso.wallLeft(canvas, const Color(0xFFBFE6FA));
    iso.wallRight(canvas, const Color(0xFFCDEBFB));
    iso.viewOnLeft(canvas, 0, 1, 0, 1, apt: apt, sky: sky, t: t);
    iso.viewOnRight(canvas, apt: apt, sky: sky);
    // 난간: 아파트는 유리, 하우스는 나무
    for (final side in [true, false]) {
      final q = side ? [iso.p(0, 0, 0), iso.p(0, 1, 0), iso.p(0, 1, .3), iso.p(0, 0, .3)] : [iso.p(0, 0, 0), iso.p(1, 0, 0), iso.p(1, 0, .3), iso.p(0, 0, .3)];
      if (apt) {
        canvas.drawPath(iso.quad(q), Paint()..color = const Color(0xFFDFF4FF).withValues(alpha: .55));
        canvas.drawPath(iso.quad(q), Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, iso.a * .006)..color = Colors.white);
      } else {
        for (var k = 0; k <= 12; k++) {
          final s = k / 12;
          final a = side ? iso.p(0, s, 0) : iso.p(s, 0, 0);
          final b = side ? iso.p(0, s, .3) : iso.p(s, 0, .3);
          canvas.drawLine(a, b, Paint()..strokeWidth = math.max(1, iso.a * .01)..color = const Color(0xFF9A6234));
        }
        canvas.drawLine(q[3], q[2], Paint()..strokeWidth = math.max(1.5, iso.a * .018)..strokeCap = StrokeCap.round..color = const Color(0xFF8A5530));
      }
    }
    // 작은 테이블 + 의자 두 개
    iso.box(canvas, .42, .42, .14, .18, .18, .02, top: Colors.white, left: const Color(0xFFE7E2DA), right: const Color(0xFFD6CFC3));
    iso.box(canvas, .5, .5, 0, .02, .02, .14, top: const Color(0xFF8A8A8A), left: const Color(0xFF8A8A8A), right: const Color(0xFF6E6E6E));
    for (final ch in [(.25, .48), (.66, .3)]) {
      iso.box(canvas, ch.$1, ch.$2, 0, .1, .1, .09, top: const Color(0xFFFFD36B), left: const Color(0xFFE8BC55), right: const Color(0xFFD4A944));
    }
    canvas.drawCircle(iso.p(.5, .5, .17), iso.a * .016, Paint()..color = const Color(0xFFFF8FB1));
    // 화분들
    _plant(canvas, iso, .1, .12, .3, t);
    _plant(canvas, iso, .86, .1, .26, t);
    if (lv >= 5) _plant(canvas, iso, .12, .85, .22, t);
  }

  void _greenhouse(Canvas canvas, _Iso iso, double t) {
    // 유리 벽 (뒤 풍경이 비친다)
    iso.wallLeft(canvas, const Color(0xFFDFF4FF));
    iso.wallRight(canvas, const Color(0xFFE6F6FF));
    final frame = Paint()
      ..strokeWidth = math.max(1, iso.a * .008)
      ..color = Colors.white;
    for (var k = 0; k <= 5; k++) {
      canvas.drawLine(iso.p(0, k / 5, 0), iso.p(0, k / 5, 1), frame);
      canvas.drawLine(iso.p(k / 5, 0, 0), iso.p(k / 5, 0, 1), frame);
    }
    canvas.drawLine(iso.p(0, 0, .5), iso.p(0, 1, .5), frame);
    canvas.drawLine(iso.p(0, 0, .5), iso.p(1, 0, .5), frame);
    // 화단 두 줄 + 자라는 작물
    for (final row in [.2, .6]) {
      iso.box(canvas, .1, row, 0, .8, .18, .1, top: const Color(0xFF7A4E2A), left: const Color(0xFFA67848), right: const Color(0xFF8A5A33));
      for (var k = 0; k < 6; k++) {
        final c = iso.p(.16 + k * .13, row + .09, .1);
        final sway = math.sin((t + k * .15) * math.pi * 2) * iso.a * .006;
        canvas.drawCircle(c + Offset(sway, -iso.a * .03), iso.a * .03, Paint()..color = const Color(0xFF5DB04A));
        canvas.drawCircle(c + Offset(sway - iso.a * .01, -iso.a * .045), iso.a * .015, Paint()..color = const Color(0xFF8AD06A));
        if (k.isEven) canvas.drawCircle(c + Offset(sway + iso.a * .012, -iso.a * .025), iso.a * .01, Paint()..color = const Color(0xFFE5483B));
      }
    }
    // 물뿌리개
    iso.box(canvas, .82, .88, 0, .08, .06, .07, top: const Color(0xFF4DA8F5), left: const Color(0xFF3D8FD6), right: const Color(0xFF2F78BC));
  }

  // ───────────────────────── 소품 ─────────────────────────

  static void _plant(Canvas canvas, _Iso iso, double x, double y, double hgt, double t) {
    iso.box(canvas, x - .04, y - .04, 0, .08, .08, .08, top: const Color(0xFF7A4E2A), left: const Color(0xFFD9784F), right: const Color(0xFFC0623E));
    final sway = math.sin(t * math.pi * 2) * iso.a * .006;
    final top = iso.p(x, y, .08 + hgt);
    final stem = iso.p(x, y, .08);
    canvas.drawLine(stem, top, Paint()..strokeWidth = math.max(1, iso.a * .006)..color = const Color(0xFF3E8E3A));
    for (var k = 0; k < 5; k++) {
      final a = k * math.pi * 2 / 5;
      final c = top + Offset(math.cos(a) * iso.a * .04 + sway, math.sin(a) * iso.a * .025 + iso.a * .02);
      canvas.drawOval(Rect.fromCenter(center: c, width: iso.a * .07, height: iso.a * .04), Paint()..color = k.isEven ? const Color(0xFF5DB04A) : const Color(0xFF3E8E3A));
    }
    canvas.drawCircle(top + Offset(sway, 0), iso.a * .03, Paint()..color = const Color(0xFF8AD06A));
  }

  static void _floorLamp(Canvas canvas, _Iso iso, double x, double y, double t) {
    final foot = iso.p(x, y, 0), head = iso.p(x, y, .55);
    canvas.drawOval(Rect.fromCenter(center: foot, width: iso.a * .08, height: iso.a * .03), Paint()..color = const Color(0xFF5E5E5E));
    canvas.drawLine(foot, head, Paint()..strokeWidth = math.max(1, iso.a * .008)..color = const Color(0xFF5E5E5E));
    canvas.drawCircle(head, iso.a * .1, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .18 + .08 * math.sin(t * math.pi * 2)));
    canvas.drawPath(
        Path()
          ..moveTo(head.dx - iso.a * .045, head.dy + iso.a * .03)
          ..lineTo(head.dx + iso.a * .045, head.dy + iso.a * .03)
          ..lineTo(head.dx + iso.a * .028, head.dy - iso.a * .035)
          ..lineTo(head.dx - iso.a * .028, head.dy - iso.a * .035)
          ..close(),
        Paint()..color = const Color(0xFFFFF3DC));
  }

  static void _chandelier(Canvas canvas, _Iso iso, double t) {
    final c = iso.p(.5, .5, .9);
    canvas.drawLine(iso.p(.5, .5, 1.05), c, Paint()..strokeWidth = 1..color = const Color(0xFFC9A227));
    canvas.drawOval(Rect.fromCenter(center: c, width: iso.a * .2, height: iso.a * .06), Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, iso.a * .008)..color = const Color(0xFFE0B83A));
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3 + t * math.pi * 2 * .2;
      final p = c + Offset(math.cos(a) * iso.a * .1, math.sin(a) * iso.a * .03);
      canvas.drawCircle(p, iso.a * .012, Paint()..color = const Color(0xFFFFF3B0));
      canvas.drawCircle(p, iso.a * .028, Paint()..color = const Color(0xFFFFE07A).withValues(alpha: .25));
    }
  }

  @override
  bool shouldRepaint(HomeInteriorPainter old) => old.stage != stage || old.room != room || old.anim != anim;
}

/// 비스듬히 내려다보는 방 좌표: x(오른쪽 벽 방향 0~1), y(왼쪽 벽 방향 0~1), z(높이 0~1).
/// (0,0)은 뒤쪽 모서리, (1,1)은 앞쪽 모서리.
class _Iso {
  _Iso(Size size) {
    // 가로는 바닥 마름모가 꽉 차게, 세로는 벽 높이 + 바닥이 들어가게 맞춘다
    a = math.min(size.width * .46, size.height / 1.82); // 바닥 마름모 높이 a + 벽 높이 .72a + 여유
    hgt = a * .72;
    cx = size.width / 2;
    oy = (size.height - (a + hgt)) / 2 + hgt;
  }
  late final double a, hgt, cx, oy;

  Offset p(double x, double y, double z) => Offset(cx + (x - y) * a, oy + (x + y) * a * .5 - z * hgt);

  Path quad(List<Offset> q) => Path()..addPolygon(q, true);

  /// 상자: 윗면 · 앞왼쪽 면(y = y0+dy) · 앞오른쪽 면(x = x0+dx)
  void box(Canvas canvas, double x0, double y0, double z0, double dx, double dy, double dz, {required Color top, required Color left, required Color right}) {
    final x1 = x0 + dx, y1 = y0 + dy, z1 = z0 + dz;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, a * .003)
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: .18);
    final l = quad([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)]);
    final r = quad([p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), p(x1, y0, z1)]);
    final tp = quad([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)]);
    canvas.drawPath(l, Paint()..color = left);
    canvas.drawPath(r, Paint()..color = right);
    canvas.drawPath(tp, Paint()..color = top);
    canvas.drawPath(l, edge);
    canvas.drawPath(r, edge);
    canvas.drawPath(tp, edge);
  }

  void wallLeft(Canvas canvas, Color c) {
    final q = quad([p(0, 0, 0), p(0, 1, 0), p(0, 1, 1), p(0, 0, 1)]);
    canvas.drawPath(q, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(c, Colors.white, .2)!, c]).createShader(q.getBounds()));
    // 벽 두께 (윗면)
    canvas.drawPath(quad([p(0, 0, 1), p(0, 1, 1), p(-.03, 1, 1), p(-.03, -.03, 1)]), Paint()..color = const Color(0xFFFFFFFF));
  }

  void wallRight(Canvas canvas, Color c) {
    final q = quad([p(0, 0, 0), p(1, 0, 0), p(1, 0, 1), p(0, 0, 1)]);
    canvas.drawPath(q, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(c, Colors.white, .15)!, c]).createShader(q.getBounds()));
    canvas.drawPath(quad([p(0, 0, 1), p(1, 0, 1), p(1, -.03, 1), p(-.03, -.03, 1)]), Paint()..color = const Color(0xFFF7F7F7));
  }

  /// 오른쪽 벽의 액자 (x 범위, z 범위)
  void frameRight(Canvas canvas, double x0, double x1, double z0, double z1, Color art) {
    canvas.drawPath(quad([p(x0, 0, z0), p(x1, 0, z0), p(x1, 0, z1), p(x0, 0, z1)]), Paint()..color = const Color(0xFFB27546));
    final m = (x1 - x0) * .12, mz = (z1 - z0) * .12;
    canvas.drawPath(quad([p(x0 + m, 0, z0 + mz), p(x1 - m, 0, z0 + mz), p(x1 - m, 0, z1 - mz), p(x0 + m, 0, z1 - mz)]), Paint()..color = art);
    canvas.drawCircle(p((x0 + x1) / 2, 0, (z0 + z1) / 2), a * .02, Paint()..color = Colors.white.withValues(alpha: .8));
  }

  /// 왼쪽 벽의 창 (y 범위, z 범위) + 창밖 풍경 + 커튼
  void windowLeft(Canvas canvas, double y0, double y1, double z0, double z1, {required bool apt, required bool sky, required double t}) {
    final frame = quad([p(0, y0 - .03, z0 - .04), p(0, y1 + .03, z0 - .04), p(0, y1 + .03, z1 + .04), p(0, y0 - .03, z1 + .04)]);
    canvas.drawPath(frame, Paint()..color = Colors.white);
    viewOnLeft(canvas, y0, y1, z0, z1, apt: apt, sky: sky, t: t);
    final bar = Paint()
      ..strokeWidth = math.max(1, a * .01)
      ..color = Colors.white;
    canvas.drawLine(p(0, (y0 + y1) / 2, z0), p(0, (y0 + y1) / 2, z1), bar);
    canvas.drawPath(frame, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(.6, a * .004)..color = Colors.black.withValues(alpha: .15));
    // 커튼
    final curtain = apt ? const Color(0xFFF7D9DF) : const Color(0xFFFFE3A3);
    for (final edge in [y0 - .06, y1 - .02]) {
      canvas.drawPath(quad([p(0, edge, z0 - .08), p(0, edge + .08, z0 - .08), p(0, edge + .08, z1 + .08), p(0, edge, z1 + .08)]), Paint()..color = curtain);
    }
  }

  /// 왼쪽 벽면 위 사각형 안에 창밖 풍경을 그린다
  void viewOnLeft(Canvas canvas, double y0, double y1, double z0, double z1, {required bool apt, required bool sky, required double t}) {
    final glass = quad([p(0, y0, z0), p(0, y1, z0), p(0, y1, z1), p(0, y0, z1)]);
    canvas.save();
    canvas.clipPath(glass);
    final b = glass.getBounds();
    canvas.drawRect(b, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky ? const [Color(0xFF5FAEEB), Color(0xFFBFE6FA)] : const [Color(0xFF8FD0F5), Color(0xFFDDF2FB)]).createShader(b));
    // 흘러가는 구름
    final cx0 = b.left + b.width * ((t * .5) % 1.2 - .1);
    canvas.drawCircle(Offset(cx0, b.top + b.height * .25), b.width * .08, Paint()..color = Colors.white.withValues(alpha: .9));
    canvas.drawCircle(Offset(cx0 + b.width * .08, b.top + b.height * .28), b.width * .06, Paint()..color = Colors.white.withValues(alpha: .9));
    if (sky) {
      // 구름 바다 위 (스카이 아파트)
      canvas.drawRect(Rect.fromLTWH(b.left, b.top + b.height * .7, b.width, b.height * .3), Paint()..color = Colors.white.withValues(alpha: .85));
    } else if (apt) {
      final city = Paint()..color = const Color(0xFF9DB7CC);
      for (var k = 0; k < 8; k++) {
        final bw = b.width / 8;
        final bh = b.height * (.25 + (k * 37 % 5) * .08);
        canvas.drawRect(Rect.fromLTWH(b.left + k * bw, b.bottom - bh, bw * .85, bh), city);
      }
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(b.left, b.bottom - b.height * .25)
            ..quadraticBezierTo(b.center.dx, b.bottom - b.height * .45, b.right, b.bottom - b.height * .3)
            ..lineTo(b.right, b.bottom)
            ..lineTo(b.left, b.bottom)
            ..close(),
          Paint()..color = const Color(0xFF7CC35A));
    }
    canvas.restore();
  }

  /// 발코니 오른쪽 벽 자리에 먼 풍경 (언덕 / 도시)
  void viewOnRight(Canvas canvas, {required bool apt, required bool sky}) {
    final q = quad([p(0, 0, 0), p(1, 0, 0), p(1, 0, 1), p(0, 0, 1)]);
    canvas.save();
    canvas.clipPath(q);
    final b = q.getBounds();
    if (sky) {
      canvas.drawRect(Rect.fromLTWH(b.left, b.top + b.height * .65, b.width, b.height * .35), Paint()..color = Colors.white.withValues(alpha: .85));
    } else if (apt) {
      for (var k = 0; k < 10; k++) {
        final bw = b.width / 10;
        final bh = b.height * (.3 + (k * 53 % 6) * .07);
        canvas.drawRect(Rect.fromLTWH(b.left + k * bw, b.bottom - bh, bw * .8, bh), Paint()..color = const Color(0xFFA9C4DA));
      }
    } else {
      canvas.drawOval(Rect.fromLTWH(b.left - b.width * .2, b.bottom - b.height * .45, b.width * 1.4, b.height * .7), Paint()..color = const Color(0xFF8CCB64));
    }
    canvas.restore();
  }
}
