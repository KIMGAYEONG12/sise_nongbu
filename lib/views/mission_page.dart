import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 일일·주간 미션. 목표를 채우면 포인트를 받을 수 있다.
class MissionPage extends ConsumerStatefulWidget {
  const MissionPage({super.key});
  @override
  ConsumerState<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends ConsumerState<MissionPage> {
  int _tab = 0;

  /// 지금 바로 받을 수 있는 미션 (일일·주간 모두): 목표를 채웠고 아직 안 받은 것
  List<MissionDef> _claimable(UserData user, DateTime now) {
    final out = <MissionDef>[];
    for (final weekly in [false, true]) {
      final list = weekly ? weeklyMissions : dailyMissions;
      final tag = weekly ? weekTag(now) : dayTag(now);
      final map = weekly ? user.weekly : user.daily;
      final claimed = periodClaimed(map, tag);
      for (final m in list) {
        if (periodCount(map, tag, m.key) >= m.target && !claimed.contains(m.id)) out.add(m);
      }
    }
    return out;
  }

  /// 받을 수 있는 미션 보상을 한 번에 모두 받는다. 하나가 실패하면 거기서 멈추고, 그때까지 받은 만큼은 안내한다.
  Future<void> _claimAll(List<MissionDef> list) async {
    final vm = ref.read(farmViewModelProvider);
    var got = 0, pts = 0;
    try {
      for (final m in list) {
        await vm.claimMission(m);
        got++;
        pts += m.points;
      }
      if (mounted) showMsg(context, '미션 $got개를 한 번에 받았어요 (+${cash(pts)})');
    } catch (e) {
      if (mounted) showMsg(context, got > 0 ? '$got개(+${cash(pts)})를 받고 멈췄어요: ${errMsg(e)}' : errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final now = DateTime.now();
    final weekly = _tab == 1;
    final list = weekly ? weeklyMissions : dailyMissions;
    final tag = weekly ? weekTag(now) : dayTag(now);
    final map = weekly ? user.weekly : user.daily;
    final claimed = periodClaimed(map, tag);
    final claimable = _claimable(user, now);
    final claimablePts = claimable.fold<int>(0, (a, m) => a + m.points);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '미션', onBack: () => Navigator.of(context).pop(), trailing: PointPill(points: user.points)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PillTabs(labels: const ['일일 미션', '주간 미션'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
            // 위쪽에도 "전체 받기": 목록이 길어도 바로 눌러 한 번에 받을 수 있다 (아래 큰 버튼과 같은 동작)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GreenButton(
                height: 44,
                icon: const Icon(Icons.redeem_rounded, size: 20),
                label: claimable.isEmpty ? '받을 보상이 없어요' : '전체 받기 +${cash(claimablePts)} (${claimable.length}개)',
                onPressed: claimable.isEmpty ? null : () => _claimAll(claimable),
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                for (final m in list)
                  Builder(builder: (_) {
                    final raw = periodCount(map, tag, m.key);
                    final count = raw > m.target ? m.target : raw;
                    final done = raw >= m.target;
                    final got = claimed.contains(m.id);
                    return SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        EmojiBadge(m.emoji, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: ThinBar(value: count / m.target, height: 6)),
                              const SizedBox(width: 8),
                              Text('$count/${m.target}', style: const TextStyle(fontSize: 11, color: AppColors.sub, fontWeight: FontWeight.w700)),
                            ]),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        if (got)
                          const Text('수령 완료', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w800))
                        else if (done)
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => runGuarded(context, () => ref.read(farmViewModelProvider).claimMission(m), ok: '+${cash(m.points)}를 받았어요'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                              child: Text('받기 +${cash(m.points)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          )
                        else
                          Text('+${cash(m.points)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.coin)),
                      ]),
                    );
                  }),
                const SizedBox(height: 6),
                Center(child: Text(weekly ? '주간 미션은 매주 월요일에 초기화돼요.' : '일일 미션은 매일 자정에 초기화돼요.', style: const TextStyle(fontSize: 12, color: AppColors.sub))),
              ]),
            ),
            // 받을 수 있는 보상을 한 번에 받는 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GreenButton(
                label: claimable.isEmpty ? '받을 보상이 없어요' : '전체 받기 +${cash(claimablePts)} (${claimable.length}개)',
                onPressed: claimable.isEmpty ? null : () => _claimAll(claimable),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
