import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  Future<void> _resetMoney(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('자금을 되돌릴까요?'),
        content: const Text('보유 자금이 100,000원이 돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('되돌리기')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(context, () => ref.read(farmRepoProvider).resetMoney(), ok: '자금을 100,000원으로 되돌렸어요');
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(speedProvider) > 1;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '앱 정보', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SwitchListTile(
                    title: const Text('데모 모드 (성장 600배속)'),
                    subtitle: const Text('발표·시연용으로 작물이 600배 빨리 자라요. 예) 50분 걸리는 배추가 약 5초 만에 수확돼요.\n켠 뒤에 새로 심는 작물부터 적용되고, 이미 심은 작물은 원래 속도로 자라요.'),
                    isThreeLine: true,
                    value: demo,
                    onChanged: (v) => ref.read(speedProvider.notifier).state = v ? 600 : 1,
                  ),
                ),
                const SizedBox(height: 8),
                SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ListTile(
                    leading: const CoinIcon(size: 28),
                    title: const Text('자금을 100,000원으로 되돌리기'),
                    subtitle: const Text('테스트용: 보유 자금을 시작 자금으로 맞춰요 (작물·창고·아이템은 그대로)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _resetMoney(context, ref),
                  ),
                ),
                const SizedBox(height: 8),
                const SoftCard(child: ListTile(title: Text('가상 게임 안내'), subtitle: Text('가상 화폐로 진행하는 게임이며 실제 투자·거래 조언이 아닙니다.'))),
                const SizedBox(height: 8),
                const SoftCard(child: ListTile(title: Text('시세 출처'), subtitle: Text('한국농수산식품유통공사 전국 공영도매시장 실시간 경매정보 (공공데이터포털)'))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
