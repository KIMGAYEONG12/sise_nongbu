import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'point_shop_page.dart';
import '../core/korean.dart';

/// 상점 탭: 포인트 상점(씨앗·소모품·시설)과 특별 상점
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});
  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  int _tab = 0;

  Widget _buyBtn(String label, VoidCallback? onTap) => SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.line,
            disabledForegroundColor: AppColors.sub,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      );

  Widget _row(String emoji, String title, String sub, Widget action) => SoftCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          EmojiBadge(emoji, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KoText(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              KoText(sub, style: const TextStyle(fontSize: 12, color: AppColors.sub, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 8),
          action,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final plots = ref.watch(plotsProvider).valueOrNull ?? const <Plot>[];
    final vm = ref.read(farmViewModelProvider);
    final expandCost = plotExpandCost(plots.length);
    final ghCost = greenhouseCostFor(user.greenhouses);

    return Column(children: [
      PageHeader(title: '상점', trailing: MoneyPill(money: user.money)),
      Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PillTabs(labels: const ['포인트 상점', '특별 상점'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
      Expanded(
        child: _tab == 1
            ? const PointShopBody()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                const SectionTitle('씨앗'),
                for (final c in crops)
                  _row(c.emoji, '${c.name} 씨앗', '보유 ${user.item(seedKey(c.code))}개 · 파종비(${won(c.seedCost)})보다 15% 저렴',
                      _buyBtn(won(seedPrice(c)), user.money < seedPrice(c) ? null : () => runGuarded(context, () => vm.buySeed(c), ok: '${c.name} 씨앗을 샀어요'))),
                const SectionTitle('성장 아이템'),
                for (final i in consumables)
                  _row(i.emoji, i.name, '${i.desc}\n보유 ${user.item(i.key)}개',
                      _buyBtn(won(i.price), user.money < i.price ? null : () => runGuarded(context, () => vm.buyConsumable(i), ok: '${withJosa(i.name, '을', '를')} 샀어요'))),
                // 묶음 상품: 같은 아이템을 여러 개 사면 10% 싸다
                const SectionTitle('묶음 상품 (10% 할인)'),
                for (final bd in bundles)
                  _row(bd.emoji, bd.name, '${itemName(bd.itemKey)} ${bd.qty}개를 한 번에 · 보유 ${user.item(bd.itemKey)}개',
                      _buyBtn(won(bd.price), user.money < bd.price ? null : () => runGuarded(context, () => vm.buyBundle(bd), ok: '${bd.name}을 샀어요'))),
                _row('🎁', '씨앗 꾸러미', '여섯 작물 씨앗을 1개씩 (따로 사는 값의 90%)',
                    _buyBtn(won(seedPackPrice()), user.money < seedPackPrice() ? null : () => runGuarded(context, vm.buySeedPack, ok: '씨앗 꾸러미를 샀어요 🎁'))),
                const SectionTitle('농장 시설'),
                _row('🟫', '밭 넓히기', plots.length >= maxPlots ? '최대 $maxPlots칸까지 넓혔어요' : '${plots.length}칸 → ${plots.length + plotExpandStep}칸 (최대 $maxPlots칸)',
                    _buyBtn(expandCost == null ? '최대' : won(expandCost), expandCost == null || user.money < expandCost ? null : () => runGuarded(context, vm.expandPlots, ok: '밭을 넓혔어요 🌾'))),
                // 하우스: 여러 채 지을 수 있고 한 채마다 성장 시간이 10%씩 줄어든다
                _row('🏠', '하우스 (${user.greenhouses}/$maxGreenhouses채)',
                    user.greenhouses >= maxGreenhouses ? '모두 지었어요 · 성장 시간 ${(100 - greenhouseFactor(user.greenhouses) * 100).round()}% 단축' : '지을 때마다 성장 시간 10%씩 단축 (지금 ${(100 - greenhouseFactor(user.greenhouses) * 100).round()}%, 최대 50%) · 이후 파종부터 적용',
                    _buyBtn(ghCost == null ? '최대' : won(ghCost), ghCost == null || user.money < ghCost ? null : () => runGuarded(context, vm.buyGreenhouse, ok: '하우스를 지었어요 🏠'))),
                _row('📦', '창고 넓히기', user.warehouseLevel >= maxWarehouseLevel ? '최대로 넓혔어요 (${user.warehouseCapKg}kg)' : '${user.warehouseCapKg}kg → ${user.warehouseCapKg + warehouseStepKg}kg',
                    _buyBtn(user.warehouseLevel >= maxWarehouseLevel ? '최대' : won(warehouseCost(user.warehouseLevel)), user.warehouseLevel >= maxWarehouseLevel || user.money < warehouseCost(user.warehouseLevel) ? null : () => runGuarded(context, vm.expandWarehouse, ok: '창고를 넓혔어요 📦'))),
              ]),
      ),
    ]);
  }
}
