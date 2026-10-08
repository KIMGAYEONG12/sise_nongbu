import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 레벨에 따라 바뀌는 하우스 모양 (0 비닐하우스 · 1 유리 온실 · 2 스마트 온실 · 3 황금 온실)
int greenhouseTier(int level) => level >= 7
    ? 3
    : level >= 5
        ? 2
        : level >= 3
            ? 1
            : 0;

const greenhouseNames = ['비닐하우스', '유리 온실', '스마트 온실', '황금 온실'];

/// 하우스 그림: 레벨(tier)이 오를 때마다 모양이 바뀐다. 모두 코드로 그려서 확대해도 선명하다.
/// 0 비닐하우스: 나무 뼈대에 비닐을 씌운 둥근 터널 · 1 유리 온실: 흰 철제 뼈대와 유리 지붕 ·
/// 2 스마트 온실: 파란 유리 + 지붕 태양광 패널 · 3 황금 온실: 금빛 뼈대와 깃발, 반짝이는 별.
class GreenhousePainter extends CustomPainter {
  const GreenhousePainter({this.count = 1, this.tier = 1});

  /// 지은 하우스 수 (이름표에 "하우스 ×3"으로 보여준다)
  final int count;

  /// 하우스 모양 단계 (0~3)
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = tier.clamp(0, 3);
    Offset p(double x, double y) => Offset(x * w, y * h);
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double lw) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    // 단계별 색
    final frame = [const Color(0xFFB9824A), Colors.white, const Color(0xFFEAF2F8), const Color(0xFFF2C14B)][t];
    final glass = [
      [const Color(0x66F4FFF0), const Color(0x44D9F0C8), const Color(0x55E6F7DA)],
      [const Color(0x66EAF8FF), const Color(0x40B9E4F4), const Color(0x55D5F1FA)],
      [const Color(0x778FC8F5), const Color(0x555B9FE0), const Color(0x669CCBF2)],
      [const Color(0x66FFF3B8), const Color(0x55FFD66B), const Color(0x66FFE9A0)],
    ][t];
    final gable = t >= 2;

    const left = .05, right = .95, base = .86, wallTop = .5;
    const cx = (left + right) / 2, rx = (right - left) / 2, ry = .4;
    const apex = .1;
    double roofY(double x) {
      if (gable) return wallTop - (wallTop - apex) * (1 - ((x - cx).abs() / rx).clamp(0.0, 1.0));
      return wallTop - ry * math.sqrt((1 - math.pow((x - cx) / rx, 2)).clamp(0.0, 1.0).toDouble());
    }

    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: p(.5, .95), width: w * 1.0, height: h * .13), fill(const Color(0x40000000)));
    // 화단
    final bed = RRect.fromRectAndRadius(Rect.fromLTRB(w * .02, h * base - h * .01, w * .98, h * .96), Radius.circular(w * .03));
    final bedColors = t == 3 ? const [Color(0xFFD9A441), Color(0xFF9C6B1E)] : const [Color(0xFFB9824A), Color(0xFF8A5530)];
    canvas.drawRRect(bed, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bedColors).createShader(bed.outerRect));
    canvas.drawRRect(bed, line(const Color(0xFF6B3F1F), 1.2));
    canvas.drawLine(p(.04, .905), p(.96, .905), line(const Color(0x33FFFFFF), 1));

    // 안에서 자라는 작물 (유리 뒤에 먼저 그린다): 단계가 오를수록 작물이 풍성해진다
    canvas.drawRect(Rect.fromLTRB(w * left, h * (base - .14), w * right, h * base), fill(const Color(0x55FFFFFF)));
    final fruit = [const Color(0xFFE5483B), const Color(0xFFE5483B), const Color(0xFFFF7A2F), const Color(0xFFFFC21A)][t];
    for (var i = 0; i < 5; i++) {
      final x = .16 + i * .17;
      canvas.drawLine(p(x, base), p(x, base - .24), line(const Color(0xFF3F8F2E), 2.2));
      for (final d in const [(-.04, .1), (.04, .15), (-.035, .2), (.04, .24)]) {
        canvas.drawOval(Rect.fromCenter(center: p(x + d.$1, base - d.$2), width: w * .075, height: h * .045), fill(i.isEven ? const Color(0xFF55B23A) : const Color(0xFF3F9E35)));
      }
      for (final d in t == 0 ? const [(.03, .08)] : const [(.03, .08), (-.03, .17), (.035, .22)]) {
        canvas.drawCircle(p(x + d.$1, base - d.$2), w * .017, fill(fruit));
        canvas.drawCircle(p(x + d.$1 - .005, base - d.$2 - .008), w * .005, fill(const Color(0xAAFFFFFF)));
      }
    }

    // 몸체 (둥근 터널 또는 뾰족 지붕)
    final body = Path()..moveTo(w * left, h * base)..lineTo(w * left, h * wallTop);
    if (gable) {
      body..lineTo(w * cx, h * apex)..lineTo(w * right, h * wallTop);
    } else {
      body.arcTo(Rect.fromLTRB(w * left, h * (wallTop - ry), w * right, h * (wallTop + ry)), math.pi, math.pi, false);
    }
    body..lineTo(w * right, h * base)..close();
    canvas.drawPath(body, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: glass).createShader(Offset.zero & size));

    // 유리·비닐에 비친 빛 줄기
    canvas.save();
    canvas.clipPath(body);
    for (final x in [.2, .3]) {
      canvas.drawPath(Path()..moveTo(w * x, h * .05)..lineTo(w * (x + .07), h * .05)..lineTo(w * (x - .08), h * base)..lineTo(w * (x - .15), h * base)..close(), fill(const Color(0x33FFFFFF)));
    }
    canvas.restore();

    // 뼈대
    final steel = line(frame, w * (t == 0 ? .02 : .016));
    canvas.drawPath(body, steel);
    for (final k in const [-.62, -.3, 0.0, .3, .62]) {
      final x = cx + k * rx;
      canvas.drawLine(p(x, roofY(x)), p(x, base), line(frame.withValues(alpha: .92), w * .01));
    }
    canvas.drawLine(p(left, wallTop), p(right, wallTop), line(frame.withValues(alpha: .92), w * .01));
    canvas.drawLine(p(left, .7), p(right, .7), line(frame.withValues(alpha: .85), w * .008));

    if (t == 0) {
      // 비닐 끈
      for (final y in const [.62, .76]) {
        canvas.drawLine(p(left, y), p(right, y), line(const Color(0x55FFFFFF), 1));
      }
    } else if (t == 1) {
      // 지붕 환기창
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p(cx, .125), width: w * .1, height: h * .035), Radius.circular(w * .01)), fill(Colors.white));
    } else {
      // 지붕 태양광 패널
      for (final side in const [-1.0, 1.0]) {
        final a = p(cx + side * .06, .2 + .02), b = p(cx + side * .34, wallTop - .12);
        final panel = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(b.dx, b.dy + h * .09)..lineTo(a.dx, a.dy + h * .09)..close();
        canvas.drawPath(panel, fill(const Color(0xFF1F3F7A)));
        canvas.drawPath(panel, line(Colors.white, 1));
        canvas.drawLine(Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2), Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + h * .09), line(Colors.white70, .8));
      }
    }
    if (t == 3) {
      // 꼭대기 깃발 + 별빛
      canvas.drawLine(p(cx, apex), p(cx, apex - .1), line(const Color(0xFF8C5A1C), 2));
      final flag = Path()..moveTo(w * cx, h * (apex - .1))..lineTo(w * (cx + .09), h * (apex - .075))..lineTo(w * cx, h * (apex - .05))..close();
      canvas.drawPath(flag, fill(const Color(0xFFE5483B)));
      for (final s in const [(.12, .3), (.88, .34), (.2, .62), (.82, .66)]) {
        final c = p(s.$1, s.$2);
        final star = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4, r = i.isEven ? w * .03 : w * .01;
          final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(star..close(), fill(const Color(0xCCFFF6C2)));
      }
    }

    // 문 (양쪽으로 열림)
    final door = Rect.fromLTRB(w * .41, h * .58, w * .59, h * base);
    canvas.drawRRect(RRect.fromRectAndRadius(door, Radius.circular(w * .012)), fill(const Color(0x55FFFFFF)));
    canvas.drawRRect(RRect.fromRectAndRadius(door, Radius.circular(w * .012)), line(frame, w * .014));
    canvas.drawLine(p(cx, .58), p(cx, base), line(frame, w * .012));
    canvas.drawCircle(p(cx - .02, .72), w * .008, fill(const Color(0xFFE0A800)));
    canvas.drawCircle(p(cx + .02, .72), w * .008, fill(const Color(0xFFE0A800)));

    // 이름표
    final name = greenhouseNames[t];
    final tp = TextPainter(
      text: TextSpan(text: count > 1 ? '$name ×$count' : name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1B4D2B))),
      textDirection: TextDirection.ltr,
    )..layout();
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: p(.5, -.04), width: tp.width + 18, height: tp.height + 8), const Radius.circular(12));
    canvas.drawRRect(tag.shift(const Offset(0, 2)), fill(const Color(0x33000000)));
    canvas.drawRRect(tag, fill(Colors.white));
    tp.paint(canvas, Offset(tag.center.dx - tp.width / 2, tag.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(GreenhousePainter old) => old.tier != tier || old.count != count;
}
