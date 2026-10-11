import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

class _News {
  const _News(this.category, this.emoji, this.title, this.body, [this.time]);
  final String category, emoji, title, body;
  final DateTime? time;
}

/// 농부 뉴스: 시세 변화로 만든 소식 + 게임 안내(이벤트·특수)
class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});
  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage> {
  static const _tabs = ['전체', '시세', '이벤트', '특수'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? const {};
    final news = <_News>[];
    for (final c in crops) {
      final p = prices[c.code];
      if (p == null) continue;
      final pct = changePercent(p.pricePerKg, p.prevPerKg);
      if (pct == null) {
        news.add(_News('시세', c.emoji, '${c.name} 시세 ${krw(p.pricePerKg)}/kg',
            '${p.asOf.month}월 ${p.asOf.day}일 경매 기준 시세예요.', p.asOf));
      } else if (pct.abs() < 0.05) {
        news.add(_News('시세', c.emoji, '${c.name} 시세 보합',
            '전일과 거의 같은 ${krw(p.pricePerKg)}/kg이에요.', p.asOf));
      } else {
        final up = pct > 0;
        news.add(_News(
            '시세',
            c.emoji,
            '${c.name} 시세 ${up ? '상승' : '하락'} ${pct.abs().toStringAsFixed(1)}%',
            '${krw(p.pricePerKg)}/kg으로 전일보다 ${up ? '올랐어요' : '내렸어요'}. ${up ? '지금 출하하면 좋은 값을 받을 수 있어요.' : '값이 오를 때까지 창고에 보관해 볼까요?'}',
            p.asOf));
      }
    }
    news.sort((a, b) {
      final x = a.time, y = b.time;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });
    news.addAll(const [
      _News(
          '이벤트', '📋', '미션을 완료하고 포인트를 받아요', '일일·주간 미션을 채우면 포인트 보상을 받을 수 있어요.'),
      _News('이벤트', '🏡', '마을 공동기금 모으기',
          '기금이 25·50·75·100%에 도달하면 기부한 농부에게 포인트를 드려요.'),
      _News('이벤트', '🧩', '작물 매칭 도전',
          '하루 $gameDailyRewardLimit번까지 점수에 따라 자금과 포인트를 받아요.'),
      _News('특수', '🏠', '하우스로 더 빨리 키워요', '하우스를 설치하면 모든 작물의 성장 시간이 20% 줄어요.'),
      _News('특수', '🧰', '특별 보관함', '특별 상점에서 창고 용량을 늘릴 수 있어요.'),
      _News('특수', '🥔', '감자는 가장 빨리 자라요', '성장 시간이 짧아 자주 수확하고 싶을 때 좋아요.'),
    ]);

    final cat = _tabs[_tab];
    final list =
        _tab == 0 ? news : news.where((n) => n.category == cat).toList();

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
                title: '농부 뉴스', onBack: () => Navigator.of(context).pop()),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: PillTabs(
                    labels: _tabs,
                    index: _tab,
                    onChanged: (v) => setState(() => _tab = v))),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('아직 소식이 없어요',
                          style: TextStyle(color: AppColors.sub)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                          for (final n in list)
                            SoftCard(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    EmojiBadge(n.emoji, size: 46),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: AppColors.greenLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: Text(n.category,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .greenDark)),
                                              ),
                                              if (n.time != null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                    '${n.time!.month}/${n.time!.day}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Color(0xFF111111))),
                                              ],
                                            ]),
                                            const SizedBox(height: 4),
                                            KoText(n.title,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: Color(0xFF000000))),
                                            const SizedBox(height: 2),
                                            KoText(n.body,
                                                style: const TextStyle(
                                                    fontSize: 14.5,
                                                    color: Color(0xFF111111),
                                                    height: 1.45,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ]),
                                    ),
                                  ]),
                            ),
                        ]),
            ),
          ]),
        ),
      ),
    );
  }
}
