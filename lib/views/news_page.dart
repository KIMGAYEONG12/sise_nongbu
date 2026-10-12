import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'fund_page.dart';
import 'match_game_page.dart';
import 'mission_page.dart';
import 'point_shop_page.dart';
import 'price_detail_page.dart';

/// 뉴스를 눌렀을 때 가는 곳
enum NewsGo { missions, fund, match, shop, pointShop }

/// 뉴스 한 건. 시세 소식은 작물 그림·kg당 가격·등락률이 함께 나오고, 이벤트·특수 소식은 이모지와 안내 글만 나온다.
class NewsItem {
  const NewsItem(this.category, this.emoji, this.title, this.body, {this.time, this.cropCode, this.price, this.percent, this.tag, this.go, this.openCrop});

  /// 시세 · 이벤트 · 특수
  final String category;
  final String emoji, title, body;
  final DateTime? time;

  /// 시세 소식이면 작물 코드 (그림을 보여 준다)
  final String? cropCode;

  /// kg당 시세(원)와 전일 대비 등락률(%). 비교할 값이 없으면 percent는 null.
  final double? price, percent;

  /// 가격 옆에 붙는 작은 꼬리표 (예: 출하 추천 · 보관 추천)
  final String? tag;

  /// 눌렀을 때 열 화면: 작물 시세 상세([openCrop]) 또는 게임 안의 해당 화면([go]). 둘 다 없으면 눌러도 이동하지 않는다.
  final NewsGo? go;
  final String? openCrop;

  bool get tappable => go != null || openCrop != null;

  bool get isUp => (percent ?? 0) >= 0.05;
  bool get isDown => (percent ?? 0) <= -0.05;
}

/// 시세로 만든 소식 목록 (최근 날짜 순) + 게임 안내 소식
List<NewsItem> buildNews(Map<String, AuctionPrice> prices) {
  final news = <NewsItem>[];
  for (final c in crops) {
    final p = prices[c.code];
    if (p == null) continue;
    final pct = changePercent(p.pricePerKg, p.prevPerKg);
    if (pct == null) {
      news.add(NewsItem('시세', c.emoji, '${c.name} 시세 ${krw(p.pricePerKg)}/kg', '${p.asOf.month}월 ${p.asOf.day}일 경매 기준 시세예요.',
          time: p.asOf, cropCode: c.code, price: p.pricePerKg, openCrop: c.code));
    } else if (pct.abs() < 0.05) {
      news.add(NewsItem('시세', c.emoji, '${c.name} 시세 보합', '전일과 거의 같은 ${krw(p.pricePerKg)}/kg이에요.',
          time: p.asOf, cropCode: c.code, price: p.pricePerKg, percent: pct, tag: '보합', openCrop: c.code));
    } else {
      final up = pct > 0;
      news.add(NewsItem(
        '시세',
        c.emoji,
        '${c.name} 시세 ${up ? '상승' : '하락'} ${pct.abs().toStringAsFixed(1)}%',
        '${krw(p.pricePerKg)}/kg으로 전일보다 ${up ? '올랐어요' : '내렸어요'}. ${up ? '지금 출하하면 좋은 값을 받을 수 있어요.' : '값이 오를 때까지 창고에 보관해 볼까요?'}',
        time: p.asOf,
        cropCode: c.code,
        price: p.pricePerKg,
        percent: pct,
        tag: up ? '출하 추천' : '보관 추천',
        openCrop: c.code,
      ));
    }
  }
  news.sort((a, b) {
    final x = a.time, y = b.time;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  });
  news.addAll(const [
    NewsItem('이벤트', '📋', '미션을 완료하고 포인트를 받아요', '일일·주간 미션을 채우면 포인트 보상을 받을 수 있어요.', go: NewsGo.missions),
    NewsItem('이벤트', '🏡', '마을 공동기금 모으기', '기금이 25·50·75·100%에 도달하면 기부한 농부에게 포인트를 드려요.', go: NewsGo.fund),
    NewsItem('이벤트', '🧩', '작물 매칭 도전', '하루 $gameDailyRewardLimit번까지 점수에 따라 자금과 포인트를 받아요.', go: NewsGo.match),
    NewsItem('특수', '🏠', '하우스로 더 빨리 키워요', '하우스를 지을 때마다 모든 작물의 성장 시간이 줄어요. 10채면 최대 70%까지 줄어요.', go: NewsGo.shop),
    NewsItem('특수', '🧰', '특별 보관함', '특별 상점에서 창고 용량을 늘릴 수 있어요.', go: NewsGo.pointShop),
    NewsItem('특수', '🥔', '감자는 가장 빨리 자라요', '성장 시간이 짧아 자주 수확하고 싶을 때 좋아요.', openCrop: 'POTATO'),
  ]);
  return news;
}

