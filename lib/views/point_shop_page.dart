import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../core/korean.dart';
import 'about_page.dart';
import 'shop_page.dart';

/// 특별 상점 목록 (상점 탭과 독립 화면에서 같이 쓴다)
class PointShopBody extends ConsumerWidget {
  const PointShopBody({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, PointItem item) async {
    String? code;
    var msg = '${withJosa(item.name, '을', '를')} 받았어요';
    switch (item.key) {
      case pointRareSeed:
        final c = crops[Random().nextInt(crops.length)];
        code = c.code;
        msg = '${c.label} 씨앗 3개를 받았어요!';
      case pointWaterPack:
        msg = '💧 물통 10개를 받았어요!';
      case pointBoosterPack:
        msg = '⚡ 성장촉진제 2개를 받았어요!';
      case pointSeedBox:
        msg = '🎁 기본 작물 씨앗 $seedPackCropCount종을 받았어요!';
      case pointCoinBag:
        msg = '💰 ${won(coinBagMoney)}을 받았어요!';
      case pointFarmBook:
        msg = '📘 경험치 $farmBookExp을 얻었어요!';
    }
    await runGuarded(context, () => ref.read(farmViewModelProvider).buyPointItem(item, cropCode: code), ok: msg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    // 다음 목표: 아직 못 사는 아이템 중 가장 싼 것 (다 살 수 있으면 가장 비싼 것)
    final costs = pointItems.map((e) => e.cost).toList()..sort();
    final goal = costs.firstWhere((c) => c > user.points, orElse: () => costs.last);
    final ratio = goal <= 0 ? 1.0 : (user.points / goal).clamp(0.0, 1.0).toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      // 시안: 캐시 보물 상자 · 캐시 · 보유 캐시 · 초록 막대
      SoftCard(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(children: [
          const CashCoin(size: 52, kind: CashKind.chest),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('캐시', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                const Spacer(),
                CashPill(amount: user.points),
              ]),
              const SizedBox(height: 8),
              ThinBar(value: ratio, height: 12, color: const Color(0xFF34A34A), track: const Color(0xFFE4EAE6)),
              const SizedBox(height: 5),
              Text(user.points >= goal ? '모든 아이템을 살 수 있어요!' : '다음 아이템까지 ${cash(goal - user.points)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF55655A), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      // 포인트 상점과 같은 카드(그림 · 이름 · 설명 · 오른쪽 초록 버튼). 캐시가 모자라면 설명 아래에 얼마 더 필요한지 알려 준다.
      for (final item in pointItems)
        Builder(builder: (_) {
          String? blocked;
          if (item.key == pointDecor && user.decor >= maxDecor) blocked = '최대';
          if (item.key == pointVault && user.warehouseBonusKg >= maxVaultBonusKg) blocked = '최대';
          final short = user.points < item.cost;
          final enabled = blocked == null && !short;
          return ShopRow(
            emoji: item.emoji,
            title: item.name,
            sub: '${item.desc}${blocked == null && short ? '\n🔒 ${cash(item.cost - user.points)} 더 모으면 열려요' : ''}',
            action: ShopBuyButton(blocked ?? cash(item.cost), enabled ? () => _buy(context, ref, item) : null),
          );
        }),
      const SizedBox(height: 4),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        CashCoin(size: 14),
        SizedBox(width: 4),
        Flexible(child: Text('캐시는 미션, 업적, 레벨업, 판매로 모을 수 있어요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Color(0xFF55655A), fontWeight: FontWeight.w600))),
      ]),
    ]);
  }
}

class PointShopPage extends ConsumerWidget {
  const PointShopPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
              title: '특별 상점',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                CashPill(amount: user.points),
                IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())), icon: const Icon(Icons.settings_outlined, color: AppColors.ink)),
              ]),
            ),
            const Expanded(child: PointShopBody()),
          ]),
        ),
      ),
    );
  }
}
