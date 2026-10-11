import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 레벨에 따라 바뀌는 하우스 모양 (0 비닐하우스 · 1 유리 온실 · 2 스마트 온실 · 3 황금 온실 · 4 오토메이션 스마트팜 · 5 AI 퀀텀 팜).
/// 레벨이 오를수록 더 좋은 시설로 바뀐다.
int greenhouseTier(int level) => level >= 13
    ? 5
    : level >= 10
        ? 4
        : level >= 7
            ? 3
            : level >= 5
                ? 2
                : level >= 3
                    ? 1
                    : 0;

const greenhouseNames = ['비닐하우스', '유리 온실', '스마트 온실', '황금 온실', '오토메이션 스마트팜', 'AI 퀀텀 팜'];

const greenhouseMaxTier = 5;

/// 하우스 단계: 하우스를 한 채 지을 때마다 한 단계씩 올라가고, 레벨로 오른 모양 단계(0~5)만큼 더해진다. 하우스가 없으면 0.
int greenhouseStage(int level, int houses) => houses <= 0 ? 0 : houses + greenhouseTier(level);

/// 단계마다 다른 하우스 이름 (갈수록 더 최첨단)
const greenhouseStageNames = [
  '비닐하우스',
  '대형 비닐하우스',
  '유리 온실',
  '대형 유리 온실',
  '스마트 온실',
  '스마트 온실 프로',
  '황금 온실',
  '프리미엄 황금 온실',
  '오토메이션 스마트팜',
  '하이테크 스마트팜',
  'AI 퀀텀 팜',
  '나노 바이오 팜',
  '홀로그램 스마트팜',
  '플라즈마 에너지 팜',
  '위성 연동 스마트팜',
  '핵융합 에너지 팜',
  '우주 정거장 팜',
  '은하 바이오 돔',
  '초광속 양자 농장',
  '우주 문명 농장',
];

/// [stage]단계의 이름. 가장 높은 이름을 넘으면 "우주 문명 농장 2세대"처럼 세대가 붙는다.
String greenhouseStageName(int stage) {
  if (stage <= 0) return greenhouseStageNames.first;
  final n = greenhouseStageNames.length;
  if (stage <= n) return greenhouseStageNames[stage - 1];
  return '${greenhouseStageNames.last} ${stage - n + 1}세대';
}

/// [stage]단계에서 그리는 모양(0~5). 두 단계마다 모양이 한 번 바뀐다.
int greenhouseTierOfStage(int stage) => ((stage - 1) ~/ 2).clamp(0, greenhouseMaxTier).toInt();

/// [stage]단계의 크기 배율: 하우스를 지을 때마다 5%씩 커져서 최대 1.5배.
double greenhouseSizeScale(int stage) => (1 + 0.05 * (stage - 1)).clamp(1.0, 1.5).toDouble();

/// 레벨과 지은 하우스 수에 맞는 모양(0~5)
int greenhouseTierFor(int level, int houses) => greenhouseTierOfStage(greenhouseStage(level, houses));

/// 각 모양이 처음 나타나는 레벨 (greenhouseTier 와 같은 기준)
const greenhouseTierLevels = [1, 3, 5, 7, 10, 13];

/// 하우스 그림: 레벨(tier)이 오를 때마다 모양이 바뀐다. 모두 코드로 그려서 확대해도 선명하다.
/// 0 비닐하우스: 나무 뼈대에 비닐을 씌운 둥근 터널 · 1 유리 온실: 흰 철제 뼈대와 유리 지붕 ·
/// 2 스마트 온실: 파란 유리 + 지붕 태양광 패널 · 3 황금 온실: 금빛 뼈대와 깃발, 반짝이는 별.
class GreenhousePainter extends CustomPainter {
  const GreenhousePainter({this.count = 1, this.tier = 1, this.name, this.stage = 0});

  /// 지은 하우스 수 (이름표에 "하우스 ×3"으로 보여준다)
  final int count;

