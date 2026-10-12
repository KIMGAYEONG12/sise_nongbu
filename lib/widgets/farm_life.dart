import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'crop_art.dart';

/// 농장 그림 위에서 움직이는 것들: 밭에서 살랑살랑 흔들리는 작물과, 밭 사이를 오가며 물을 주는 최첨단 로봇.
/// 부모가 농장 그림과 같은 크기·위치로 놓고, [k]는 그림 원본(936×714) 1px가 화면에서 차지하는 크기다.
/// [active]가 false이면(농장 탭이 아닐 때) 멈춰서 배터리와 메모리를 아낀다.
class FarmLife extends StatefulWidget {
  const FarmLife({super.key, required this.k, required this.active, required this.plots, this.now});
  final double k;
  final bool active;

  /// 내 밭들. 작물이 심어진 밭 최대 세 곳의 작물이 그림 속 흙 위에 서서 흔들린다.
  final List<Plot> plots;

  /// 테스트에서 시간을 고정할 때만 쓴다 (평소에는 null)
  final DateTime? now;

  /// 그림 속 흙 밭 세 곳의 가운데 (원본 픽셀)
  static const patches = [Offset(352, 596), Offset(470, 628), Offset(585, 676)];

  /// 로봇이 다니는 길 (원본 픽셀): 집 앞에서 시작해 길을 따라 밭 쪽으로 내려갔다가 돌아온다.
  static const route = [
    Offset(330, 436),
    Offset(292, 498),
    Offset(338, 556),
    Offset(420, 590),
    Offset(500, 612),
    Offset(560, 654),
    Offset(500, 612),
    Offset(420, 590),
    Offset(338, 556),
    Offset(292, 498),
  ];

  @override
  State<FarmLife> createState() => _FarmLifeState();

  /// 길을 따라 [t](0~1) 만큼 간 곳의 위치와 진행 방향(왼쪽으로 가면 true).
  /// route 의 마지막 점에서 첫 점으로 돌아가는 구간까지 포함해 한 바퀴를 돈다.
  static (Offset, bool) robotAt(double t) {
    final pts = [...route, route.first];
    var total = 0.0;
    final lens = <double>[];
    for (var i = 0; i + 1 < pts.length; i++) {
      final l = (pts[i + 1] - pts[i]).distance;
      lens.add(l);
      total += l;
    }
    var d = (t % 1.0) * total;
    for (var i = 0; i < lens.length; i++) {
      if (d <= lens[i] || i == lens.length - 1) {
        final f = lens[i] == 0 ? 0.0 : (d / lens[i]).clamp(0.0, 1.0);
        final p = Offset.lerp(pts[i], pts[i + 1], f)!;
        return (p, pts[i + 1].dx < pts[i].dx);
      }
      d -= lens[i];
    }
    return (pts.first, false);
  }
}

class _FarmLifeState extends State<FarmLife> with SingleTickerProviderStateMixin {
  /// 로봇이 한 바퀴 도는 시간
  static const lap = Duration(seconds: 28);

