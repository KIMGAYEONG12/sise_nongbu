import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'my_page.dart';
import 'package:url_launcher/url_launcher.dart';

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
    ('작물은 얼마나 걸려 자라나요?', '작물마다 달라요. 물주기(한 번에 3%씩)·성장촉진제(한 번에 30%씩)·하우스로 시간을 줄일 수 있어요. 물주기·영양제·성장촉진제 모두 한 밭에 쓰는 횟수 제한이 없어요.\n\n'
        '🏠 하우스는 상점에서 최대 320채까지 지을 수 있고, 한 채에 10,000P예요. '
        '5채까지는 한 채마다 성장 시간이 10%씩, 10채까지는 4%씩 더 줄어 70%, 그 뒤로도 조금씩 늘어 320채에서 최대 95%까지 단축돼요. '
        '하우스를 지을수록 건물이 커지고 이름도 바뀌어요.'),
    ('튜토리얼은 어디에서 보나요? 다시 볼 수 있나요?', '처음 앱을 켜면, 메인 화면 다음에 튜토리얼이 나와요(건너뛰기 가능). 튜토리얼은 처음 한 번만 나오고, 그다음부터는 앱을 켜도 나오지 않아요. 게임 방법이 다시 궁금하시면 이 자주 묻는 질문을 보시거나 농장 화면의 AI 도우미에게 편하게 물어봐 주세요.'),
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

  /// 의견을 받는 메일 주소 (개발자 계정. 플레이 스토어 문의 이메일·개인정보처리방침과 같다)
  static const supportEmail = 'opencarsister2019@gmail.com';

  /// 받는 사람·제목·내용을 채운 메일 앱을 연다. (닉네임을 함께 적어 누가 보냈는지 알 수 있게)
  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) {
      showMsg(context, '보낼 내용을 적어 주세요');
      return;
    }
    setState(() => _busy = true);
    final user = ref.read(userDataProvider);
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQuery({'subject': '[하루 농장] 고객센터 의견', 'body': '$t\n\n──────\n보낸 농부: ${user.nickname} (Lv.${user.level.level})'}),
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (opened) {
      _text.clear();
      showMsg(context, '메일 앱에서 보내기를 누르면 의견이 전달돼요. 고마워요!');
    } else {
      showMsg(context, '메일 앱을 열지 못했어요. $supportEmail 로 직접 보내 주세요');
    }
  }

  /// mailto 주소는 공백을 +가 아니라 %20으로 바꿔야 메일 앱에서 글자가 그대로 보인다
  static String _encodeQuery(Map<String, String> q) =>
      q.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

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
                  const SectionTitle('의견 보내기'),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('보내기를 누르면 메일 앱이 열려요. 내용을 확인하고 메일 앱에서 보내기를 눌러 주세요.', style: TextStyle(fontSize: 12.5, color: _gray, fontWeight: FontWeight.w600)),
                  ),
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
