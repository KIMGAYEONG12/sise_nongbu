import 'package:flutter/material.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import 'common.dart';

/// 하늘·산·언덕으로 이루어진 시안 풍의 농장 배경 (이미지 파일 없이 코드로 그린다)
class ScenePainter extends CustomPainter {
  const ScenePainter({this.sun = true, this.fence = false, this.hillsOnly = false});
  final bool sun, fence;

  /// true면 하늘·산 없이 언덕만 그린다 (로그인 화면 하단용)
  final bool hillsOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (!hillsOnly) {
      final rect = Rect.fromLTWH(0, 0, w, h);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9FDCF5), Color(0xFFEAF8E0)])
              .createShader(rect),
      );
      if (sun) {
        canvas.drawCircle(Offset(w * .82, h * .17), h * .13, Paint()..color = const Color(0x55FFF3B0));
        canvas.drawCircle(Offset(w * .82, h * .17), h * .075, Paint()..color = const Color(0xFFFFE27A));
      }
      _cloud(canvas, Offset(w * .2, h * .16), h * .05);
      _cloud(canvas, Offset(w * .55, h * .1), h * .04);

      final mountain = Path()
        ..moveTo(0, h * .58)
        ..lineTo(w * .18, h * .36)
        ..lineTo(w * .34, h * .52)
        ..lineTo(w * .52, h * .32)
        ..lineTo(w * .74, h * .54)
        ..lineTo(w * .9, h * .4)
        ..lineTo(w, h * .52)
        ..lineTo(w, h * .75)
        ..lineTo(0, h * .75)
        ..close();
      canvas.drawPath(mountain, Paint()..color = const Color(0xFF8CC4B4));

    }

    final far = Path()
      ..moveTo(0, h * .6)
      ..quadraticBezierTo(w * .25, h * .48, w * .5, h * .58)
      ..quadraticBezierTo(w * .78, h * .68, w, h * .56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFFA9DA7A));

    final tree = Paint()..color = const Color(0xFF5FAE45);
    for (final t in [[.08, .6], [.15, .58], [.9, .6], [.84, .62], [.48, .58]]) {
      canvas.drawCircle(Offset(w * t[0], h * t[1]), h * .035, tree);
    }

    final near = Path()
      ..moveTo(0, h * .74)
      ..quadraticBezierTo(w * .3, h * .62, w * .6, h * .72)
      ..quadraticBezierTo(w * .85, h * .8, w, h * .7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF7FC25A));

    if (fence) {
      final y = h * .82;
      final wood = Paint()
        ..color = const Color(0xFF9A6A3A)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, y), Offset(w, y), wood);
      canvas.drawLine(Offset(0, y + 14), Offset(w, y + 14), wood);
      for (var x = 8.0; x < w; x += 30) {
        canvas.drawLine(Offset(x, y - 10), Offset(x, y + 24), wood..strokeWidth = 5);
      }
    }
  }

  void _cloud(Canvas c, Offset o, double r) {
    final p = Paint()..color = Colors.white.withValues(alpha: .92);
    c.drawCircle(o, r, p);
    c.drawCircle(o.translate(r * 1.1, r * .2), r * .85, p);
    c.drawCircle(o.translate(-r * 1.1, r * .25), r * .75, p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - r * 1.7, o.dy + r * .2, r * 3.5, r * .9), Radius.circular(r)), p);
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.sun != sun || old.fence != fence || old.hillsOnly != hillsOnly;
}

/// [ScenePainter] 위에 자식을 올린 배경 영역
class SceneBackground extends StatelessWidget {
  const SceneBackground({super.key, this.child, this.sun = true, this.fence = false});
  final Widget? child;
  final bool sun, fence;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: ScenePainter(sun: sun, fence: fence), child: child ?? const SizedBox.expand());
}

