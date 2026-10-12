import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'farm_life.dart' show FarmRobotPainter;

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
  const GreenhousePainter({this.count = 1, this.tier = 1, this.name, this.stage = 0, this.anim}) : super(repaint: anim);

  /// 0~1을 되풀이하는 움직임 시간. 있으면 안의 작물이 살랑이고 위성·신호·별이 움직인다. null이면 멈춘 그림.
  final Animation<double>? anim;

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
    // 움직임 시간 0~1. 위성·작물·불빛은 한 바퀴에 3번 되풀이(빠름), 로봇은 한 바퀴에 한 번(느림)
    final slow = anim?.value ?? 0.0;
    final a = (slow * 3) % 1.0;
    final a2 = a * math.pi * 2;
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
        // 위로 갈수록 더 크게 흔들리는 줄기 (뿌리는 그대로)
        final sw = math.sin(a2 + i * 1.1) * .016;
        double bend(double height) => sw * (height / .24);
        canvas.drawLine(p(x, base), p(x + sw, base - .24), line(const Color(0xFF3F8F2E), 2.2));
        for (final d in const [(-.04, .1), (.04, .15), (-.035, .2), (.04, .24)]) {
          canvas.drawOval(Rect.fromCenter(center: p(x + d.$1 + bend(d.$2), base - d.$2), width: w * .075 * big, height: h * .045 * big), fill(i.isEven ? const Color(0xFF55B23A) : const Color(0xFF3F9E35)));
        }
        for (final d in t == 0 ? const [(.03, .08)] : const [(.03, .08), (-.03, .17), (.035, .22)]) {
          canvas.drawCircle(p(x + d.$1 + bend(d.$2), base - d.$2), w * .017 * big, fill(fruit));
          canvas.drawCircle(p(x + d.$1 + bend(d.$2) - .005, base - d.$2 - .008), w * .005, fill(const Color(0xAAFFFFFF)));
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
    if (stage >= 11) _drawTech(canvas, size, stage, frame, a);

    // 하우스 안에서 작물에 물을 주는 농장 로봇 (하우스를 지으면 밖을 순찰하던 로봇이 안으로 들어온다).
    // 에너지 코어 같은 장치보다 앞에 그려서 로봇이 가려지지 않는다.
    _drawRobot(canvas, size, slow * math.pi * 2, base);

    // 이름표
    final name = this.name ?? greenhouseNames[t];
    final tp = TextPainter(
      text: TextSpan(text: name, style: const TextStyle(fontFamily: 'NotoSansKR', fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1B4D2B))),
      textDirection: TextDirection.ltr,
    )..layout();
    final tag = RRect.fromRectAndRadius(Rect.fromCenter(center: p(.5, -.04), width: tp.width + 18, height: tp.height + 8), const Radius.circular(12));
    canvas.drawRRect(tag.shift(const Offset(0, 2)), fill(const Color(0x33000000)));
    canvas.drawRRect(tag, fill(Colors.white));
    tp.paint(canvas, Offset(tag.center.dx - tp.width / 2, tag.center.dy - tp.height / 2));
  }


  /// 하우스 안을 왼쪽·오른쪽으로 오가며 작물에 물을 주는 로봇. 오른쪽으로 갈 때 물을 뿌리고, 방향을 바꿀 때 몸을 돌린다.
  void _drawRobot(Canvas canvas, Size size, double a2, double base) {
    final w = size.width, h = size.height;
    final rw = w * .12, rh = h * .205; // 작은 로봇
    final s = math.sin(a2); // -1(왼쪽 끝) ~ 1(오른쪽 끝)
    final goingRight = math.cos(a2) >= 0;
    final cx = w * (.5 + .25 * s);
    canvas.save();
    canvas.translate(cx - rw / 2, h * (base - .005) - rh);
    if (!goingRight) {
      canvas.translate(rw, 0);
      canvas.scale(-1, 1); // 왼쪽으로 갈 때는 몸을 돌린다
    }
    final tt = a2 / (math.pi * 2);
    FarmRobotPainter(t: tt, watering: false).paint(canvas, Size(rw, rh));
    // 물 주는 모습: 앞으로 내민 팔(오른쪽 위)에서 물방울이 포물선으로 퍼지며 작물 위로 떨어진다.
    // (로봇 그림 안의 물방울은 크기에 비례해 1픽셀도 안 돼서 안 보였다 → 하우스 크기에 맞춰 크게 따로 그린다)
    final arm = Offset(rw * 1.0, rh * .52);
    final ground = h * (base - .03) - (h * (base - .005) - rh); // 로봇 좌표에서 밭 높이
    for (var i = 0; i < 7; i++) {
      final f = (tt * 24 + i / 7) % 1.0; // 한 방울이 떨어지는 시간 (빠르게 계속 이어진다)
      final dx = rw * (.12 + .5 * f) + rw * .06 * i / 7; // 앞으로 퍼져 나간다
      final dy = (ground - arm.dy) * f * f; // 아래로 갈수록 빨라진다
      final c = arm + Offset(dx, dy);
      final r = w * .017 * (1 - .3 * f);
      canvas.drawCircle(c, r + 1.2, Paint()..color = const Color(0x66BFE8FF).withValues(alpha: .4 * (1 - f)));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3CA7F0).withValues(alpha: .95 - .6 * f));
      canvas.drawCircle(c.translate(-r * .3, -r * .3), r * .35, Paint()..color = const Color(0xCCFFFFFF));
    }
    // 물이 닿는 작물 위의 작은 물결
    final splash = Offset(arm.dx + rw * .62, ground);
    final ps = (tt * 24) % 1.0;
    canvas.drawOval(Rect.fromCenter(center: splash, width: rw * (.5 + .5 * ps), height: rw * .16), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFBFE8FF).withValues(alpha: .8 * (1 - ps)));
    canvas.restore();
  }

  /// 위성: 금박 몸체, 격자무늬 파란 태양광 날개, 접시 안테나, 반짝이는 신호.
  /// 오른쪽 위에 떠 있으면서 지붕 쪽으로 점선 신호와 물결을 보낸다.
  void _drawSatellite(Canvas canvas, Size size, double a) {
    final a2 = a * math.pi * 2;
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double lw) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    // 천천히 둥실 떠다니며(위아래·좌우) 살짝 기울어진다
    final sat = p(.86 + math.sin(a2) * .014, .07 + math.cos(a2 * 1.0 + 1.2) * .016);
    final unit = w * .034; // 위성 크기 (조금 작게)

    // 지붕으로 보내는 점선 신호
    final from = sat + Offset(-unit * .6, unit * 1.9);
    final to = p(.6, .27);
    final beam = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);
    // 점선이 지붕 쪽으로 흘러간다 (한 바퀴에 두 칸씩)
    final phase = (a * 14) % 7.0;
    for (final m in beam.computeMetrics()) {
      for (var d = phase - 7; d < m.length; d += 7) {
        final start = math.max(0.0, d), end = math.min(d + 3.5, m.length);
        if (end <= start) continue;
        final k = start / m.length; // 지붕에 가까울수록 또렷하게
        canvas.drawPath(m.extractPath(start, end), line(const Color(0xFFFFE066).withValues(alpha: .35 + .6 * k), 1.5));
      }
    }
    // 위성 아래로 퍼지는 신호 물결
    // 물결이 안쪽에서 바깥으로 차례로 퍼진다
    var ring = 0;
    for (final r in const [.05, .08, .11]) {
      final glowK = .5 + .5 * math.sin(a2 * 2 - ring * 1.1);
      canvas.drawArc(Rect.fromCenter(center: from, width: w * r * 2, height: w * r * 2), math.pi * .5, math.pi * .5, false, line(const Color(0xFFFFE066).withValues(alpha: (.85 - r * 4) * (.35 + .65 * glowK)), 1.3));
      ring++;
    }

    canvas.save();
    canvas.translate(sat.dx, sat.dy);
    canvas.rotate(-.42 + math.sin(a2 + .6) * .07);

    // 뒤에서 은은하게 빛나는 기운
    canvas.drawCircle(Offset.zero, unit * 3.4, Paint()..shader = const RadialGradient(colors: [Color(0x887DF9FF), Color(0x007DF9FF)]).createShader(Rect.fromCircle(center: Offset.zero, radius: unit * 3.4)));

    // 태양광 날개: 은색 뼈대 + 파란 패널(격자 + 빛 반사)
    for (final side in const [-1.0, 1.0]) {
      // 날개를 잇는 은색 막대
      canvas.drawLine(Offset(side * unit * .9, 0), Offset(side * unit * 1.5, 0), line(const Color(0xFFC9D4E2), unit * .22));
      for (var k = 0; k < 2; k++) {
        final left = side < 0 ? -unit * (1.5 + (k + 1) * 1.9) + unit * .0 : unit * (1.5 + k * 1.9);
        final rect = Rect.fromLTWH(left + (side < 0 ? unit * .0 : unit * .0), -unit * .95, unit * 1.8, unit * 1.9);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(unit * .12));
        canvas.drawRRect(rr, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4C8DF0), Color(0xFF1B44A8)]).createShader(rect));
        // 격자
        final grid = line(const Color(0x88CFE3FF), .7);
        for (var i = 1; i < 3; i++) {
          canvas.drawLine(Offset(rect.left + rect.width * i / 3, rect.top), Offset(rect.left + rect.width * i / 3, rect.bottom), grid);
        }
        for (var i = 1; i < 4; i++) {
          canvas.drawLine(Offset(rect.left, rect.top + rect.height * i / 4), Offset(rect.right, rect.top + rect.height * i / 4), grid);
        }
        // 빛 반사
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawPath(
          Path()
            ..moveTo(rect.left, rect.top + rect.height * .55)
            ..lineTo(rect.left + rect.width * .55, rect.top)
            ..lineTo(rect.left + rect.width * .8, rect.top)
            ..lineTo(rect.left, rect.top + rect.height * .85)
            ..close(),
          fill(const Color(0x33FFFFFF)),
        );
        canvas.restore();
        canvas.drawRRect(rr, line(const Color(0xFFE3ECF7), 1));
      }
    }

    // 금박 몸체
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: unit * 1.8, height: unit * 1.9), Radius.circular(unit * .3));
    canvas.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9A0), Color(0xFFE9AE24), Color(0xFFB57B10)]).createShader(body.outerRect));
    canvas.save();
    canvas.clipRRect(body);
    final crinkle = line(const Color(0x55FFFFFF), .8);
    for (final d in const [(-.5, -.6, .4, -.1), (-.6, .1, .2, .5), (.1, -.7, .6, -.2), (-.1, .5, .6, .7)]) {
      canvas.drawLine(Offset(d.$1 * unit, d.$2 * unit), Offset(d.$3 * unit, d.$4 * unit), crinkle);
    }
    canvas.drawRect(Rect.fromLTRB(-unit * .9, -unit * .95, unit * .9, -unit * .62), fill(const Color(0xFFE3E9F1)));
    canvas.restore();
    canvas.drawRRect(body, line(const Color(0xFF8A5A0C), 1));
    // 렌즈(눈) + 가운데 불빛
    canvas.drawCircle(Offset.zero, unit * .42, fill(const Color(0xFF0F2742)));
    canvas.drawCircle(Offset.zero, unit * .3, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.3), colors: [Color(0xFFB8FFFF), Color(0xFF29B6E8)]).createShader(Rect.fromCircle(center: Offset.zero, radius: unit * .3)));
    canvas.drawCircle(Offset(-unit * .09, -unit * .1), unit * .08, fill(Colors.white));

    // 위쪽 안테나 + 깜빡이는 불빛
    canvas.drawLine(Offset(unit * .35, -unit * .95), Offset(unit * .55, -unit * 1.7), line(const Color(0xFFC9D4E2), 1.3));
    final blink = (math.sin(a2 * 4) > 0) ? 1.0 : .25; // 안테나 불빛이 깜빡
    canvas.drawCircle(Offset(unit * .55, -unit * 1.7), unit * .2, Paint()..color = const Color(0xCCFF5C7A).withValues(alpha: .8 * blink)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(unit * .55, -unit * 1.7), unit * .11, fill(Color.lerp(const Color(0xFF7A3A48), const Color(0xFFFF8FA3), blink)!));

    // 아래 접시 안테나 (신호를 지붕으로 쏜다)
    canvas.drawLine(Offset(0, unit * .95), Offset(0, unit * 1.35), line(const Color(0xFFC9D4E2), 1.4));
    final dish = Rect.fromCenter(center: Offset(0, unit * 1.5), width: unit * 1.7, height: unit * 1.0);
    final dishPath = Path()..addArc(dish, 0, math.pi);
    canvas.drawPath(dishPath, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFB4C3D4)]).createShader(dish));
    canvas.drawPath(dishPath, line(const Color(0xFF52687C), 1));
    canvas.drawLine(Offset(0, unit * 1.5), Offset(0, unit * 1.05), line(const Color(0xFF52687C), 1));
    canvas.drawCircle(Offset(0, unit * 1.05), unit * .13, fill(const Color(0xFFFFD34E)));
    canvas.restore();

    // 반짝이는 별 (네 갈래)
    var starN = 0;
    for (final sp in const [(.72, .035, .018), (.95, .15, .014), (.77, .17, .012)]) {
      final tw = .65 + .35 * math.sin(a2 * 2 + starN * 2.1); // 반짝반짝 크기가 변한다
      starN++;
      final c = p(sp.$1, sp.$2), r = w * sp.$3 * tw;
      final star = Path()
        ..moveTo(c.dx, c.dy - r * 1.6)
        ..quadraticBezierTo(c.dx + r * .2, c.dy - r * .2, c.dx + r * 1.6, c.dy)
        ..quadraticBezierTo(c.dx + r * .2, c.dy + r * .2, c.dx, c.dy + r * 1.6)
        ..quadraticBezierTo(c.dx - r * .2, c.dy + r * .2, c.dx - r * 1.6, c.dy)
        ..quadraticBezierTo(c.dx - r * .2, c.dy - r * .2, c.dx, c.dy - r * 1.6)
        ..close();
      canvas.drawPath(star, fill(const Color(0xDDFFF6C2)));
    }
  }

  /// 11단계 이후의 첨단 장치들. 위성 연동 스마트팜(15단계)에는 지붕 위 위성과 신호가 나온다.
  void _drawTech(Canvas canvas, Size size, int stage, Color frame, double a) {
    final a2 = a * math.pi * 2;
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
      var n = 0;
      for (final d in const [(.2, .55), (.34, .66), (.66, .6), (.8, .68), (.5, .74), (.28, .46), (.72, .46)]) {
        final c = p(d.$1 + math.sin(a2 + n) * .012, d.$2 + math.cos(a2 * 1.3 + n * 1.7) * .018);
        canvas.drawCircle(c, w * .016, glow(const Color(0xCC9BFF7A), 3));
        canvas.drawCircle(c, w * .008, fill(const Color(0xFFE9FFD0)));
        n++;
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
      final pulse = 1 + .14 * math.sin(a2 * 2);
      canvas.drawCircle(p(.5, .06), w * .05 * pulse, glow(const Color(0xCCFF5CE1), 5));
      canvas.drawCircle(p(.5, .06), w * .024 * pulse, fill(const Color(0xFFFFE0FA)));
    }

    // 15 위성 연동 스마트팜: 오른쪽 위에 위성이 떠 있고, 지붕으로 신호를 보낸다
    if (stage >= 15) _drawSatellite(canvas, size, a);

    // 16 핵융합 에너지 팜: 안쪽 가운데의 밝은 에너지 코어
    if (stage >= 16) {
      final core = 1 + .12 * math.sin(a2 * 3);
      canvas.drawCircle(p(.5, .66), w * .06 * core, glow(const Color(0xCCFFB84A), 6));
      canvas.drawCircle(p(.5, .66), w * .026, fill(const Color(0xFFFFF6D0)));
      canvas.drawCircle(p(.5, .66), w * .05 * core, line(const Color(0xAAFFD34E), 1.2));
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
  bool shouldRepaint(GreenhousePainter old) => old.tier != tier || old.count != count || old.name != name || old.stage != stage || old.anim != anim;
}

/// 움직이는 하우스: [GreenhousePainter]에 시간을 흘려 보내서 안의 작물이 살랑이고 위성·신호·별이 움직이게 한다.
/// [active]가 false이면(농장 탭이 아닐 때 등) 멈춰서 배터리를 아낀다. 크기는 부모가 정한다.
class GreenhouseView extends StatefulWidget {
  const GreenhouseView({super.key, required this.count, required this.tier, required this.stage, this.name, this.active = true});
  final int count, tier, stage;
  final String? name;
  final bool active;

  @override
  State<GreenhouseView> createState() => _GreenhouseViewState();
}

class _GreenhouseViewState extends State<GreenhouseView> with SingleTickerProviderStateMixin {
  /// 한 바퀴 시간. 위성·작물은 이 안에서 3번 움직이고(6초마다 한 번), 로봇은 천천히 한 번 오간다.
  static const loop = Duration(seconds: 18);
  late final AnimationController _c = AnimationController(vsync: this, duration: loop);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(GreenhouseView old) {
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
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: GreenhousePainter(count: widget.count, tier: widget.tier, name: widget.name, stage: widget.stage, anim: _c)),
      );
}
