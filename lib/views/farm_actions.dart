import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'harvest_result_page.dart';
import '../core/korean.dart';

/// 성장 시간 문구 (예: 4시간, 6분, 24초)
String durText(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}시간${d.inMinutes % 60 == 0 ? '' : ' ${d.inMinutes % 60}분'}';
  if (d.inMinutes >= 1) return '${d.inMinutes}분';
  return '${d.inSeconds}초';
}

/// 빈 밭을 눌렀을 때: 심을 작물을 고르는 시트
Future<void> showPlantSheet(BuildContext context, WidgetRef ref, Plot plot) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Consumer(builder: (_, ref2, __) {
      final user = ref2.watch(userDataProvider);
      final speed = ref2.watch(speedProvider);
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          const Text('무엇을 심을까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('보유 자금 ${won(user.money)}${user.greenhouse ? ' · 🏠 하우스로 성장 20% 단축' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
              for (final c in crops)
                Builder(builder: (_) {
                  final seeds = user.item(seedKey(c.code));
                  final dur = applyGreenhouse(growDuration(c, speed), user.greenhouse);
                  return SoftCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      runGuarded(context, () => ref.read(farmViewModelProvider).plant(plot.index, c), ok: '${withJosa(c.name, '을', '를')} 심었어요 🌱');
                    },
                    child: Row(children: [
                      EmojiBadge(c.emoji),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('수확 ${c.yieldKg.toStringAsFixed(0)}kg · ${durText(dur)}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: seeds > 0 ? AppColors.greenLight : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
                        child: Text(seeds > 0 ? '씨앗 사용 ($seeds)' : won(c.seedCost), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: seeds > 0 ? AppColors.greenDark : AppColors.ink)),
                      ),
                    ]),
                  );
                }),
            ]),
          ),
        ]),
      );
    }),
  );
}

/// 다 자란 밭 수확: 성공하면 수확 완료 화면을 연다.
Future<void> harvestPlot(BuildContext context, WidgetRef ref, Plot plot) async {
  final cropCode = plot.cropCode;
  if (cropCode == null) return;
  try {
    final kg = await ref.read(farmViewModelProvider).harvest(plot);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HarvestResultPage(cropCode: cropCode, kg: kg)));
  } catch (e) {
    showMsg(context, errMsg(e));
  }
}