  /// 하우스 모양 단계 (0~5)
  final int tier;

  /// 이름표에 쓸 이름 (없으면 모양 단계의 기본 이름)
  final String? name;

  /// 하우스 단계. 11단계(AI 퀀텀 팜)부터는 단계마다 첨단 장치가 하나씩 더 붙는다 (0이면 모양 단계만으로 그린다).
  final int stage;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = tier.clamp(0, greenhouseMaxTier);
    Offset p(double x, double y) => Offset(x * w, y * h);
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double lw) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    // 단계별 색
    final frame = [
      const Color(0xFFB9824A),
      Colors.white,
      const Color(0xFFEAF2F8),
      const Color(0xFFE0A100), // 황금 온실: 진한 금색 뼈대
      const Color(0xFFF5D76E),
      const Color(0xFF7DF9FF),
    ][t];
    final glass = [
      [const Color(0x80F4FFF0), const Color(0x60D9F0C8), const Color(0x70E6F7DA)],
      [const Color(0x80EAF8FF), const Color(0x60B9E4F4), const Color(0x70D5F1FA)],
      [const Color(0x998FC8F5), const Color(0x775B9FE0), const Color(0x889CCBF2)],
      [const Color(0xCCFFE27A), const Color(0xBBFFC93C), const Color(0xCCFFD95A)], // 황금 온실: 유리가 금빛으로 짙게 물든다
      [const Color(0xAA7FE8D8), const Color(0x8837B8B0), const Color(0x9960E0D0)],
      [const Color(0xAA9B8CFF), const Color(0x886A5BE0), const Color(0xAAB7A6FF)],
    ][t];
    final gable = t >= 2;
    final gold = t == 3;

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
    final bedColors = t == 3
        ? const [Color(0xFFF2B93B), Color(0xFFB57A12)]
        : t >= 4
            ? const [Color(0xFF55657A), Color(0xFF2B3744)]
            : const [Color(0xFFB9824A), Color(0xFF8A5530)];
    canvas.drawRRect(bed, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bedColors).createShader(bed.outerRect));
    canvas.drawRRect(bed, line(const Color(0xFF6B3F1F), 1.2));
    canvas.drawLine(p(.04, .905), p(.96, .905), line(const Color(0x33FFFFFF), 1));

    // 안에서 자라는 작물: 단계가 오를수록 풍성해진다.
    // 유리가 짙은 황금/첨단 온실(3단계 이상)은 유리 뒤에 그리면 가려지므로 유리 위에 그려서 작물이 또렷하게 보이게 한다.
    void paintCrops() {
      final big = t >= 3 ? 1.3 : 1.0;
      canvas.drawRect(Rect.fromLTRB(w * left, h * (base - .14), w * right, h * base), fill(const Color(0x55FFFFFF)));
      final fruit = [const Color(0xFFE5483B), const Color(0xFFE5483B), const Color(0xFFFF7A2F), const Color(0xFFFFC21A), const Color(0xFFFF5C8A), const Color(0xFFB9FF5C)][t];
      for (var i = 0; i < 5; i++) {
        final x = .16 + i * .17;
        canvas.drawLine(p(x, base), p(x, base - .24), line(const Color(0xFF3F8F2E), 2.2));
        for (final d in const [(-.04, .1), (.04, .15), (-.035, .2), (.04, .24)]) {
          canvas.drawOval(Rect.fromCenter(center: p(x + d.$1, base - d.$2), width: w * .075 * big, height: h * .045 * big), fill(i.isEven ? const Color(0xFF55B23A) : const Color(0xFF3F9E35)));
        }
        for (final d in t == 0 ? const [(.03, .08)] : const [(.03, .08), (-.03, .17), (.035, .22)]) {
          canvas.drawCircle(p(x + d.$1, base - d.$2), w * .017 * big, fill(fruit));
          canvas.drawCircle(p(x + d.$1 - .005, base - d.$2 - .008), w * .005, fill(const Color(0xAAFFFFFF)));
        }
      }
    }

    if (t < 3) paintCrops();

    // 몸체 (둥근 터널 또는 뾰족 지붕)
    final body = Path()..moveTo(w * left, h * base)..lineTo(w * left, h * wallTop);
    if (gable) {
      body..lineTo(w * cx, h * apex)..lineTo(w * right, h * wallTop);
    } else {
      body.arcTo(Rect.fromLTRB(w * left, h * (wallTop - ry), w * right, h * (wallTop + ry)), math.pi, math.pi, false);
    }
    body..lineTo(w * right, h * base)..close();
    if (t >= 3) {
      // 황금/첨단 온실은 몸체 둘레에 빛이 번진다
      final glow = [const Color(0xFFFFD34E), const Color(0xFF7DF9FF), const Color(0xFFB7A6FF)][t - 3];
      canvas.drawPath(body, Paint()..color = glow.withValues(alpha: gold ? .75 : .55)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (gold ? .045 : .035)));
    }
    canvas.drawPath(body, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: glass).createShader(Offset.zero & size));
    if (gold) {
      // 금빛 광택: 위쪽이 밝고 아래로 갈수록 짙은 금색
      canvas.drawPath(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66FFF6C2), Color(0x00FFFFFF), Color(0x55C98A00)]).createShader(Offset.zero & size));
    }

    if (t >= 3) paintCrops();

    // 유리·비닐에 비친 빛 줄기
    canvas.save();
    canvas.clipPath(body);
    for (final x in [.2, .3]) {
      canvas.drawPath(Path()..moveTo(w * x, h * .05)..lineTo(w * (x + .07), h * .05)..lineTo(w * (x - .08), h * base)..lineTo(w * (x - .15), h * base)..close(), fill(const Color(0x33FFFFFF)));
    }
    canvas.restore();

    // 뼈대
    final steel = line(frame, w * (t == 0 ? .02 : (gold ? .026 : .016)));
    canvas.drawPath(body, steel);
    for (final k in const [-.62, -.3, 0.0, .3, .62]) {
      final x = cx + k * rx;
      canvas.drawLine(p(x, roofY(x)), p(x, base), line(frame.withValues(alpha: .92), w * .01));
    }
    canvas.drawLine(p(left, wallTop), p(right, wallTop), line(frame.withValues(alpha: .92), w * .01));
    canvas.drawLine(p(left, .7), p(right, .7), line(frame.withValues(alpha: .85), w * .008));
    if (t >= 1) {
      // 온실 유리 칸 느낌의 가로 살
      for (final y in const [.6, .8]) {
        canvas.drawLine(p(left, y), p(right, y), line(frame.withValues(alpha: .55), w * .006));
      }
    }

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
    if (t >= 4) {
      // 지붕 위 안테나 + 깜빡이는 센서 불빛
      canvas.drawLine(p(cx, apex), p(cx, apex - .12), line(frame, 2));
      canvas.drawCircle(p(cx, apex - .12), w * .02, fill(t == 4 ? const Color(0xFFFFF3A0) : const Color(0xFFFFFFFF)));
      canvas.drawCircle(p(cx, apex - .12), w * .035, Paint()..color = frame.withValues(alpha: .5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      for (final s in const [(.12, .3), (.88, .34), (.2, .62), (.82, .66)]) {
        canvas.drawCircle(p(s.$1, s.$2), w * .012, fill(frame.withValues(alpha: .9)));
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

    // 11단계(AI 퀀텀 팜)부터는 단계가 오를 때마다 첨단 장치가 하나씩 더 붙는다 (앞 단계 장치는 그대로 유지)
    if (stage >= 11) _drawTech(canvas, size, stage, frame);

    // 이름표
    final name = this.name ?? greenhouseNames[t];
    final tp = TextPainter(
      text: TextSpan(text: name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1B4D2B))),
      textDirection: TextDirection.ltr,
    )..layout();
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: p(.5, -.04), width: tp.width + 18, height: tp.height + 8), const Radius.circular(12));
    canvas.drawRRect(tag.shift(const Offset(0, 2)), fill(const Color(0x33000000)));
    canvas.drawRRect(tag, fill(Colors.white));
    tp.paint(canvas, Offset(tag.center.dx - tp.width / 2, tag.center.dy - tp.height / 2));
  }


  /// 11단계 이후의 첨단 장치들. 위성 연동 스마트팜(15단계)에는 지붕 위 위성과 신호가 나온다.
  void _drawTech(Canvas canvas, Size size, int stage, Color frame) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double lw) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw
      ..strokeCap = StrokeCap.round
      ..color = c;
    Paint glow(Color c, double r) => Paint()
      ..color = c
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r);

    // 11 AI 퀀텀 팜: 지붕 가운데 AI 칩
    final chip = RRect.fromRectAndRadius(Rect.fromCenter(center: p(.5, .3), width: w * .13, height: h * .09), Radius.circular(w * .02));
    canvas.drawRRect(chip, glow(const Color(0xAA7DF9FF), 4));
    canvas.drawRRect(chip, fill(const Color(0xFF14233A)));
    canvas.drawRRect(chip, line(const Color(0xFF7DF9FF), 1.2));
    final ai = TextPainter(text: const TextSpan(text: 'AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF7DF9FF))), textDirection: TextDirection.ltr)..layout();
    ai.paint(canvas, p(.5, .3) - Offset(ai.width / 2, ai.height / 2));

    // 12 나노 바이오 팜: 안에서 떠다니는 초록 나노 입자
    if (stage >= 12) {
      for (final d in const [(.2, .55), (.34, .66), (.66, .6), (.8, .68), (.5, .74), (.28, .46), (.72, .46)]) {
        canvas.drawCircle(p(d.$1, d.$2), w * .016, glow(const Color(0xCC9BFF7A), 3));
        canvas.drawCircle(p(d.$1, d.$2), w * .008, fill(const Color(0xFFE9FFD0)));
      }
    }

    // 13 홀로그램 스마트팜: 지붕을 감싸는 파란 홀로그램 호
    if (stage >= 13) {
      for (final r in const [.34, .44]) {
        canvas.drawArc(Rect.fromCenter(center: p(.5, .56), width: w * r * 2.2, height: h * r * 1.7), math.pi * 1.05, math.pi * .9, false, line(const Color(0x887DD3FF), 1.2));
      }
    }

    // 14 플라즈마 에너지 팜: 꼭대기의 분홍빛 플라즈마 구슬
    if (stage >= 14) {
      canvas.drawCircle(p(.5, .06), w * .05, glow(const Color(0xCCFF5CE1), 5));
      canvas.drawCircle(p(.5, .06), w * .024, fill(const Color(0xFFFFE0FA)));
    }

    // 15 위성 연동 스마트팜: 오른쪽 위에 위성이 떠 있고, 지붕으로 신호를 보낸다
    if (stage >= 15) {
      final sat = p(.86, .06);
      // 신호 줄기 (점선)와 동그란 신호 물결
      final beam = Path()..moveTo(sat.dx - w * .03, sat.dy + h * .05)..lineTo(p(.6, .27).dx, p(.6, .27).dy);
      for (final m in beam.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 7) {
          canvas.drawPath(m.extractPath(d, math.min(d + 3.5, m.length)), line(const Color(0xCCFFE066), 1.4));
        }
      }
      for (final r in const [.045, .075, .105]) {
        canvas.drawArc(Rect.fromCenter(center: sat + Offset(-w * .03, h * .05), width: w * r * 2, height: w * r * 2), math.pi * .55, math.pi * .45, false, line(const Color(0x99FFE066), 1.2));
      }
      canvas.save();
      canvas.translate(sat.dx, sat.dy);
      canvas.rotate(-.5);
      final unit = w * .042;
      // 태양광 날개 두 장
      for (final side in const [-1.0, 1.0]) {
        final wing = Rect.fromLTWH(side < 0 ? -unit * 3.6 : unit * 1.0, -unit * .8, unit * 2.6, unit * 1.6);
        canvas.drawRect(wing, fill(const Color(0xFF2A5BC0)));
        canvas.drawRect(wing, line(Colors.white, .8));
        canvas.drawLine(Offset(wing.center.dx, wing.top), Offset(wing.center.dx, wing.bottom), line(Colors.white70, .6));
        canvas.drawLine(Offset(wing.left, wing.center.dy), Offset(wing.right, wing.center.dy), line(Colors.white70, .6));
      }
      // 몸체와 접시 안테나
      final bodyRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: unit * 2, height: unit * 1.6), Radius.circular(unit * .3));
      canvas.drawRRect(bodyRect, fill(const Color(0xFFE8EDF3)));
      canvas.drawRRect(bodyRect, line(const Color(0xFF52687C), 1));
      canvas.drawCircle(Offset(0, unit * 1.3), unit * .7, fill(const Color(0xFFFFD34E)));
      canvas.drawLine(Offset(0, unit * .8), Offset(0, unit * 1.3), line(const Color(0xFF52687C), 1));
      canvas.drawCircle(Offset.zero, unit * .35, fill(const Color(0xFF7DF9FF)));
      canvas.restore();
    }

    // 16 핵융합 에너지 팜: 안쪽 가운데의 밝은 에너지 코어
    if (stage >= 16) {
      canvas.drawCircle(p(.5, .66), w * .06, glow(const Color(0xCCFFB84A), 6));
      canvas.drawCircle(p(.5, .66), w * .026, fill(const Color(0xFFFFF6D0)));
      canvas.drawCircle(p(.5, .66), w * .05, line(const Color(0xAAFFD34E), 1.2));
    }

    // 17 우주 정거장 팜: 하우스를 감싸는 궤도 고리
    if (stage >= 17) {
      final ring = Rect.fromCenter(center: p(.5, .56), width: w * 1.08, height: h * .26);
      canvas.drawOval(ring, line(const Color(0x99C9D6E8), 1.6));
      canvas.drawCircle(Offset(ring.left, ring.center.dy), w * .016, fill(const Color(0xFFE8EDF3)));
      canvas.drawCircle(Offset(ring.right, ring.center.dy), w * .016, fill(const Color(0xFFE8EDF3)));
    }

    // 18 은하 바이오 돔: 왼쪽 위 나선 은하
    if (stage >= 18) {
      for (var i = 0; i < 18; i++) {
        final a = i * .55, r = w * (.01 + i * .004);
        canvas.drawCircle(p(.12, .1) + Offset(math.cos(a) * r, math.sin(a) * r * .7), w * .006, fill(Colors.white.withValues(alpha: .35 + i / 40)));
      }
    }

    // 19 초광속 양자 농장: 옆으로 흐르는 광속 줄무늬
    if (stage >= 19) {
      for (final y in const [.4, .5, .6]) {
        canvas.drawLine(p(-.02, y), p(.1, y), line(const Color(0x887DF9FF), 1.4));
      }
    }

    // 20 우주 문명 농장: 고리가 있는 행성
    if (stage >= 20) {
      final pl = p(.2, .04);
      canvas.drawCircle(pl, w * .035, fill(const Color(0xFFFF9A5C)));
      canvas.drawOval(Rect.fromCenter(center: pl, width: w * .1, height: h * .03), line(const Color(0xCCFFE0B0), 1.2));
    }
  }

  @override
  bool shouldRepaint(GreenhousePainter old) => old.tier != tier || old.count != count || old.name != name || old.stage != stage;
}
