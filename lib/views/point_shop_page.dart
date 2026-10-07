import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 포인트 상점 목록 (상점 탭과 독립 화면에서 같이 쓴다)
class PointShopBody extends ConsumerWidget {
  const PointShopBody({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, PointItem item) async {
    String? code;
    var msg = '${item.name}을(를) 받았어요';
    if (item.key == pointRareSeed) {
      final c = crops[Random().nextInt(crops.length)];
      code = c.code;
      msg = '${c.emoji} ${c.name} 씨앗 3개를 받았어요!';
    }
    await runGuarded(context, () => ref.read(farmViewModelProvider).buyPointItem(item, cropCode: code), ok: msg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      for (final item in pointItems)
        Builder(builder: (_) {
          String? blocked;
          if (item.key == pointDecor && user.decor >= maxDecor) blocked = '최대';
          if (item.key == pointVault && user.warehouseBonusKg >= maxVaultBonusKg) blocked = '최대';
          final short = user.points < item.cost;
          return SoftCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              EmojiBadge(item.emoji, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(item.desc, style: const TextStyle(fontSize: 12, color: AppColors.sub, height: 1.3)),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: blocked != null || short ? null : () => _buy(context, ref, item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.sub,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(blocked ?? '${item.cost}P', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            ]),
          );
        }),
    ]);
  }
}

class PointShopPage extends ConsumerWidget {
  const PointShopPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '포인트 상점', onBack: () => Navigator.of(context).pop(), trailing: PointPill(points: user.points)),
            const Expanded(child: PointShopBody()),
          ]),
        ),
      ),
    );
  }
}
