import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 판매 선택: 창고의 수확물을 골라 현재 시세로 한꺼번에 출하한다.
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});
  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> {
  final _picked = <String>{};
  bool _busy = false;

  Future<void> _sell(List<Lot> chosen) async {
    setState(() => _busy = true);
    final vm = ref.read(farmViewModelProvider);
    var done = 0;
    String? error;
    for (final l in chosen) {
      try {
        await vm.sell(l);
        done++;
        _picked.remove(l.id);
      } catch (e) {
        error = errMsg(e);
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showMsg(context, done > 0 ? '$done건 판매 후 중단: $error' : error);
    } else {
      showMsg(context, '$done건을 판매했어요 💰');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? const <String, AuctionPrice>{};
    final user = ref.watch(userDataProvider);
    final now = DateTime.now();

    int amountOf(Lot l) {
      final p = prices[l.cropCode];
      return p == null ? 0 : saleAmount(l.kg, p.pricePerKg, freshnessOf(l.harvestedAt, now));
    }

    final chosen = lots.where((l) => _picked.contains(l.id) && prices[l.cropCode] != null).toList();
    final total = chosen.fold<int>(0, (a, l) => a + amountOf(l));
    final sellable = lots.where((l) => prices[l.cropCode] != null).toList();
    final allOn = sellable.isNotEmpty && sellable.every((l) => _picked.contains(l.id));

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
              title: '판매하기',
              onBack: () => Navigator.of(context).pop(),
              trailing: TextButton(
                onPressed: sellable.isEmpty ? null : () => setState(() => allOn ? _picked.clear() : _picked.addAll(sellable.map((l) => l.id))),
                child: Text(allOn ? '선택 해제' : '전체 선택'),
              ),
            ),
            Expanded(
              child: lots.isEmpty
                  ? const Center(child: Text('판매할 작물이 없어요', style: TextStyle(color: AppColors.sub)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                      for (final l in lots)
                        Builder(builder: (_) {
                          final c = cropOf(l.cropCode);
                          final p = prices[l.cropCode];
                          final f = freshnessOf(l.harvestedAt, now);
                          final on = _picked.contains(l.id);
                          return SoftCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: on ? AppColors.greenLight : null,
                            onTap: p == null ? null : () => setState(() => on ? _picked.remove(l.id) : _picked.add(l.id)),
                            child: Row(children: [
                              Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined, color: on ? AppColors.green : AppColors.sub),
                              const SizedBox(width: 10),
                              EmojiBadge(c.emoji, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${c.name} ${l.kg.toStringAsFixed(0)}kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  Text('신선도 ${(f * 100).round()}% · ${p == null ? '시세 없음' : '${won(p.pricePerKg)}/kg'}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                                ]),
                              ),
                              Text(p == null ? '-' : won(amountOf(l)), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.greenDark)),
                            ]),
                          );
                        }),
                    ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .1), blurRadius: 12, offset: const Offset(0, -3))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Text('예상 수익', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(won(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.greenDark)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text('선택 ${chosen.length}건 · 현재 보유 ${won(user.money)}', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                ]),
                const SizedBox(height: 10),
                GreenButton(label: '판매하기', loading: _busy, onPressed: chosen.isEmpty ? null : () => _sell(chosen)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
