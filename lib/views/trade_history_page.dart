import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 거래 기록: 판매 내역과 누적 수익
class TradeHistoryPage extends ConsumerWidget {
  const TradeHistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradesProvider).valueOrNull ?? [];
    final profit = ref.watch(userDataProvider).totalProfit;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '거래 기록', onBack: () => Navigator.of(context).pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SoftCard(child: Row(children: [
                const Text('누적 수익 (매출 − 파종비)', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(won(profit), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ])),
            ),
            Expanded(
              child: trades.isEmpty
                  ? const Center(child: Text('아직 판매 기록이 없어요', style: TextStyle(color: AppColors.sub)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                      for (final t in trades)
                        SoftCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            EmojiBadge(cropOf(t.cropCode).emoji, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${cropOf(t.cropCode).name} ${t.kg.toStringAsFixed(0)}kg → ${won(t.amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${won(t.unitPrice)}/kg × 신선도 ${(t.freshness * 100).round()}%${t.priceAsOf == null ? '' : ' · ${t.priceAsOf!.month}/${t.priceAsOf!.day} 시세'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                              ]),
                            ),
                          ]),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}
