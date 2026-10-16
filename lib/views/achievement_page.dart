import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'fund_page.dart';
import 'match_game_page.dart';

/// 업적 현황: 전체 / 일반 / 도전 / 특별
class AchievementPage extends ConsumerStatefulWidget {
  const AchievementPage({super.key});
  @override
  ConsumerState<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends ConsumerState<AchievementPage> {
  static const _tabs = ['전체', '일반', '도전', '특별'];
  int _tab = 0;

  /// 받을 수 있는 업적을 한 번에 모두 받는다. 하나가 실패하면 거기서 멈추고, 그때까지 받은 만큼은 안내한다.
  Future<void> _claimAll(List<AchievementDef> list) async {
    final vm = ref.read(farmViewModelProvider);
    var got = 0, pts = 0;
    try {
      for (final a in list) {
        await vm.claimAchievement(a);
        got++;
        pts += a.points;
      }
      if (mounted) showMsg(context, '업적 $got개를 한 번에 받았어요 (+${pts}P)');
    } catch (e) {
      if (mounted) showMsg(context, got > 0 ? '$got개(+${pts}P)를 받고 멈췄어요: ${errMsg(e)}' : errMsg(e));
    }
  }

  /// 업적을 이루러 갈 화면 (없으면 null)
  Widget? _goTo(String id) {
    if (id == 'puzzle') return const MatchGamePage();
    if (id == 'helper') return const FundPage();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final plots = ref.watch(plotsProvider).valueOrNull?.length ?? plotCount;
    final claimed = user.achClaimed;
    final list = achievements.where((a) => _tab == 0 || a.category == _tabs[_tab]).toList();
    final doneCount = achievements.where((a) => claimed.contains(a.id)).length;
    // 달성했지만 아직 안 받은 업적 (탭과 상관없이 전체)
    final claimable = [for (final a in achievements) if (!claimed.contains(a.id) && achievementProgress(a, user.raw, plots) >= a.target) a];
    final claimablePts = claimable.fold<int>(0, (s, a) => s + a.points);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '업적 현황', onBack: () => Navigator.of(context).pop(), trailing: PointPill(points: user.points)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: PillTabs(labels: _tabs, index: _tab, onChanged: (v) => setState(() => _tab = v))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Align(alignment: Alignment.centerLeft, child: Text('달성한 업적 $doneCount/${achievements.length}', style: const TextStyle(fontSize: 15, color: Color(0xFF000000), fontWeight: FontWeight.w800))),
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
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF000000))),
                            const SizedBox(height: 2),
                            KoText(a.desc, style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF000000), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: ThinBar(value: shown / a.target, height: 9)),
                              const SizedBox(width: 10),
                              Text('${commaNum(shown)}/${commaNum(a.target)}', style: const TextStyle(fontSize: 13, color: Color(0xFF000000), fontWeight: FontWeight.w800)),
                            ]),
                            // 게임·기부처럼 직접 해야 하는 업적은 바로 가는 버튼을 둔다
                            if (!reached && _goTo(a.id) != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _goTo(a.id)!)),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.greenDark, side: const BorderSide(color: AppColors.green, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                                    child: Text(a.id == 'puzzle' ? '🥬 퍼즐 하러 가기' : '🏡 기부하러 가기', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ),
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
                              child: Text('받기 +${a.points}P', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                            ),
                          )
                        else
                          Text('+${a.points}P', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFE08A00))),
                      ]),
                    );
                  }),
              ]),
            ),
            // 받을 수 있는 보상을 한 번에 받는 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GreenButton(
                label: claimable.isEmpty ? '받을 보상이 없어요' : '전체 받기 +${claimablePts}P (${claimable.length}개)',
                onPressed: claimable.isEmpty ? null : () => _claimAll(claimable),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
