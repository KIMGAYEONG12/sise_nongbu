import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'veggie_art.dart';

/// 작물 그림 (시안의 둥글고 풍성한 배추처럼 코드로 그린 벡터 그림 → 어떤 크기에서도 선명).
/// [stage] 0.0~1.0 성장 진행률: 0.34 미만 작게(막 심음), 0.67 미만 중간(어린 작물), 그 이상 다 자란 작물.
/// 배추·무·양파·사과·토마토·감자 모두 이모지가 아니라 직접 그린 그림이라 작물이 바뀌면 그림도 바뀐다.
class CropArt extends StatelessWidget {
  const CropArt({super.key, required this.code, required this.size, this.stage = 1.0});
  final String code;
  final double size;
  final double stage;

  @override
  Widget build(BuildContext context) {
    // 막 심은 작물도 초록 새싹 대신 그 작물 그림을 작게 보여 준다 (심은 작물이 무엇인지 바로 알 수 있게).
    // 자라는 정도에 따라 작게(45%) → 중간(62%) → 크게(100%).
    final scale = stage < .34
        ? .45
        : stage < .67
            ? .62
            : 1.0;
    final Widget art = code == 'CABBAGE'
        ? CustomPaint(size: Size.square(size), painter: CabbagePainter(scale: scale == .62 ? .72 : scale))
        : CustomPaint(size: Size.square(size), painter: VeggiePainter(code, scale: scale));
    return SizedBox.square(dimension: size, child: art);
  }
}

/// 작물 그림을 연두색 동그라미 안에 담은 배지 (이모지 배지 대신 쓴다)
class CropBadge extends StatelessWidget {
  const CropBadge(this.code, {super.key, this.size = 44, this.color});
  final String code;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color ?? const Color(0xFFD8EDC8).withValues(alpha: .7), shape: BoxShape.circle),
        child: CropArt(code: code, size: size * .82),
      );
}

/// 위에서 내려다본 둥근 배추 한 포기 (겉잎 → 속잎 → 연두색 속)
class CabbagePainter extends CustomPainter {
  const CabbagePainter({this.scale = 1});

  /// 칸 안에서 차지하는 크기 비율 (어린 배추는 작게)
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .52);
    final r = size.shortestSide * .46 * scale;

    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * .78), width: r * 1.7, height: r * .42), Paint()..color = const Color(0x30000000));

    void leaf(double angle, double dist, double w, double h, List<Color> colors, Color edge) {
      canvas.save();
      canvas.translate(c.dx + math.cos(angle) * dist, c.dy + math.sin(angle) * dist * .9);
      canvas.rotate(angle + math.pi / 2);
      final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      final path = Path()
        ..moveTo(0, h / 2)
        ..cubicTo(-w * .62, h * .3, -w * .58, -h * .48, 0, -h / 2)
        ..cubicTo(w * .58, -h * .48, w * .62, h * .3, 0, h / 2)
        ..close();
      canvas.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, r * .035)
            ..color = edge);
      // 잎맥
      final vein = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, r * .025)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x88E9F8C8);
      canvas.drawLine(Offset(0, h * .42), Offset(0, -h * .38), vein);
      for (final t in [-.15, .1, .32]) {
        canvas.drawLine(Offset(0, h * t), Offset(-w * .3, h * (t - .14)), vein);
        canvas.drawLine(Offset(0, h * t), Offset(w * .3, h * (t - .14)), vein);
      }
      canvas.restore();
    }

    // 겉잎 (진한 초록, 8장)
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4 + .2;
      leaf(a, r * .52, r * .95, r * .86, const [Color(0xFF4FA83A), Color(0xFF2F7A26)], const Color(0xFF256420));
    }
    // 속잎 (밝은 초록, 6장)
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      leaf(a, r * .3, r * .78, r * .7, const [Color(0xFF8CCB55), Color(0xFF58A83C)], const Color(0xFF3E8A2C));
    }
    // 가운데 속 (연두색 공)
    final head = Rect.fromCircle(center: c.translate(0, -r * .04), radius: r * .4);
    canvas.drawOval(
      head,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-.3, -.4), radius: .95, colors: [Color(0xFFF2FBD2), Color(0xFFC6E88A), Color(0xFF8FC95A)], stops: [0, .55, 1]).createShader(head),
    );
    canvas.drawOval(
        head,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * .035)
          ..color = const Color(0xFF6DAA3F));
    // 속잎 겹친 선
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * .03)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xAA7BB548);
    canvas.drawArc(Rect.fromCircle(center: c.translate(-r * .08, r * .02), radius: r * .26), math.pi * .9, math.pi * .9, false, fold);
    canvas.drawArc(Rect.fromCircle(center: c.translate(r * .1, -r * .06), radius: r * .2), -math.pi * .2, math.pi * .9, false, fold);
    // 하이라이트
    canvas.drawCircle(c.translate(-r * .14, -r * .2), r * .07, Paint()..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(CabbagePainter old) => old.scale != scale;
}
