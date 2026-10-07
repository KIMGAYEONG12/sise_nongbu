import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 마을 공동기금: 모두가 함께 목표 금액을 모으고, 기부한 농부는 단계 보상을 받는다.
class FundPage extends ConsumerStatefulWidget {
  const FundPage({super.key});
  @override
  ConsumerState<FundPage> createState() => _FundPageState();
}

class _FundPageState extends ConsumerState<FundPage> {
  static const _amounts = [1000, 5000, 10000, 50000];
  int _pick = 1;
  bool _busy = false;

  Future<void> _donate(int amount) async {
    setState(() => _busy = true);
    await runGuarded(context, () => ref.read(farmViewModelProvider).donate(amount), ok: '${won(amount)}을 기부했어요. 고마워요! 🏡');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final fund = ref.watch(fundProvider).valueOrNull ?? FundData.fromMap(null);
    final pct = (fund.ratio * 100).floor();
    final claimed = user.fundClaimed;
    final amount = _amounts[_pick];

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '마을 공동기금', onBack: () => Navigator.of(context).pop(), trailing: MoneyPill(money: user.money)),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                SoftCard(
                  child: Column(children: [
                    const Text('🏡', style: TextStyle(fontSize: 54)),
                    const SizedBox(height: 6),
                    const Text('우리 마을 기금', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    ThinBar(value: fund.ratio, height: 14),
                    const SizedBox(height: 8),
                    Text('$pct%  ·  ${won(fund.total)} / ${won(fund.goal)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('내 기부 합계 ${won(user.fundGiven)}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  ]),
                ),
                const SectionTitle('기부하기'),
                SoftCard(
                  child: Column(children: [
                    Row(children: [
                      for (var i = 0; i < _amounts.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _pick = i),
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i == _pick ? AppColors.green : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: i == _pick ? AppColors.green : AppColors.line),
                                ),
                                child: Text(commaNum(_amounts[i]), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: i == _pick ? Colors.white : AppColors.ink)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    GreenButton(label: '${won(amount)} 기부하기', loading: _busy, onPressed: user.money < amount ? null : () => _donate(amount)),
                    if (user.money < amount)
                      const Padding(padding: EdgeInsets.only(top: 6), child: Text('보유 자금이 부족해요', style: TextStyle(fontSize: 11, color: AppColors.sub))),
                  ]),
                ),
                const SectionTitle('기금 달성 보상'),
                for (final m in fundMilestones)
                  Builder(builder: (_) {
                    final reached = pct >= m.percent;
                    final got = claimed.contains('${m.percent}');
                    return SoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        EmojiBadge(reached ? '🎁' : '🔒'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('기금 ${m.percent}% 달성', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('+${m.points}P · 기부한 농부에게 지급', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                          ]),
                        ),
                        if (got)
                          const Text('수령 완료', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w800))
                        else
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: reached ? () => runGuarded(context, () => ref.read(farmViewModelProvider).claimFund(m), ok: '+${m.points}P를 받았어요') : null,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                              child: const Text('받기', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ]),
                    );
                  }),
                const SizedBox(height: 4),
                const Text('기금은 모든 농부가 함께 채우는 값이에요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.sub)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
