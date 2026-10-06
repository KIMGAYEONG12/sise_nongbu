import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';

String won(num v) => '${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원';

class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(marketViewModelProvider);
    return vm.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('시세를 불러오지 못했어요'),
        ElevatedButton(onPressed: () => ref.read(marketViewModelProvider.notifier).refresh(), child: const Text('다시 시도')),
      ])),
      data: (prices) => RefreshIndicator(
        onRefresh: () => ref.read(marketViewModelProvider.notifier).refresh(),
        child: ListView(children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('가상 게임이며 실제 투자·거래 조언이 아닙니다.', style: TextStyle(color: Colors.grey))),
          for (final c in crops)
            if (prices[c.code] case final p?)
              ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 28)),
                title: Text('${c.name}  ${won(p.pricePerKg)}/kg'),
                subtitle: Text('${p.asOf.month}월 ${p.asOf.day}일 기준'),
                trailing: p.change == null ? null : Text('${p.change! >= 0 ? '↗' : '↘'} ${won(p.change!.abs())}',
                    style: TextStyle(color: p.change! >= 0 ? Colors.red : Colors.blue)),
              ),
        ]),
      ),
    );
  }
}
