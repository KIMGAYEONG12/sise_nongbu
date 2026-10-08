import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import '../core/korean.dart';

/// 수확 완료 화면 (시안): 햇살이 퍼지는 작물 그림, 수확량과 현재 시세 기준 예상 판매 금액.
class HarvestResultPage extends ConsumerWidget {
  const HarvestResultPage({super.key, required this.cropCode, required this.kg});
  final String cropCode;
  final double kg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cropOf(cropCode);
    final price = ref.watch(marketViewModelProvider).valueOrNull?[cropCode];
    final lv = ref.watch(userDataProvider).level;
    // 작은 화면에서도 넘치지 않게 그림 크기를 화면 높이에 맞춘다
    final art = (MediaQuery.sizeOf(context).height * .26).clamp(130.0, 260.0).toDouble();
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(children: [
              PageHeader(title: '', onBack: () => Navigator.of(context).pop()),
              const Text('수확 완료!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const Spacer(),
              SizedBox(
                width: art,
                height: art,
                child: Stack(alignment: Alignment.center, children: [
                  const Positioned.fill(child: CustomPaint(painter: SunburstPainter())),
                  CropArt(code: c.code, size: art * .65),
                ]),
              ),
              const SizedBox(height: 8),
              Text('${withJosa(c.name, '을', '를')} 수확했습니다!', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              // 경험치: 이번에 얻은 경험치와 현재 레벨 진행 막대
              SoftCard(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  Row(children: [
                    const Text('⭐', style: TextStyle(fontSize: 20, height: 1)),
                    const SizedBox(width: 8),
                    const Text('경험치', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
                      child: const Text('+$harvestExp EXP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.greenDark)),
                    ),
                    const Spacer(),
                    Text('Lv. ${lv.level}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ThinBar(value: lv.ratio, height: 12, color: const Color(0xFF34A34A), track: const Color(0xFFE4EAE6))),
                    const SizedBox(width: 10),
                    Text('${lv.exp} / ${lv.need}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                  ]),
                ]),
              ),
              SoftCard(
                color: Colors.white,
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.scale_rounded, size: 18, color: AppColors.sub),
                    const SizedBox(width: 8),
                    const Text('수확량'),
                    const Spacer(),
                    Text('${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1)}kg', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                  const Divider(height: 22, color: AppColors.line),
                  Row(children: [
                    const Icon(Icons.payments_outlined, size: 18, color: AppColors.sub),
                    const SizedBox(width: 8),
                    const Text('판매 예상 금액'),
                    const Spacer(),
                    Text(price == null ? '시세 확인 중' : won(saleAmount(kg, price.pricePerKg, 1.0)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              GreenButton(label: '확인', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 작물 뒤에서 퍼져 나가는 노란 햇살 (시안의 수확 완료 그림)
class SunburstPainter extends CustomPainter {
  const SunburstPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final glow = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFF3B0).withValues(alpha: .95), const Color(0xFFFFF3B0).withValues(alpha: 0)]).createShader(glow));
    const rayColor = Color(0xBFFFE680);
    final ray = Paint()..color = rayColor;
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      const w = math.pi / n * .45;
      final path = Path()
        ..moveTo(c.dx + math.cos(a - w) * r * .62, c.dy + math.sin(a - w) * r * .62)
        ..lineTo(c.dx + math.cos(a) * r * .98, c.dy + math.sin(a) * r * .98)
        ..lineTo(c.dx + math.cos(a + w) * r * .62, c.dy + math.sin(a + w) * r * .62)
        ..close();
      canvas.drawPath(path, ray);
    }
  }

  @override
  bool shouldRepaint(SunburstPainter old) => false;
}