/// "시세 농부" 나무 간판 로고
class LogoSign extends StatelessWidget {
  const LogoSign({super.key, this.scale = 1});
  final double scale;
  @override
  Widget build(BuildContext context) {
    final size = 38 * scale;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 22 * scale, vertical: 12 * scale),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD9A15B), Color(0xFFB87A3C)]),
          borderRadius: BorderRadius.circular(18 * scale),
          border: Border.all(color: const Color(0xFF6E4524), width: 3.5 * scale),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Stack(children: [
          Text('시세 농부',
              style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 6 * scale
                    ..color = const Color(0xFF5A3418))),
          Text('시세 농부', style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: const Color(0xFFFFF2C4))),
        ]),
      ),
      Positioned(top: -22 * scale, left: 18 * scale, child: Text('🌱', style: TextStyle(fontSize: 30 * scale))),
      Positioned(top: -26 * scale, right: 22 * scale, child: Text('🌿', style: TextStyle(fontSize: 34 * scale))),
    ]);
  }
}

/// 밭 한 칸. 비어 있으면 +, 자라는 중이면 단계별 새싹, 다 자라면 작물과 반짝임을 보여준다.
class PlotTile extends StatelessWidget {
  const PlotTile({super.key, required this.plot, required this.now, required this.onTap, this.selected = false, this.size = 80});
  final Plot plot;
  final DateTime now;
  final VoidCallback onTap;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = plot.isEmpty ? null : cropOf(plot.cropCode!);
    final ready = plot.isReady(now);
    final progress = plot.progress(now);
    Widget content;
    if (spec == null) {
      content = Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: .8), size: size * .42);
    } else if (ready) {
      content = Stack(alignment: Alignment.center, children: [
        Text(spec.emoji, style: TextStyle(fontSize: size * .52, height: 1)),
        Positioned(top: 2, right: 4, child: Text('✨', style: TextStyle(fontSize: size * .22))),
      ]);
    } else {
      final emoji = progress < .34 ? '🌱' : (progress < .67 ? '🌿' : spec.emoji);
      content = Text(emoji, style: TextStyle(fontSize: size * (progress < .67 ? .42 : .4), height: 1));
    }
    final border = ready
        ? Border.all(color: const Color(0xFFFFD54F), width: 3)
        : selected
            ? Border.all(color: Colors.white, width: 3)
            : Border.all(color: AppColors.soilDark.withValues(alpha: .5), width: 1.5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB87A45), Color(0xFF94602F)]),
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: ready ? [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: .6), blurRadius: 10)] : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          content,
          if (spec != null && !ready)
            Positioned(left: 8, right: 8, bottom: 6, child: ThinBar(value: progress, height: 4, color: const Color(0xFFB5E36B), track: Colors.black26)),
        ]),
      ),
    );
  }
}

/// 집·나무가 있는 풍경 아래에 흙 밭 칸들이 놓인 농장 카드
class FarmYard extends StatelessWidget {
  const FarmYard({super.key, required this.plots, required this.now, required this.onTapPlot, this.decor = 0, this.selected});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTapPlot;
  final int decor;
  final int? selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const pad = 12.0, gap = 8.0, inner = 8.0, cols = 3;
        final w = box.maxWidth;
        final tile = ((w - pad * 2 - inner * 2 - gap * (cols - 1)) / cols).clamp(48.0, 96.0).toDouble();
        final rows = plots.isEmpty ? 1 : (plots.length / cols).ceil();
        final boardH = rows * tile + (rows - 1) * gap + inner * 2;
        const skyH = 118.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: skyH + boardH + 14,
            child: CustomPaint(
              painter: const ScenePainter(),
              child: Stack(children: [
                const Positioned(left: 14, top: 22, child: Text('🏡', style: TextStyle(fontSize: 70, height: 1))),
                const Positioned(right: 20, top: 34, child: Text('🌳', style: TextStyle(fontSize: 52, height: 1))),
                const Positioned(right: 78, top: 56, child: Text('🌳', style: TextStyle(fontSize: 34, height: 1))),
                Positioned(left: 96, top: 66, child: Text('🌻' * decor, style: const TextStyle(fontSize: 22, height: 1))),
                Positioned(
                  left: pad,
                  right: pad,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(inner),
                    decoration: BoxDecoration(
                      color: AppColors.soil,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.soilDark, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Wrap(spacing: gap, runSpacing: gap, children: [
                      for (final p in plots)
                        PlotTile(plot: p, now: now, size: tile, selected: selected == p.index, onTap: () => onTapPlot(p)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      });
}
