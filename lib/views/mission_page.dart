import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final now = DateTime.now();
    final weekly = _tab == 1;
    final list = weekly ? weeklyMissions : dailyMissions;
    final tag = weekly ? weekTag(now) : dayTag(now);
    final map = weekly ? user.weekly : user.daily;
    final claimed = periodClaimed(map, tag);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '미션', onBack: () => Navigator.of(context).pop(), trailing: PointPill(points: user.points)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PillTabs(labels: const ['일일 미션', '주간 미션'], index: _tab, onChanged: (v) => setState(() => _tab = v))),
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
                              onPressed: () => runGuarded(context, () => ref.read(farmViewModelProvider).claimMission(m), ok: '+${m.points}P를 받았어요'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                              child: Text('받기 +${m.points}P', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          )
                        else
                          Text('+${m.points}P', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.coin)),
                      ]),
                    );
                  }),
                const SizedBox(height: 6),
                Center(child: Text(weekly ? '주간 미션은 매주 월요일에 초기화돼요.' : '일일 미션은 매일 자정에 초기화돼요.', style: const TextStyle(fontSize: 12, color: AppColors.sub))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
