import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'my_page.dart';
import 'tutorial_page.dart';

/// 고객센터: 자주 묻는 질문과 의견 보내기
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _text = TextEditingController();
  bool _busy = false;

  static const _faq = [
    ('시세는 어디서 가져오나요?', '공공데이터포털의 전국 공영도매시장 경매 정보를 사용해요. 키가 없으면 샘플 시세로 동작해요.'),
    ('작물은 얼마나 걸려 자라나요?', '작물마다 달라요. 물주기(밭당 3번 10%씩)·성장촉진제(횟수 제한 없이 30%씩)·하우스로 시간을 줄일 수 있어요.\n\n'
        '🏠 하우스는 상점에서 몇 채든 살 수 있어요. 첫 하우스는 20,000P이고 한 채 늘 때마다 10,000P씩 비싸져요. '
        '5채까지는 한 채마다 성장 시간이 10%씩, 그 뒤로는 4%씩 더 줄어서 최대 70%까지 단축돼요. '
        '하우스를 지을수록 건물이 커지고 이름도 바뀌어요.'),
    ('튜토리얼은 어디에서 보나요? 다시 볼 수 있나요?', '앱을 켜면 스플래시 다음에 튜토리얼이 나와요(건너뛰기 가능). 언제든 아래 "튜토리얼 다시 보기"를 누르면 다시 볼 수 있어요.'),
    ('신선도는 무엇인가요?', '수확한 뒤 하루가 지날 때마다 5%씩 떨어지고, 최저 70%까지 내려가요. 판매 금액에 곱해져요.'),
    ('이 게임은 실제 거래인가요?', '아니에요. 가상 화폐로 즐기는 게임이며 실제 투자·거래 조언이 아닙니다.'),
    ('농작물 통계는 어디서 보나요?', 'MY → 농작물 통계, 또는 바로 아래 "농작물 통계"를 누르면 누적 수익과 파종·수확·판매 횟수, 작물별 수확 횟수를 볼 수 있어요.'),
  ];

  /// 이 화면의 회색 글씨 (기본 회색보다 진하게 해서 잘 읽히게)
  static const _gray = Color(0xFF46564B);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    final ok = await runGuarded(context, () => ref.read(farmViewModelProvider).sendFeedback(t), ok: '의견을 보냈어요. 고마워요!');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              PageHeader(title: '고객센터', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  const SectionTitle('자주 묻는 질문'),
                  for (final f in _faq)
                    SoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [KoText(f.$2, style: const TextStyle(fontSize: 13.5, height: 1.5, color: _gray, fontWeight: FontWeight.w500))],
                        ),
                      ),
                    ),
                  // MY 화면의 '농작물 통계' 메뉴와 같은 모양의 바로가기
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => showCropStats(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        child: Row(children: [
                          Icon(Icons.bar_chart_rounded, color: Color(0xFF2B3A30), size: 24),
                          SizedBox(width: 14),
                          Expanded(child: Text('농작물 통계', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1C2B20)))),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFF2B3A30)),
                        ]),
                      ),
                    ),
                  ),
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => TutorialPage(onDone: () => Navigator.of(c).pop()))),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        child: Row(children: [
                          Icon(Icons.school_rounded, color: Color(0xFF2B3A30), size: 24),
                          SizedBox(width: 14),
                          Expanded(child: Text('튜토리얼 다시 보기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1C2B20)))),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFF2B3A30)),
                        ]),
                      ),
                    ),
                  ),
                  const SectionTitle('의견 보내기'),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: '불편한 점이나 바라는 점을 적어 주세요',
                      hintStyle: TextStyle(color: _gray, fontSize: 14),
                      counterStyle: TextStyle(color: _gray, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GreenButton(label: '보내기', loading: _busy, onPressed: _send),
                ]),
              ),
            ]),
          ),
        ),
      );
}
