import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(speedProvider) > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('데모 모드 (성장 600배속)'),
          subtitle: const Text('이후 파종하는 작물부터 적용돼요'),
          value: demo,
          onChanged: (v) => ref.read(speedProvider.notifier).state = v ? 600 : 1,
        ),
        const ListTile(title: Text('가상 게임 안내'), subtitle: Text('가상 화폐로 진행하는 게임이며 실제 투자·거래 조언이 아닙니다.')),
        const ListTile(title: Text('시세 출처'), subtitle: Text('한국농수산식품유통공사 전국 공영도매시장 실시간 경매정보 (공공데이터포털)')),
        FutureBuilder<String?>(
          future: ref.read(farmRepoProvider).fcmToken(),
          builder: (_, s) => ListTile(title: const Text('FCM 토큰 (테스트 메시지용)'), subtitle: SelectableText(s.data ?? '확인 중…')),
        ),
      ]),
    );
  }
}
