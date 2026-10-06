import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';
import 'market_page.dart';

class TradeHistoryPage extends ConsumerWidget {
  const TradeHistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradesProvider).valueOrNull ?? [];
    final profit = ref.watch(userProvider).valueOrNull?['totalProfit'] ?? 0;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Chip(label: Text('누적 수익 ${won(profit)} (매출 − 파종비)'))),
      Expanded(
        child: ListView(children: [
          for (final t in trades)
            ListTile(
              leading: Text(cropOf(t.cropCode).emoji, style: const TextStyle(fontSize: 24)),
              title: Text('${cropOf(t.cropCode).name} ${t.kg.toStringAsFixed(0)}kg → ${won(t.amount)}'),
              subtitle: Text('${won(t.unitPrice)}/kg × 신선도 ${(t.freshness * 100).round()}%'
                  '${t.priceAsOf == null ? '' : ' · ${t.priceAsOf!.month}/${t.priceAsOf!.day} 시세'}'),
            ),
        ]),
      ),
    ]);
  }
}
