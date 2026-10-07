import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/farm_scene.dart';

/// 처음 한 번 보여주는 5장짜리 튜토리얼 (시세 확인 → 파종 → 성장 → 판매 → 시작)
class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final _ctrl = PageController();
  int _i = 0;
  static const _total = 5;

  static const _titles = ['시세를 확인해보세요!', '밭에 작물을 심어보세요!', '작물이 자라요!', '시세를 보고 판매해보세요!', '농부가 될 준비 완료!'];
  static const _subs = [
    '농산물 가격은 실시간으로 변동됩니다.\n가격이 높을 때 판매하면 더 많은 수익을 얻을 수 있어요.',
    '빈 밭을 눌러 원하는 작물을 심고\n정성껏 키워주세요.',
    '시간이 지나면 작물이 성장하고,\n수확할 수 있게 됩니다.',
    '시세를 확인하고, 가격이 높을 때\n판매하면 더 많은 수익을 얻을 수 있어요.',
    '미션과 업적을 달성하면 포인트를 받아요.\n이제 나만의 농장을 키워볼까요?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_i >= _total - 1) {
      widget.onDone();
    } else {
      _ctrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_i > 0) _ctrl.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              PageHeader(title: '튜토리얼 ${_i + 1}/$_total', onBack: _i > 0 ? _back : null, trailing: TextButton(onPressed: widget.onDone, child: const Text('건너뛰기', style: TextStyle(color: AppColors.sub)))),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _total,
                  onPageChanged: (v) => setState(() => _i = v),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                    child: Column(children: [
                      Text(_titles[i], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(_subs[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.5)),
                      const SizedBox(height: 16),
                      Expanded(child: _Visual(index: i)),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                child: GreenButton(label: _i == _total - 1 ? '시작하기' : '다음', onPressed: _next),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _total; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == _i ? AppColors.green : AppColors.line),
                  ),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      );
}

class _Visual extends ConsumerWidget {
  const _Visual({required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        return _PriceCard(prices: ref.watch(marketViewModelProvider).valueOrNull);
      case 1:
        return _SceneCard(child: Center(child: _PlantDemo()));
      case 2:
        return _SceneCard(child: Center(child: _GrowDemo()));
      case 3:
        return _SceneCard(child: Center(child: _SellDemo(price: ref.watch(marketViewModelProvider).valueOrNull?['CABBAGE'])));
      default:
        return _SceneCard(child: const Align(alignment: Alignment(-.6, .75), child: Text('👩‍🌾', style: TextStyle(fontSize: 110, height: 1))));
    }
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(22)),
          child: ClipRRect(borderRadius: BorderRadius.circular(20), child: SceneBackground(fence: true, child: child)),
        ),
      );
}

/// 1. 오늘의 시세 카드 (실제 시세를 불러왔으면 그 값, 아니면 안내 문구)
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.prices});
  final Map<String, AuctionPrice>? prices;
  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.show_chart_rounded, size: 20), SizedBox(width: 6), Text('오늘의 시세', style: TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          for (final c in crops.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Builder(builder: (_) {
                final p = prices?[c.code];
                final pct = p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
                return Row(children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  SizedBox(width: 50, child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(child: Text(p == null ? '시세를 불러오는 중…' : '${commaNum(p.pricePerKg)}원/kg', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ChangeChip(percent: pct),
                ]);
              }),
            ),
        ]),
      );
}

/// 2. 3×2 밭 중 가운데 칸을 눌러 심는 모습
class _PlantDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 216,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.soil, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.soilDark, width: 3)),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < 6; i++)
            i == 4
                ? Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .85), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
                    ),
                    const Positioned(right: -8, bottom: -14, child: Text('👆', style: TextStyle(fontSize: 34))),
                  ])
                : PlotTile(plot: Plot(i, null, null), now: DateTime.now(), size: 60, onTap: () {}),
        ]),
      );
}

/// 3. 파종 → 성장 → 수확
class _GrowDemo extends StatelessWidget {
  Widget _step(String emoji, String label) => Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 34, height: 1.2)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _step('🌱', '파종'),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, color: AppColors.green)),
        _step('🌿', '성장'),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, color: AppColors.green)),
        _step('🥬', '수확'),
      ]);
}

/// 4. 시세 카드 + 판매하기 버튼
class _SellDemo extends StatelessWidget {
  const _SellDemo({required this.price});
  final AuctionPrice? price;
  @override
  Widget build(BuildContext context) {
    final p = price;
    final pct = p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('🥬', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('배추', style: TextStyle(fontSize: 12, color: AppColors.sub)),
              Text(p == null ? '시세 확인 중' : '${commaNum(p.pricePerKg)}원/kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
          ChangeChip(percent: pct),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(19)),
          child: const Text('판매하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
