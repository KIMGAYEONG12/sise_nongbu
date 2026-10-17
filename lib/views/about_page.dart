import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 앱 정보: 데모 모드, 자금 되돌리기, 가상 게임 안내, 시세·날씨 출처.
/// 설명 문구는 [ka]로 낱말이 글자 단위로 끊기지 않게 한다.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  Future<void> _resetMoney(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('자금을 되돌릴까요?'),
        content: KoText('보유 자금이 ${won(startMoney)}가 돼요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('되돌리기')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runGuarded(context, () => ref.read(farmRepoProvider).resetMoney(),
        ok: '자금을 ${won(startMoney)}로 되돌렸어요');
  }

  static const _titleStyle = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF000000));
  static const _bodyStyle = TextStyle(
      fontSize: 13.5,
      height: 1.55,
      color: Color(0xFF111111),
      fontWeight: FontWeight.w500);

  /// 제목 + 설명 한 칸 (스위치·버튼 없이 글만 있는 카드)
  Widget _info(String title, List<String> lines) => SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KoText(title, style: _titleStyle),
          for (final l in lines) ...[
            const SizedBox(height: 8),
            KoText(l, style: _bodyStyle),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(speedProvider) >= demoSpeed;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
                title: '앱 정보', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _info('시세 출처', [
                      '데이터: 한국농수산식품유통공사(aT)의 "전국 공영도매시장 실시간 경매정보" (공공데이터포털 data.go.kr 오픈 API)',
                      '시장: 서울가락도매시장 (전국 최대 거래량)\n품목: 배추·무·양파·사과·토마토·감자',
                      '계산: 경매 한 건마다 낙찰가를 포장 무게(kg)로 나눠 kg당 가격으로 바꾸고, 거래량이 많은 가격에 더 큰 비중을 주는 거래량 가중평균으로 시세를 만들어요. 등락률은 직전 거래일 대비예요.',
                      '갱신: 서버가 약 10분마다 새 경매 기록을 받아 저장하고, 앱은 그 값이 바뀌는 즉시 화면에 반영해요. 서버가 끊기면 앱이 5분마다 직접 조회해요.',
                      '휴장일(일요일·명절)에는 거래가 있었던 가장 최근 날의 시세를 쓰고 "○월 ○일 기준"으로 표시해요.',
                      '시세는 도매시장 경매 낙찰가라서 마트·소매 가격과 달라요. 게임 안에서는 이 시세에 수확량을 곱해 판매 금액(P)을 계산해요.',
                    ]),
                    const SizedBox(height: 8),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: SwitchListTile(
                        title: const KoText('작물 성장 빠르게 올리기',
                            style: _titleStyle),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: KoText(
                              '켜시면 어떤 작물이든 심고, 1초 뒤에 바로 수확하실 수 있어요.',
                              style: _bodyStyle),
                        ),
                        value: demo,
                        onChanged: (v) => ref
                            .read(speedProvider.notifier)
                            .state = v ? demoSpeed : 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: ListTile(
                        leading: const CoinIcon(size: 28),
                        title: KoText('자금을 ${won(startMoney)}로 되돌리기',
                            style: _titleStyle),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: KoText(
                              '테스트용: 보유 자금을 시작 자금으로 맞춰요 (작물·창고·아이템은 그대로)',
                              style: _bodyStyle),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _resetMoney(context, ref),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _info('가상 게임 안내', [
                      '이 앱의 Point(P)는 게임 안에서만 쓰는 가상 화폐예요. 실제 돈과 아무 관련이 없고, 현금으로 바꾸거나 인출할 수 없어요.',
                      '실제 투자·거래 조언이 아니에요.',
                    ]),
                    const SizedBox(height: 8),
                    _info('날씨 출처', [
                      'OpenWeather 현재 날씨 API를 우선 쓰고, 안 되면 Open-Meteo(무료)로 자동 전환해요. 기준 위치는 서울이고 30분마다 갱신해요.',
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
