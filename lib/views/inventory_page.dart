import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'sell_page.dart';
import '../core/korean.dart';

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

  /// 아이템 판매 창: 1개만 팔거나 모두 판다.
  Future<void> _sellItem(String key, int have, int unit) async {
    final name = itemName(key);
    final qty = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${withJosa(name, '을', '를')} 팔까요?'),
        content: Text('1개에 ${won(unit)}이에요 (상점 가격의 절반).\n지금 $have개 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, 1), child: Text('1개 팔기 (${won(unit)})')),
          if (have > 1) TextButton(onPressed: () => Navigator.pop(d, have), child: Text('모두 팔기 (${won(unit * have)})')),
        ],
      ),
    );
    if (qty == null || !mounted) return;
    await runGuarded(context, () => ref.read(farmViewModelProvider).sellItem(key, qty), ok: '$name $qty개가 판매되었습니다! +${won(unit * qty)}');
  }

  /// 씨앗 여러 종류를 골라(전체 선택 가능) 가진 개수만큼 한 번에 판다.
  Future<void> _sellSeeds(List<MapEntry<String, int>> seeds) async {
    final picked = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _SeedSellSheet(seeds: seeds),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final total = picked.entries.fold<int>(0, (a, e) => a + itemSellPrice(e.key) * e.value);
    final count = picked.values.fold<int>(0, (a, v) => a + v);
    await runGuarded(context, () => ref.read(farmViewModelProvider).sellItems(picked), ok: '씨앗 ${picked.length}종 $count개가 판매되었습니다! +${won(total)}');
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
    final seeds = [for (final e in items) if (e.key.startsWith('seed_') && itemSellPrice(e.key) > 0) e];

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
          // 작물을 누르면 그 작물이 골라진 판매 화면으로 간다
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellPage(initialCrop: e.key))),
        ));
      }
    }
    if (showItems) {
      for (final e in items) {
        final unit = itemSellPrice(e.key);
        rows.add(_InvRow(
          leading: Text(itemEmoji(e.key), style: const TextStyle(fontSize: 28, height: 1)),
          title: itemName(e.key),
          sub: unit > 0 ? '눌러서 판매 · 1개 ${won(unit)}' : null,
          trailing: '${e.value}개',
          // 아이템을 누르면 1개 또는 모두 팔 수 있다 (상점 가격의 절반)
          onTap: unit > 0 ? () => _sellItem(e.key, e.value, unit) : null,
        ));
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
                  // 창고가 비어 있어도 눌러지고, 이유를 알려 준다 (예전엔 비활성이라 "안 눌린다"처럼 보였다)
                  onPressed: () {
                    if (lots.isEmpty) {
                      showMsg(context, '판매할 작물이 없어요. 밭에서 작물을 수확하면 여기에 쌓여요');
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lots.isEmpty ? AppColors.greenLight : AppColors.green,
                    foregroundColor: lots.isEmpty ? AppColors.greenDark : Colors.white,
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
          // 씨앗이 여러 종류 쌓였을 때 한 종류씩 누르지 않고 전체 선택으로 한 번에 판다
          if (showItems && seeds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GreenButton(label: '🌱 씨앗 한꺼번에 팔기 (${seeds.length}종)', outlined: true, height: 44, onPressed: () => _sellSeeds(seeds)),
            ),
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

/// 씨앗 판매 창: 씨앗마다 체크해서 고르거나 "전체 선택"으로 모두 고른다. 고른 씨앗은 가진 개수를 모두 판다.
/// 팔기를 누르면 고른 씨앗(키 → 개수)을 돌려준다.
class _SeedSellSheet extends StatefulWidget {
  const _SeedSellSheet({required this.seeds});
  final List<MapEntry<String, int>> seeds;
  @override
  State<_SeedSellSheet> createState() => _SeedSellSheetState();
}

class _SeedSellSheetState extends State<_SeedSellSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final seeds = widget.seeds;
    final allOn = _picked.length == seeds.length;
    final chosen = {for (final e in seeds) if (_picked.contains(e.key)) e.key: e.value};
    final total = chosen.entries.fold<int>(0, (a, e) => a + itemSellPrice(e.key) * e.value);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text('씨앗 팔기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => allOn ? _picked.clear() : _picked.addAll(seeds.map((e) => e.key))),
                child: Text(allOn ? '선택 해제' : '전체 선택', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const Align(alignment: Alignment.centerLeft, child: Text('고른 씨앗은 가진 개수를 모두 팔아요 (상점 가격의 절반)', style: TextStyle(fontSize: 12, color: AppColors.sub))),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final e in seeds)
                  CheckboxListTile(
                    value: _picked.contains(e.key),
                    onChanged: (v) => setState(() => v == true ? _picked.add(e.key) : _picked.remove(e.key)),
                    activeColor: AppColors.green,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Text(won(itemSellPrice(e.key) * e.value), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.greenDark)),
                    title: Text('${itemEmoji(e.key)} ${itemName(e.key)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${e.value}개 · 1개 ${won(itemSellPrice(e.key))}', style: const TextStyle(fontSize: 12)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            GreenButton(
              label: chosen.isEmpty ? '팔 씨앗을 골라 주세요' : '${chosen.length}종 팔기 +${won(total)}',
              height: 50,
              onPressed: chosen.isEmpty ? null : () => Navigator.pop(context, chosen),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 창고 목록 한 줄: 그림 · 이름(+작은 설명) · 오른쪽 수량
class _InvRow extends StatelessWidget {
  const _InvRow({required this.leading, required this.title, required this.trailing, this.sub, this.onTap});
  final Widget leading;
  final String title, trailing;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
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
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.sub, size: 20),
        ]),
      ));
}
