import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'sell_page.dart';

/// 창고 탭: 보관 용량, 수확물(작물)과 아이템, 판매·창고 확장
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  int _tab = 0;

  Future<void> _expand(int cost, int nextCap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('창고를 넓힐까요?'),
        content: Text('${won(cost)}을 내면 용량이 ${nextCap}kg이 돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runGuarded(context, ref.read(farmViewModelProvider).expandWarehouse, ok: '창고를 넓혔어요 📦');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final lots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? const <String, AuctionPrice>{};
    final now = DateTime.now();
    final used = lots.fold<double>(0, (a, l) => a + l.kg);
    final cap = user.warehouseCapKg;
    final maxed = user.warehouseLevel >= maxWarehouseLevel;
    final cost = warehouseCost(user.warehouseLevel);

    final items = <MapEntry<String, int>>[
      for (final e in user.items.entries)
        if (((e.value as num?)?.toInt() ?? 0) > 0) MapEntry(e.key, (e.value as num).toInt()),
    ];

    final showCrops = _tab != 2, showItems = _tab != 1;

    return Column(children: [
      PageHeader(title: '창고', trailing: MoneyPill(money: user.money)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SoftCard(
          child: Column(children: [
            Row(children: [
              const Text('보관 용량', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${used.toStringAsFixed(0)} / $cap kg', style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            ThinBar(value: cap == 0 ? 0 : used / cap, height: 10, color: used / cap > .9 ? AppColors.up : AppColors.green),
          ]),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: PillTabs(labels: const ['전체', '작물', '아이템'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          if (showCrops) ...[
            if (lots.isEmpty && _tab == 1) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('창고가 비어 있어요', style: TextStyle(color: AppColors.sub)))),
            for (final l in lots)
              Builder(builder: (_) {
                final c = cropOf(l.cropCode), p = prices[l.cropCode];
                final f = freshnessOf(l.harvestedAt, now);
                return SoftCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    EmojiBadge(c.emoji, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.name} ${l.kg.toStringAsFixed(0)}kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('신선도 ${(f * 100).round()}% · ${p == null ? '시세 없음' : '예상 ${won(saleAmount(l.kg, p.pricePerKg, f))}'}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                      ]),
                    ),
                  ]),
                );
              }),
          ],
          if (showItems)
            for (final e in items)
              SoftCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  EmojiBadge(itemEmoji(e.key), size: 48),
                  const SizedBox(width: 12),
                  Expanded(child: Text(itemName(e.key), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text('${e.value}개', style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              ),
          if (_tab == 0 && lots.isEmpty && items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('창고가 비어 있어요', style: TextStyle(color: AppColors.sub)))),
          if (_tab == 2 && items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('보유한 아이템이 없어요', style: TextStyle(color: AppColors.sub)))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(children: [
          Expanded(
            child: GreenButton(
              label: maxed ? '창고 최대' : '창고 확장 ${won(cost)}',
              outlined: true,
              onPressed: maxed || user.money < cost ? null : () => _expand(cost, cap + warehouseStepKg),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GreenButton(
              label: '판매하기',
              onPressed: lots.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellPage())),
            ),
          ),
        ]),
      ),
    ]);
  }
}
