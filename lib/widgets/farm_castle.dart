import 'package:flutter/material.dart';

/// Lv.90 "전설의 농장 성": 농장 그림 속 오두막 자리에 덮어 그리는 성 (코드로 그려서 확대해도 선명하다).
/// 자리는 farm_page의 _castle (그림 원본 픽셀)에 맞춰 오두막의 지붕·굴뚝·벽을 모두 가리도록 짰다.
class FarmCastle extends StatelessWidget {
  const FarmCastle({super.key});
  @override
  Widget build(BuildContext context) => const IgnorePointer(child: CustomPaint(painter: _CastlePainter(), size: Size.infinite));
}

class _CastlePainter extends CustomPainter {
  const _CastlePainter();

  static const _stone = Color(0xFFF2EBDB), _stoneShade = Color(0xFFDCCFB3), _line = Color(0xFF7A6A55);
  static const _roof = Color(0xFF4F5BD5), _roofLight = Color(0xFF7D88EA), _gold = Color(0xFFF2C14E);
  static const _window = Color(0xFF2E3A6B), _glow = Color(0xFFFFD66B), _flag = Color(0xFFE2453C), _gate = Color(0xFF8B5A2B);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final sw = (w / 220).clamp(1.0, 3.0).toDouble(); // 선 굵기
    Offset p(double x, double y) => Offset(x * w, y * h);
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * w, t * h, rr * w, b * h);
    final line = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round;

    void archPath(Path path, Rect rc) {
      path
        ..moveTo(rc.left, rc.bottom)
        ..lineTo(rc.left, rc.top + rc.width / 2)
        ..arcToPoint(Offset(rc.right, rc.top + rc.width / 2), radius: Radius.circular(rc.width / 2))
        ..lineTo(rc.right, rc.bottom)
        ..close();
    }

    // [cx],[cy]는 창 가운데, [ww]는 창 너비(비율)
    void window(double cx, double cy, double ww) {
      final rc = Rect.fromCenter(center: p(cx, cy), width: ww * w, height: ww * w * 1.6);
      final path = Path();
      archPath(path, rc);
      canvas.drawPath(path, Paint()..color = _window);
      // 따뜻한 불빛: 창 아래쪽만 노랗게
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(Rect.fromLTRB(rc.left, rc.top + rc.height * .45, rc.right, rc.bottom), Paint()..color = _glow);
      canvas.restore();
      canvas.drawLine(Offset(rc.center.dx, rc.top), Offset(rc.center.dx, rc.bottom), line);
      canvas.drawPath(path, line);
    }

    // 바닥 그림자
    canvas.drawOval(r(.02, .90, .98, 1.02), Paint()..color = const Color(0x33000000));

    void wall(double l, double t, double rr, double b, {double merlon = .035}) {
      final rect = r(l, t, rr, b);
      // 오른쪽 1/4은 그늘
      canvas.drawRect(rect, Paint()..color = _stone);
      canvas.drawRect(Rect.fromLTRB(rect.right - rect.width * .25, rect.top, rect.right, rect.bottom), Paint()..color = _stoneShade);
      // 돌 줄눈
      final joint = Paint()
        ..color = _line.withValues(alpha: .25)
        ..strokeWidth = sw * .7;
      for (var y = t + .06; y < b; y += .06) {
        canvas.drawLine(p(l, y), p(rr, y), joint);
      }
      canvas.drawRect(rect, line);
      // 성가퀴(톱니 모양 꼭대기)
      final mw = (rr - l) / 7;
      for (var i = 0; i < 7; i += 2) {
        final m = r(l + mw * i, t - merlon, l + mw * (i + 1), t);
        canvas.drawRect(m, Paint()..color = _stone);
        canvas.drawRect(m, line);
      }
    }

    void tower(double l, double rr, double top, double b, double apex) {
      final body = r(l, top, rr, b);
      canvas.drawRect(body, Paint()..color = _stone);
      canvas.drawRect(Rect.fromLTRB(body.right - body.width * .3, body.top, body.right, body.bottom), Paint()..color = _stoneShade);
      canvas.drawRect(body, line);
      // 금색 띠
      canvas.drawRect(r(l, top, rr, top + .025), Paint()..color = _gold);
      canvas.drawRect(r(l, top, rr, top + .025), line);
      // 뾰족 지붕 (왼쪽 밝게, 오른쪽 어둡게)
      final cx = (l + rr) / 2, ext = (rr - l) * .18;
      final left = Path()
        ..moveTo(cx * w, apex * h)
        ..lineTo((l - ext) * w, top * h)
        ..lineTo(cx * w, top * h)
        ..close();
      final right = Path()
        ..moveTo(cx * w, apex * h)
        ..lineTo(cx * w, top * h)
        ..lineTo((rr + ext) * w, top * h)
        ..close();
      canvas.drawPath(left, Paint()..color = _roofLight);
      canvas.drawPath(right, Paint()..color = _roof);
      canvas.drawPath(Path()..addPath(left, Offset.zero)..addPath(right, Offset.zero), line);
      // 깃발
      final pole = p(cx, apex);
      final flagTop = pole.translate(0, -h * .07);
      canvas.drawLine(pole, flagTop, line..strokeWidth = sw * 1.2);
      line.strokeWidth = sw;
      final flag = Path()
        ..moveTo(flagTop.dx, flagTop.dy)
        ..lineTo(flagTop.dx + w * .05, flagTop.dy + h * .018)
        ..lineTo(flagTop.dx, flagTop.dy + h * .036)
        ..close();
      canvas.drawPath(flag, Paint()..color = _flag);
      // 창문
      final wx = cx, wy = top + (b - top) * .3;
      window(wx, wy, (rr - l) * .32);
    }

    // 뒤쪽 큰 탑 두 개 (오두막 굴뚝을 가린다)
    tower(.24, .44, .16, .95, .02);
    tower(.62, .82, .16, .95, .02);
    // 가운데 본관 (탑 사이로 오두막 지붕 마루가 보이지 않게 높게)
    wall(.40, .15, .66, .95);
    window(.53, .27, .05);
    // 바깥 성벽과 양 끝 탑 (오두막 처마와 벽을 가린다)
    wall(.02, .42, .98, .97);
    tower(.04, .24, .26, .97, .08);
    tower(.76, .96, .26, .97, .08);
    for (final x in [.30, .40, .66, .76]) {
      window(x, .60, .04);
    }
    // 성문: 금테 아치 + 나무 문
    final gate = r(.43, .66, .57, .97);
    final gatePath = Path();
    archPath(gatePath, gate);
    canvas.drawPath(gatePath, Paint()..color = _gate);
    canvas.drawLine(Offset(gate.center.dx, gate.top + gate.width * .2), Offset(gate.center.dx, gate.bottom), line);
    canvas.drawPath(gatePath, Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 2.4);
    canvas.drawPath(gatePath, line);

    // 바닥 덤불: 성 아래 끝을 풀밭과 자연스럽게 잇는다
    // 덤불 한 덩이 = 크기가 다른 동그라미 셋 + 밝은 잎 (그림 속 풀밭 색에 맞춤)
    void bush(double x, double size) {
      final c = p(x, .975), k = w * size;
      final dark = Paint()..color = const Color(0xFF4F9332);
      final mid = Paint()..color = const Color(0xFF6DAE3F);
      final light = Paint()..color = const Color(0xFF9CCC65);
      canvas.drawCircle(c.translate(-k * .9, k * .25), k * .75, dark);
      canvas.drawCircle(c.translate(k * .9, k * .3), k * .7, dark);
      canvas.drawCircle(c, k, mid);
      canvas.drawCircle(c.translate(-k * .3, -k * .35), k * .35, light);
    }

    // 성문 앞(가운데)은 길이 이어지게 비워 둔다
    for (final (x, size) in const [(.03, .035), (.13, .03), (.25, .038), (.36, .028), (.64, .03), (.75, .038), (.87, .03), (.97, .035)]) {
      bush(x, size);
    }

    // 반짝임 (전설의 성)
    final star = Paint()..color = Colors.white.withValues(alpha: .9);
    for (final o in [const Offset(.18, .22), const Offset(.56, .12), const Offset(.93, .26)]) {
      final c = p(o.dx, o.dy), k = w * .018;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - k)
          ..lineTo(c.dx + k * .3, c.dy - k * .3)
          ..lineTo(c.dx + k, c.dy)
          ..lineTo(c.dx + k * .3, c.dy + k * .3)
          ..lineTo(c.dx, c.dy + k)
          ..lineTo(c.dx - k * .3, c.dy + k * .3)
          ..lineTo(c.dx - k, c.dy)
          ..lineTo(c.dx - k * .3, c.dy - k * .3)
          ..close(),
        star,
      );
    }
  }

  @override
  bool shouldRepaint(_CastlePainter old) => false;
}
