import 'package:flutter/material.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import 'common.dart';
import 'crop_art.dart';

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
        CropArt(code: spec.code, size: size * .64),
        Positioned(top: 2, right: 4, child: Text('✨', style: TextStyle(fontSize: size * .22))),
      ]);
    } else {
      content = progress < .67
          ? Text(progress < .34 ? '🌱' : '🌿', style: TextStyle(fontSize: size * .42, height: 1))
          : CropArt(code: spec.code, size: size * .56);
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

/// 밭 칸들을 [cols]열 격자로 놓는다. 칸 크기는 가로폭에 맞춰 정확히 계산해서 줄바꿈으로 칸이 밀리지 않게 한다.
class PlotGrid extends StatelessWidget {
  const PlotGrid({super.key, required this.plots, required this.now, required this.onTap, this.selected, this.cols = 3, this.gap = 8, this.maxTile = 110});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTap;
  final int? selected;
  final int cols;
  final double gap, maxTile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final tile = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble().clamp(40.0, maxTile).toDouble();
        final rows = <Widget>[];
        for (var r = 0; r * cols < plots.length; r++) {
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            final i = r * cols + c;
            if (c > 0) cells.add(SizedBox(width: gap));
            cells.add(i < plots.length
                ? PlotTile(plot: plots[i], now: now, size: tile, selected: selected == plots[i].index, onTap: () => onTap(plots[i]))
                : SizedBox(width: tile, height: tile));
          }
          if (r > 0) rows.add(SizedBox(height: gap));
          rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
        }
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: rows));
      });
}

/// 나무 테두리 안에 흙 밭 칸들이 놓인 밭 판 (시안의 갈색 밭)
class SoilBoard extends StatelessWidget {
  const SoilBoard({super.key, required this.plots, required this.now, required this.onTap, this.selected, this.maxTile = 110, this.grass = false});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTap;
  final int? selected;
  final double maxTile;

  /// true면 시안의 작물 성장 화면처럼 잔디 테두리를 한 겹 더 두른다.
  final bool grass;

  @override
  Widget build(BuildContext context) {
    final board = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB07A48), Color(0xFF8E5B32)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.soilDark, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: PlotGrid(plots: plots, now: now, onTap: onTap, selected: selected, maxTile: maxTile),
    );
    if (!grass) return board;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9BD267), Color(0xFF6DB146)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .18), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: board,
    );
  }
}

/// 챗GPT 시안의 농장 일러스트(집·연못·밭) 위에 실제로 누를 수 있는 밭 칸들을 올린 농장 카드
class FarmYard extends StatelessWidget {
  const FarmYard({super.key, required this.plots, required this.now, required this.onTapPlot, this.decor = 0, this.selected});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTapPlot;
  final int decor;
  final int? selected;

  static const _imgAspect = 936 / 714;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final imgH = w / _imgAspect;
        // 밭 판: 가로 76%, 3열
        final boardW = w * .76;
        const gap = 8.0, pad = 9.0 + 3.0;
        final tile = ((boardW - pad * 2 - gap * 2) / 3).floorToDouble().clamp(40.0, 84.0).toDouble();
        final rows = plots.isEmpty ? 1 : (plots.length / 3).ceil();
        final boardH = rows * tile + (rows - 1) * gap + pad * 2;
        // 그림의 위쪽 45%(하늘·집)는 보이게 두고 아래쪽 들판 위에 밭 판을 얹는다
        final totalH = imgH > imgH * .45 + boardH + 14 ? imgH : imgH * .45 + boardH + 14;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: totalH,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(22)),
            child: Stack(children: [
              Positioned.fill(child: Image.asset(AppImages.farmScene, fit: BoxFit.cover, alignment: Alignment.topCenter, filterQuality: FilterQuality.medium)),
              if (decor > 0)
                Positioned(left: 12, top: 10, child: Text('🌻' * decor, style: const TextStyle(fontSize: 20, height: 1))),
              Positioned(
                left: (w - boardW) / 2,
                width: boardW,
                bottom: 10,
                child: SoilBoard(plots: plots, now: now, onTap: onTapPlot, selected: selected, maxTile: tile),
              ),
            ]),
          ),
        );
      });
}