  late final AnimationController _c = AnimationController(vsync: this, duration: lap);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(FarmLife old) {
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
  Widget build(BuildContext context) {
    final k = widget.k;
    final planted = widget.plots.where((p) => !p.isEmpty).take(FarmLife.patches.length).toList();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            final now = widget.now ?? DateTime.now();
            final (rp, goingLeft) = FarmLife.robotAt(t);
            // 로봇이 밭 가까이에 있으면 물을 준다
            final watering = FarmLife.patches.any((p) => (p - rp).distance < 34);
            final robotSize = 66 * k;
            final cropSize = 54 * k;
            return Stack(clipBehavior: Clip.none, children: [
              // 밭에서 흔들리는 작물 (자라는 정도에 따라 새싹 → 어린 작물 → 다 자란 작물)
              for (var i = 0; i < planted.length; i++)
                Positioned(
                  left: FarmLife.patches[i].dx * k - cropSize / 2,
                  top: FarmLife.patches[i].dy * k - cropSize * .86,
                  width: cropSize,
                  height: cropSize,
                  // 바람에 흔들리는 작물: 한 바퀴(28초)에 14번, 약 7도까지 기울고 숨 쉬듯 살짝 커졌다 작아진다 (눈에 띄게)
                  child: Transform.scale(
                    scale: 1 + .035 * math.sin(t * math.pi * 2 * 14 * 2 + i),
                    alignment: Alignment.bottomCenter,
                    child: Transform.rotate(
                      angle: math.sin(t * math.pi * 2 * 14 + i * 1.7) * .12,
                      alignment: Alignment.bottomCenter,
                      child: CropArt(code: planted[i].cropCode!, size: cropSize, stage: planted[i].progress(now)),
                    ),
                  ),
                ),
              // 순찰하는 최첨단 로봇
              Positioned(
                left: rp.dx * k - robotSize / 2,
                top: rp.dy * k - robotSize * .95,
                width: robotSize,
                height: robotSize,
                child: Transform.scale(
                  scaleX: goingLeft ? -1 : 1,
                  child: CustomPaint(painter: FarmRobotPainter(t: t, watering: watering)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// 최첨단 농장 로봇: 둥근 머리에 빛나는 눈, 안테나, 가슴의 에너지 등, 바퀴. 밭 옆에서는 물방울을 뿌린다.
class FarmRobotPainter extends CustomPainter {
  const FarmRobotPainter({required this.t, this.watering = false});

  /// 0~1 (한 바퀴). 안테나 불빛·바퀴·물방울 움직임에 쓴다.
  final double t;
  final bool watering;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final bob = math.sin(t * math.pi * 2 * 28) * h * .012; // 달리며 살짝 출렁

    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: p(.5, .96), width: w * .62, height: h * .1), Paint()..color = const Color(0x44000000));

    canvas.save();
    canvas.translate(0, bob);

    // 바퀴 두 개
    final wheel = Paint()..color = const Color(0xFF2E3A46);
    for (final x in const [.3, .7]) {
      canvas.drawCircle(p(x, .88), w * .09, wheel);
      canvas.drawCircle(p(x, .88), w * .045, Paint()..color = const Color(0xFF8FA3B5));
      // 바퀴살이 도는 느낌
      final a = t * math.pi * 2 * 40;
      canvas.drawLine(p(x, .88), p(x, .88) + Offset(math.cos(a), math.sin(a)) * w * .04, Paint()..color = const Color(0xFF2E3A46)..strokeWidth = 1.5);
    }

    // 몸통
    final body = RRect.fromRectAndRadius(Rect.fromLTRB(w * .2, h * .46, w * .8, h * .82), Radius.circular(w * .12));
    canvas.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2F7FB), Color(0xFF9DB4C8)]).createShader(body.outerRect));
    canvas.drawRRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0xFF52687C));
    // 가슴 에너지 등 (숨 쉬듯 깜빡)
    final glow = .55 + .45 * math.sin(t * math.pi * 2 * 6).abs();
    canvas.drawCircle(p(.5, .64), w * .09, Paint()..color = const Color(0xFF39F0C8).withValues(alpha: .35 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(p(.5, .64), w * .055, Paint()..color = const Color(0xFF1FD6AE).withValues(alpha: .6 + .4 * glow));
    // 태양광 패널 띠
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .26, h * .52, w * .74, h * .56), Radius.circular(2)), Paint()..color = const Color(0xFF2B4C8C));

    // 팔 (물뿌리개를 든 쪽)
    final arm = Paint()..color = const Color(0xFF6F879B)..strokeWidth = w * .06..strokeCap = StrokeCap.round;
    canvas.drawLine(p(.78, .58), p(.95, .5 + (watering ? .06 : 0)), arm);
    canvas.drawLine(p(.22, .58), p(.07, .64), arm);

    // 머리
    final head = RRect.fromRectAndRadius(Rect.fromLTRB(w * .26, h * .14, w * .74, h * .46), Radius.circular(w * .16));
    canvas.drawRRect(head, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFB4C7D8)]).createShader(head.outerRect));
    canvas.drawRRect(head, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0xFF52687C));
    // 얼굴 화면(바이저)과 파란 눈
    final visor = RRect.fromRectAndRadius(Rect.fromLTRB(w * .31, h * .2, w * .69, h * .37), Radius.circular(w * .08));
    canvas.drawRRect(visor, Paint()..color = const Color(0xFF16263A));
    final blink = (t * 6 % 1.0) > .93 ? .15 : 1.0; // 가끔 눈 깜빡
    for (final x in const [.41, .59]) {
      canvas.drawOval(Rect.fromCenter(center: p(x, .285), width: w * .09, height: h * .09 * blink), Paint()..color = const Color(0xFF6FE8FF));
    }
    // 안테나 + 깜빡이는 불빛
    canvas.drawLine(p(.5, .14), p(.5, .04), Paint()..color = const Color(0xFF52687C)..strokeWidth = 1.6);
    final on = (t * 10 % 1.0) < .5;
    canvas.drawCircle(p(.5, .035), w * .035, Paint()..color = on ? const Color(0xFFFF5C7A) : const Color(0xFF7A3A48));

    canvas.restore();

    // 물뿌리개에서 떨어지는 물방울
    if (watering) {
      final drop = Paint()..color = const Color(0xFF5AB8FF);
      for (var i = 0; i < 5; i++) {
        final f = (t * 14 + i * .2) % 1.0;
        canvas.drawCircle(p(.97 + .02 * i - .04, .56 + f * .36), w * .022 * (1 - f * .4), drop..color = const Color(0xFF5AB8FF).withValues(alpha: 1 - f));
      }
    }
  }

  @override
  bool shouldRepaint(FarmRobotPainter old) => old.t != t || old.watering != watering;
}
