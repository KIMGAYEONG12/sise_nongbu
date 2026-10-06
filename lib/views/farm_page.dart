import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import 'market_page.dart';

class FarmPage extends ConsumerWidget {
  const FarmPage({super.key});

  void _run(BuildContext ctx, Future<void> f) => f.catchError((e) {
        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${e is StateError ? e.message : e}')));
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(userProvider).valueOrNull?['money'] ?? 0;
    final plots = ref.watch(plotsProvider);
    final now = ref.watch(tickProvider).valueOrNull ?? DateTime.now();
    final vm = ref.read(farmViewModelProvider);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('💰 ${won(money)}', style: Theme.of(context).textTheme.headlineSmall)),
      Expanded(
        child: plots.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => LayoutBuilder(builder: (_, box) => GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: box.maxWidth > 600 ? 4 : 2, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final c = p.isEmpty ? null : cropOf(p.cropCode!);
              final ready = p.isReady(now);
              return Card(
                child: InkWell(
                  onTap: () {
                    if (p.isEmpty) {
                      _showPlantSheet(context, (spec) => _run(context, vm.plant(p.index, spec)));
                    } else if (ready) {
                      _run(context, vm.harvest(p));
                    }
                  },
                  child: Center(child: Text(c == null ? '빈 밭\n탭해서 파종' : '${c.emoji} ${c.name}\n${ready ? '수확 가능!' : _left(p, now)}', textAlign: TextAlign.center)),
                ),
              );
            },
          )),
        ),
      ),
    ]);
  }

  String _left(Plot p, DateTime now) {
    final d = p.readyAt!.difference(now);
    return '${d.inMinutes}분 ${d.inSeconds % 60}초 남음';
  }

  void _showPlantSheet(BuildContext context, void Function(CropSpec) onPick) => showModalBottomSheet(
        context: context,
        builder: (_) => ListView(children: [
          for (final c in crops)
            ListTile(
              leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(c.name),
              subtitle: Text('파종비 ${won(c.seedCost)} · 수확 ${c.yieldKg.toStringAsFixed(0)}kg'),
              onTap: () {
                Navigator.pop(context);
                onPick(c);
              },
            ),
        ]),
      );
}
