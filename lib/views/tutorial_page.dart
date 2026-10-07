import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 처음 한 번 보여주는 5장짜리 튜토리얼 (시세 확인 → 파종 → 성장 → 판매 → 시작)
/// 2~5장 그림은 챗GPT 시안 일러스트(assets/images)를 그대로 쓴다.
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
      _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_i > 0) _ctrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              // 시안: 왼쪽 < , 가운데 "튜토리얼 n/5", 오른쪽 건너뛰기
              SizedBox(
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  if (_i > 0)
                    Positioned(
                      left: 4,
                      child: IconButton(onPressed: _back, icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppColors.ink)),
                    ),
                  Text('튜토리얼 ${_i + 1} / $_total', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF3D4A40))),
                  Positioned(
                    right: 8,
                    child: TextButton(onPressed: widget.onDone, child: const Text('건너뛰기', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w600))),
                  ),
                ]),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _total,
                  onPageChanged: (v) => setState(() => _i = v),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                    child: Column(children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_titles[i], style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
                      ),
                      const SizedBox(height: 10),
                      Text(_subs[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: Color(0xFF5B6B5F), height: 1.55, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 18),
                      Expanded(child: _Visual(index: i)),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: GreenButton(label: _i == _total - 1 ? '시작하기' : '다음', height: 52, onPressed: _next),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _i ? AppColors.green : const Color(0xFFD3DCCB)),
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
        return Align(alignment: Alignment.topCenter, child: _PriceCard(prices: ref.watch(marketViewModelProvider).valueOrNull));
      case 1:
        // 집·나무가 있는 농장 + 가운데 밭을 손가락으로 누르는 그림
        return const IllustCard(asset: AppImages.tutPlant, aspect: 810 / 801);
      case 2:
        // 파종 → 성장 → 수확
        return const IllustCard(asset: AppImages.tutGrow, aspect: 813 / 771);
      case 3:
        // 농장 그림 위의 시세 카드는 실제 배추 시세로 다시 그린다
        return IllustCard(
          asset: AppImages.tutSell,
          aspect: 807 / 765,
          overlay: _SellOverlay(price: ref.watch(marketViewModelProvider).valueOrNull?['CABBAGE']),
        );
      default:
        // 시작 화면의 농부 일러스트
        return const IllustCard(asset: AppImages.tutReady, aspect: 993 / 786);
    }
  }
}

/// 1. 오늘의 시세 카드 (실제 시세를 불러왔으면 그 값, 아니면 안내 문구)
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.prices});
  final Map<String, AuctionPrice>? prices;
  @override
  Widget build(BuildContext context) {
    final list = crops.take(5).toList();
    return SoftCard(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Row(children: [
          Icon(Icons.trending_up_rounded, size: 20, color: AppColors.ink),
          SizedBox(width: 8),
          Text('오늘의 시세', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 6),
        for (var k = 0; k < list.length; k++) ...[
          Builder(builder: (_) {
            final c = list[k];
            final p = prices?[c.code];
            final pct = p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Text(c.emoji, style: const TextStyle(fontSize: 24, height: 1)),
                const SizedBox(width: 12),
                SizedBox(width: 54, child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                Expanded(
                  child: Text(p == null ? '시세를 불러오는 중…' : '${commaNum(p.pricePerKg)}원/kg',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p == null ? AppColors.sub : AppColors.ink)),
                ),
                ChangeChip(percent: pct),
              ]),
            );
          }),
          if (k < list.length - 1) const Divider(height: 1, color: Color(0xFFEDF1E8)),
        ],
      ]),
    );
  }
}

/// 4. 그림 위 시세 카드 자리(시안과 같은 위치)에 실제 배추 시세 + 판매하기 버튼
class _SellOverlay extends StatelessWidget {
  const _SellOverlay({required this.price});
  final AuctionPrice? price;
  @override
  Widget build(BuildContext context) {
    final p = price;
    final pct = p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
    final up = (pct ?? 0) >= 0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return Stack(children: [
        Positioned(
          left: w * .055,
          right: w * .045,
          top: h * .395,
          bottom: h * .095,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 260,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('🥬', style: TextStyle(fontSize: 46, height: 1)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('배추', style: TextStyle(fontSize: 14, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(p == null ? '시세 확인 중' : '${commaNum(p.pricePerKg)}원/kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Icon(Icons.chevron_right_rounded, color: AppColors.sub, size: 22),
                      const SizedBox(height: 4),
                      if (pct != null) Text(up ? '▲' : '▼', style: TextStyle(fontSize: 16, color: up ? AppColors.up : AppColors.down)),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(22)),
                    child: const Text('판매하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
