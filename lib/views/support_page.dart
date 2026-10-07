import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

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
    ('작물은 얼마나 걸려 자라나요?', '작물마다 달라요. 물주기·성장촉진제·하우스로 시간을 줄일 수 있어요.'),
    ('신선도는 무엇인가요?', '수확한 뒤 하루가 지날 때마다 5%씩 떨어지고, 최저 70%까지 내려가요. 판매 금액에 곱해져요.'),
    ('이 게임은 실제 거래인가요?', '아니에요. 가상 화폐로 즐기는 게임이며 실제 투자·거래 조언이 아닙니다.'),
  ];

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
                          children: [Text(f.$2, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.sub))],
                        ),
                      ),
                    ),
                  const SectionTitle('의견 보내기'),
                  TextField(controller: _text, minLines: 4, maxLines: 6, maxLength: 500, decoration: const InputDecoration(hintText: '불편한 점이나 바라는 점을 적어 주세요')),
                  const SizedBox(height: 8),
                  GreenButton(label: '보내기', loading: _busy, onPressed: _send),
                ]),
              ),
            ]),
          ),
        ),
      );
}
