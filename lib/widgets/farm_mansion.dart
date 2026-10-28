import 'package:flutter/material.dart';
import '../core/progress_rules.dart';
import 'common.dart';
import 'farm_castle.dart';

/// 농장 그림(farm_scene_gemini.jpg) 원본 좌표계 크기 (실제 파일은 3배 고해상도)
const farmSrcSize = Size(576, 693);

/// Lv.90 전설의 농장 성을 그릴 자리 (그림 원본 픽셀): 그림 속 오두막(지붕·굴뚝·벽)을 다 덮도록 조금 넉넉하게
const farmCastleRect = Rect.fromLTWH(10, 120, 410, 325);

/// 그림 속 큰 집(지붕·벽·현관 지붕·계단)을 감싸는 선 (그림 원본 픽셀). 황금 저택은 이 안만 금빛으로 칠한다.
const _houseOutline = <Offset>[
  Offset(78, 296), Offset(100, 264), Offset(140, 262), Offset(200, 182), Offset(222, 150), Offset(300, 126), Offset(318, 135),
  Offset(345, 165), Offset(392, 250), Offset(380, 262), Offset(372, 268), Offset(372, 345), Offset(360, 372), Offset(300, 392),
  Offset(260, 392), Offset(150, 375), Offset(120, 360), Offset(90, 345), Offset(82, 318),
];

/// 집을 누르는 자리 (그림 원본 픽셀)
const farmHouseTapRect = Rect.fromLTRB(80, 126, 392, 392);

/// 지붕·벽·나무를 금빛으로 바꾸는 색 행렬: 흰 벽은 옅은 금색, 빨간 지붕은 짙은 금색, 나무 기둥은 구릿빛
const _goldFilter = ColorFilter.matrix(<double>[
  0.50, 0.75, 0.15, 0, 20,
  0.38, 0.58, 0.10, 0, 5,
  0.12, 0.20, 0.05, 0, 10,
  0, 0, 0, 1, 0,
]);

/// 황금 농장 저택: 그림 속 집만 금빛으로 덧칠하고 반짝이를 올린다. 크기는 농장 그림 전체와 같게 놓는다 ([k] = 원본 1px의 화면 크기).
class GoldenHouseLayer extends StatelessWidget {
  const GoldenHouseLayer({super.key, required this.k});
  final double k;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _HouseClipper(k),
              child: ColorFiltered(colorFilter: _goldFilter, child: Image.asset(AppImages.farmHome, fit: BoxFit.fill, filterQuality: FilterQuality.high)),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GoldSparklePainter(k))),
        ]),
      );
}

class _HouseClipper extends CustomClipper<Path> {
  const _HouseClipper(this.k);
  final double k;
  @override
  Path getClip(Size size) => Path()..addPolygon([for (final p in _houseOutline) p * k], true);
  @override
  bool shouldReclip(_HouseClipper old) => old.k != k;
}

/// 금빛 지붕 위 반짝이 (네 갈래 별)
class _GoldSparklePainter extends CustomPainter {
  const _GoldSparklePainter(this.k);
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = const Color(0xCCFFF6C8);
    for (final s in const [(250.0, 165.0, 7.0), (330.0, 200.0, 5.0), (175.0, 245.0, 6.0), (300.0, 300.0, 4.5), (360.0, 245.0, 4.0), (120.0, 285.0, 4.0)]) {
      final c = Offset(s.$1 * k, s.$2 * k), r = s.$3 * k;
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, glow);
    }
  }

  @override
  bool shouldRepaint(_GoldSparklePainter old) => old.k != k;
}

/// 농장 집 그림의 한 부분([crop], 원본 픽셀)만 잘라 보여 준다. [stageIndex] 단계(farmHouseNames 위치)에 맞게
/// 황금 저택은 금빛, 전설의 성은 성을 덮어 그린다. 저택 둘러보기 화면에서 쓴다.
class FarmHouseScene extends StatelessWidget {
  const FarmHouseScene({super.key, required this.stageIndex, this.crop = const Rect.fromLTWH(0, 100, 440, 360)});
  final int stageIndex;
  final Rect crop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / crop.width;
        final w = farmSrcSize.width * k, h = farmSrcSize.height * k;
        final left = -crop.left * k, top = -crop.top * k;
        return ClipRect(
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(left: left, top: top, width: w, height: h, child: Image.asset(AppImages.farmHome, fit: BoxFit.fill, filterQuality: FilterQuality.high)),
            if (isGoldenHouseStage(stageIndex)) Positioned(left: left, top: top, width: w, height: h, child: GoldenHouseLayer(k: k)),
            if (stageIndex >= farmHouseNames.length - 1)
              Positioned(
                left: left + farmCastleRect.left * k,
                top: top + farmCastleRect.top * k,
                width: farmCastleRect.width * k,
                height: farmCastleRect.height * k,
                child: const FarmCastle(),
              ),
          ]),
        );
      });
}
