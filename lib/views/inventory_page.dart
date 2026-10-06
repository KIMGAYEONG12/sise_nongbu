import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';
import 'market_page.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lots = ref.watch(lotsProvider).valueOrNull ?? [];
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? {};
    if (lots.isEmpty) return const Center(child: Text('창고가 비어 있어요'));
    return ListView(children: [
      for (final l in lots)
        Builder(builder: (_) {
          final c = cropOf(l.cropCode), p = prices[l.cropCode];
          final f = freshnessOf(l.harvestedAt, DateTime.now());
          return ListTile(
            leading: Text(c.emoji, style: const TextStyle(fontSize: 28)),
            title: Text('${c.name} ${l.kg.toStringAsFixed(0)}kg · 신선도 ${(f * 100).round()}%'),
            subtitle: Text(p == null ? '시세 없음' : '예상 대금 ${won(saleAmount(l.kg, p.pricePerKg, f))}'),
            trailing: ElevatedButton(
              onPressed: p == null ? null : () => _confirm(context, ref, l, won(saleAmount(l.kg, p.pricePerKg, f))),
              child: const Text('출하'),
            ),
          );
        }),
    ]);
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, lot, String amount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('출하할까요?'),
        content: Text('현재 시세 기준 $amount 에 정산돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(farmViewModelProvider).sell(lot);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
