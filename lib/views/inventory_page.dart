import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
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

    // 시안: 같은 작물은 한 줄로 합쳐서 보여준다
    final byCrop = <String, List<Lot>>{};
    for (final l in lots) {
      byCrop.putIfAbsent(l.cropCode, () => []).add(l);
    }
    final rows = <Widget>[];
    if (showCrops) {
      for (final e in byCrop.entries) {
        final c = cropOf(e.key), p = prices[e.key];
        final kg = e.value.fold<double>(0, (a, l) => a + l.kg);
        final est = p == null ? null : e.value.fold<int>(0, (a, l) => a + saleAmount(l.kg, p.pricePerKg, freshnessOf(l.harvestedAt, now)));
        rows.add(_InvRow(
          leading: CropArt(code: c.code, size: 38),
          title: c.name,
          sub: est == null ? '시세 없음' : '예상 ${won(est)}',
          trailing: '${kg.toStringAsFixed(0)}kg',
        ));
      }
    }
    if (showItems) {
      for (final e in items) {
        rows.add(_InvRow(leading: Text(itemEmoji(e.key), style: const TextStyle(fontSize: 28, height: 1)), title: itemName(e.key), trailing: '${e.value}개'));
      }
    }

    return Column(children: [
      PageHeader(title: '창고', trailing: MoneyPill(money: user.money)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SoftCard(
          color: Colors.white,
          child: Column(children: [
            Row(children: [
              const Text('🧺', style: TextStyle(fontSize: 18, height: 1)),
              const SizedBox(width: 6),
              const Text('보관 용량', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${used.toStringAsFixed(0)} / $cap kg', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              // 판매 화면으로 가는 버튼 (창고 확장이 시안처럼 아래 큰 버튼이 되면서 여기로 옮겼다)
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: lots.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.sub,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('판매하기', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ThinBar(value: cap == 0 ? 0 : used / cap, height: 10, color: cap > 0 && used / cap > .9 ? AppColors.up : AppColors.green),
          ]),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: PillTabs(labels: const ['전체', '작물', '아이템'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
          if (rows.isNotEmpty)
            SoftCard(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  rows[i],
                ],
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(_tab == 2 ? '보유한 아이템이 없어요' : '창고가 비어 있어요', style: const TextStyle(color: AppColors.sub))),
            ),
        ]),
      ),
      // 시안: 아래 꽉 찬 초록 버튼 "창고 확장 🪙 금액"
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: GreenButton(
          label: maxed ? '창고 최대' : '창고 확장 ${won(cost)}',
          icon: maxed ? null : const CoinIcon(size: 20),
          onPressed: maxed || user.money < cost ? null : () => _expand(cost, cap + warehouseStepKg),
        ),
      ),
    ]);
  }
}

/// 창고 목록 한 줄: 그림 · 이름(+작은 설명) · 오른쪽 수량
class _InvRow extends StatelessWidget {
  const _InvRow({required this.leading, required this.title, required this.trailing, this.sub});
  final Widget leading;
  final String title, trailing;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 40, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ]),
          ),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
      );
}
