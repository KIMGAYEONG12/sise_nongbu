import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

/// 캐시(게임 안 재화) 표기: "1,200 캐시". 미션·업적·레벨업·판매 보상으로 받고 특별 상점에서 쓴다.
/// (작물을 사고파는 돈은 따로 'P'로 보인다 → [won])
String cash(num v) => '${commaNum(v)} 캐시';

/// 캐시 그림 모양: 동전 1개 · 동전 더미 · 복주머니 · 보물 상자 (시안의 "캐시 50 → 캐시 10,000")
enum CashKind { coin, stack, bag, chest }

/// 시안의 캐시 동전: 금빛 동전 가운데에 네잎클로버가 새겨져 있다. 코드로 그려서 크게 키워도 선명하다.
class CashCoin extends StatelessWidget {
  const CashCoin({super.key, this.size = 22, this.kind = CashKind.coin});
  final double size;
  final CashKind kind;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: CashPainter(kind: kind)),
      );
}

/// 캐시 그림을 그린다. 크기는 정사각형 기준.
class CashPainter extends CustomPainter {
  const CashPainter({this.kind = CashKind.coin});
  final CashKind kind;

  static const _rim = Color(0xFFD98200);
  static const _gold = Color(0xFFF6B21B);
  static const _goldLight = Color(0xFFFFE27A);
  static const _ink = Color(0xFF8A4B00);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    switch (kind) {
      case CashKind.coin:
        coin(canvas, Offset(s / 2, s / 2), s * .48);
      case CashKind.stack:
        _stack(canvas, s);
      case CashKind.bag:
        _bag(canvas, s);
      case CashKind.chest:
        _chest(canvas, s);
    }
    canvas.restore();
  }

  /// 동전 1개 (가운데 [c], 반지름 [r]): 두께 → 금빛 앞면 → 안쪽 테 → 네잎클로버 → 반짝임
  static void coin(Canvas canvas, Offset c, double r, {bool shine = true}) {
    final edge = r * .1;
    // 두께(아래쪽으로 살짝 보이는 진한 테두리)
    canvas.drawCircle(c + Offset(0, edge * .9), r, Paint()..color = const Color(0xFFB86A00));
    // 앞면
    final face = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.45), radius: 1.05, colors: [_goldLight, _gold, Color(0xFFE59200)], stops: [0, .55, 1]).createShader(face));
    canvas.drawCircle(c, r - edge * .35, Paint()..style = PaintingStyle.stroke..strokeWidth = edge * .7..color = _rim);
    // 안쪽 오목한 원
    final inner = r * .72;
    canvas.drawCircle(c, inner, Paint()..shader = const RadialGradient(center: Alignment(.3, .4), colors: [Color(0xFFFFD452), Color(0xFFF0A515)]).createShader(Rect.fromCircle(center: c, radius: inner)));
    canvas.drawCircle(c, inner, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(.8, r * .06)..color = const Color(0xFFFFF1B8).withValues(alpha: .9));
    // 네잎클로버 (잎 4장 + 줄기)
    final leaf = r * .2;
    final leafPaint = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF4C2), Color(0xFFFFD34D)]).createShader(Rect.fromCircle(center: Offset.zero, radius: leaf));
    final leafLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.7, r * .045)
      ..color = _ink.withValues(alpha: .55);
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 4 + i * math.pi / 2;
      final lc = c + Offset(math.cos(a), math.sin(a)) * leaf * 1.02;
      canvas.save();
      canvas.translate(lc.dx, lc.dy);
      canvas.rotate(a - math.pi / 2);
      final heart = _heart(leaf * 1.05);
      canvas.drawPath(heart, leafPaint);
      canvas.drawPath(heart, leafLine);
      canvas.restore();
    }
    final stem = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(c.dx + leaf * .5, c.dy + leaf * 1.4, c.dx + leaf * 1.2, c.dy + leaf * 2.1);
    canvas.drawPath(stem, Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = math.max(.8, r * .07)..color = _ink.withValues(alpha: .6));
    if (shine) {
      // 왼쪽 위 반짝임
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * .86), math.pi * 1.08, math.pi * .36, false,
          Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = math.max(1, r * .1)..color = Colors.white.withValues(alpha: .75));
    }
  }

  /// 하트 모양 잎 (원점 기준). 뾰족한 끝이 -y 쪽이라, 잎 방향으로 돌리면 끝이 동전 가운데를 향한다.
  static Path _heart(double r) => Path()
    ..moveTo(0, -r * .55)
    ..cubicTo(-r * 1.1, r * .05, -r * .55, r * .95, 0, r * .35)
    ..cubicTo(r * .55, r * .95, r * 1.1, r * .05, 0, -r * .55)
    ..close();

  /// 반짝이는 별(✦)
  static void sparkle(Canvas canvas, Offset c, double r, {Color color = Colors.white}) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  /// 옆에서 본 동전 한 닢 (더미용 납작한 원통)
  static void _flatCoin(Canvas canvas, Offset c, double w) {
    final h = w * .32, t = w * .12;
    final side = RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, t / 2), width: w, height: h + t), Radius.elliptical(w / 2, h / 2));
    canvas.drawRRect(side, Paint()..color = const Color(0xFFD38400));
    canvas.drawRRect(side, Paint()..style = PaintingStyle.stroke..strokeWidth = w * .03..color = const Color(0xFFA86200));
    final top = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawOval(top, Paint()..shader = const LinearGradient(colors: [_goldLight, _gold]).createShader(top));
    canvas.drawOval(top, Paint()..style = PaintingStyle.stroke..strokeWidth = w * .03..color = _rim);
    canvas.drawOval(top.deflate(w * .14), Paint()..style = PaintingStyle.stroke..strokeWidth = w * .025..color = const Color(0xFFFFF1B8));
  }

  void _stack(Canvas canvas, double s) {
    canvas.drawOval(Rect.fromCenter(center: Offset(s * .5, s * .92), width: s * .9, height: s * .1), Paint()..color = const Color(0x22000000));
    for (var i = 0; i < 4; i++) {
      _flatCoin(canvas, Offset(s * .32, s * .82 - i * s * .1), s * .5);
    }
    for (var i = 0; i < 3; i++) {
      _flatCoin(canvas, Offset(s * .68, s * .84 - i * s * .1), s * .48);
    }
    coin(canvas, Offset(s * .52, s * .3), s * .26);
    sparkle(canvas, Offset(s * .88, s * .18), s * .07);
  }

  void _bag(Canvas canvas, double s) {
    canvas.drawOval(Rect.fromCenter(center: Offset(s * .48, s * .93), width: s * .78, height: s * .1), Paint()..color = const Color(0x22000000));
    final body = Path()
      ..moveTo(s * .36, s * .3)
      ..cubicTo(s * .05, s * .45, s * .06, s * .92, s * .48, s * .92)
      ..cubicTo(s * .9, s * .92, s * .91, s * .45, s * .6, s * .3)
      ..close();
    final rect = Rect.fromLTWH(0, s * .25, s, s * .7);
    canvas.drawPath(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF1D6A2), Color(0xFFC79A5B)]).createShader(rect));
    canvas.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .025..color = const Color(0xFF8A6235));
    // 묶은 윗부분
    final neck = Path()
      ..moveTo(s * .34, s * .3)
      ..lineTo(s * .26, s * .12)
      ..quadraticBezierTo(s * .48, s * .2, s * .7, s * .12)
      ..lineTo(s * .62, s * .3)
      ..close();
    canvas.drawPath(neck, Paint()..color = const Color(0xFFE4C38A));
    canvas.drawPath(neck, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .025..color = const Color(0xFF8A6235));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .32, s * .27, s * .32, s * .06), Radius.circular(s * .03)), Paint()..color = const Color(0xFFB0412F));
    coin(canvas, Offset(s * .48, s * .6), s * .17, shine: false);
    coin(canvas, Offset(s * .82, s * .78), s * .13);
    sparkle(canvas, Offset(s * .84, s * .38), s * .06, color: const Color(0xFFFFE680));
  }

  void _chest(Canvas canvas, double s) {
    canvas.drawOval(Rect.fromCenter(center: Offset(s * .5, s * .92), width: s * .9, height: s * .1), Paint()..color = const Color(0x22000000));
    // 상자 몸통
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(s * .12, s * .48, s * .76, s * .42), Radius.circular(s * .05));
    canvas.drawRRect(box, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC0463A), Color(0xFF8E2A22)]).createShader(box.outerRect));
    canvas.drawRRect(box, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .025..color = const Color(0xFF5A1A12));
    // 쌓인 동전 (뚜껑 아래로 넘친다)
    for (var i = 0; i < 6; i++) {
      coin(canvas, Offset(s * (.22 + i * .11), s * (.44 - (i % 2) * .05)), s * .09, shine: false);
    }
    coin(canvas, Offset(s * .5, s * .34), s * .1);
    // 금빛 띠와 자물쇠
    final band = Paint()..color = const Color(0xFFF2B526);
    canvas.drawRect(Rect.fromLTWH(s * .12, s * .5, s * .76, s * .05), band);
    canvas.drawRect(Rect.fromLTWH(s * .2, s * .48, s * .05, s * .42), band);
    canvas.drawRect(Rect.fromLTWH(s * .75, s * .48, s * .05, s * .42), band);
    final lock = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * .5, s * .63), width: s * .14, height: s * .16), Radius.circular(s * .03));
    canvas.drawRRect(lock, Paint()..color = const Color(0xFFFFD34D));
    canvas.drawRRect(lock, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .02..color = const Color(0xFF8A4B00));
    canvas.drawCircle(Offset(s * .5, s * .62), s * .02, Paint()..color = const Color(0xFF5A3200));
    // 열린 뚜껑 (뒤로 젖혀진)
    final lid = Path()
      ..moveTo(s * .12, s * .4)
      ..quadraticBezierTo(s * .5, s * .06, s * .88, s * .4)
      ..lineTo(s * .84, s * .3)
      ..quadraticBezierTo(s * .5, s * .0, s * .16, s * .3)
      ..close();
    canvas.drawPath(lid, Paint()..color = const Color(0xFFA9362C));
    canvas.drawPath(lid, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .025..color = const Color(0xFF5A1A12));
    sparkle(canvas, Offset(s * .9, s * .2), s * .07, color: const Color(0xFFFFE680));
    sparkle(canvas, Offset(s * .1, s * .3), s * .05, color: const Color(0xFFFFE680));
  }

  @override
  bool shouldRepaint(CashPainter old) => old.kind != kind;
}

/// 보유 캐시 알약: 클로버 동전 + "1,200 캐시"
class CashPill extends StatelessWidget {
  const CashPill({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF2C14B), width: 1.3),
          boxShadow: [BoxShadow(color: const Color(0xFFE59200).withValues(alpha: .18), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const CashCoin(size: 20),
          const SizedBox(width: 4),
          Text(cash(amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Color(0xFF6A3D00))),
        ]),
      );
}