/// 전국 농부 뉴스: 시세 변화로 만든 소식 + 게임 안내(이벤트·특수)
class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});
  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage> {
  static const _tabs = ['전체', '시세', '이벤트', '특수'];
  int _tab = 0;

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// 뉴스를 눌렀을 때: 시세 소식은 그 작물 시세 상세로, 게임 소식은 해당 화면으로 간다.
  void _open(NewsItem n) {
    final crop = n.openCrop;
    if (crop != null) {
      _push(PriceDetailPage(cropCode: crop));
      return;
    }
    switch (n.go) {
      case NewsGo.missions:
        _push(const MissionPage());
      case NewsGo.fund:
        _push(const FundPage());
      case NewsGo.match:
        _push(const MatchGamePage());
      case NewsGo.pointShop:
        _push(const PointShopPage());
      case NewsGo.shop:
        // 하우스는 일반 상점에서 짓는다: 맨 앞 화면으로 돌아가 상점 탭을 연다
        ref.read(shellIndexProvider.notifier).state = 3;
        Navigator.of(context).popUntil((r) => r.isFirst);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? const <String, AuctionPrice>{};
    final news = buildNews(prices);
    final cat = _tabs[_tab];
    final list = _tab == 0 ? news : news.where((n) => n.category == cat).toList();

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '전국 농부 뉴스', onBack: () => Navigator.of(context).pop()),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PillTabs(labels: _tabs, index: _tab, onChanged: (v) => setState(() => _tab = v))),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('아직 소식이 없어요', style: TextStyle(color: AppColors.sub)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final n in list) NewsCard(item: n, onTap: n.tappable ? () => _open(n) : null)]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 시안의 뉴스 카드: 왼쪽 둥근 그림 · 가운데 제목과 "가격 + 꼬리표" · 오른쪽 ▲▼ 등락률
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item, this.onTap});
  final NewsItem item;

  /// 누르면 이동할 곳 (없으면 눌러도 아무 일 없음)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = item;
    final tone = n.isUp ? AppColors.up : (n.isDown ? AppColors.down : AppColors.green);
    final ring = n.cropCode == null ? AppColors.line : tone.withValues(alpha: .55);
    final hasPrice = n.price != null && n.cropCode != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // 왼쪽 둥근 그림 (시세 소식은 작물 그림, 나머지는 이모지)
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white, tone.withValues(alpha: n.cropCode == null ? .10 : .16)]),
            border: Border.all(color: ring, width: 2.4),
          ),
          child: n.cropCode != null ? CropArt(code: n.cropCode!, size: 42) : Text(n.emoji, style: const TextStyle(fontSize: 28, height: 1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KoText(n.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF000000), height: 1.25)),
            const SizedBox(height: 5),
            if (hasPrice)
              Row(children: [
                Flexible(child: Text('${krw(n.price!)}/kg', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF111111)))),
                if (n.tag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: tone.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                    child: Text(n.tag!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: tone)),
                  ),
                ],
              ])
            else
              const SizedBox.shrink(),
            if (hasPrice) const SizedBox(height: 4),
            KoText(n.body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF222222), height: 1.4, fontWeight: FontWeight.w500)),
            if (n.time != null) ...[
              const SizedBox(height: 3),
              Text('${n.category} · ${n.time!.month}/${n.time!.day}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF55655A), fontWeight: FontWeight.w700)),
            ] else ...[
              const SizedBox(height: 3),
              Text(n.category, style: const TextStyle(fontSize: 11.5, color: AppColors.greenDark, fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
        // 오른쪽 등락률 (▲ 빨강 / ▼ 파랑)
        if (n.cropCode != null && n.percent != null) ...[
          const SizedBox(width: 8),
          _Change(percent: n.percent!),
        ],
        if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Color(0xFF55655A), size: 24),
      ]),
          ),
        ),
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final flat = percent.abs() < 0.05;
    final up = percent > 0;
    final color = flat ? const Color(0xFF55655A) : (up ? AppColors.up : AppColors.down);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(flat ? '–' : (up ? '▲' : '▼'), style: TextStyle(color: color, fontSize: 13, height: 1)),
      const SizedBox(height: 3),
      Text('${percent.abs().toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15.5)),
    ]);
  }
}
