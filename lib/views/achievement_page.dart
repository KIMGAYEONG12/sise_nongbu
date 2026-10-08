import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 업적 현황: 전체 / 일반 / 도전 / 특별
class AchievementPage extends ConsumerStatefulWidget {
  const AchievementPage({super.key});
  @override
  ConsumerState<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends ConsumerState<AchievementPage> {
  static const _tabs = ['전체', '일반', '도전', '특별'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final plots = ref.watch(plotsProvider).valueOrNull?.length ?? plotCount;
    final claimed = user.achClaimed;
    final list = achievements.where((a) => _tab == 0 || a.category == _tabs[_tab]).toList();
    final doneCount = achievements.where((a) => claimed.contains(a.id)).length;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '업적 현황', onBack: () => Navigator.of(context).pop(), trailing: PointPill(points: user.points)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: PillTabs(labels: _tabs, index: _tab, onChanged: (v) => setState(() => _tab = v))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Align(alignment: Alignment.centerLeft, child: Text('달성한 업적 $doneCount/${achievements.length}', style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w700))),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                for (final a in list)
                  Builder(builder: (_) {
                    final raw = achievementProgress(a, user.raw, plots);
                    final shown = raw > a.target ? a.target : raw;
                    final reached = raw >= a.target;
                    final got = claimed.contains(a.id);
                    return SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        EmojiBadge(a.emoji, size: 48, color: got ? AppColors.greenLight : null),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text(ka(a.desc), style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: ThinBar(value: shown / a.target, height: 6)),
                              const SizedBox(width: 8),
                              Text('${commaNum(shown)}/${commaNum(a.target)}', style: const TextStyle(fontSize: 11, color: AppColors.sub, fontWeight: FontWeight.w700)),
                            ]),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        if (got)
                          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28)
                        else if (reached)
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => runGuarded(context, () => ref.read(farmViewModelProvider).claimAchievement(a), ok: '+${a.points}P를 받았어요'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                              child: Text('받기 +${a.points}P', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          )
                        else
                          Text('+${a.points}P', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.coin)),
                      ]),
                    );
                  }),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
