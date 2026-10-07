import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../services/weather_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/farm_scene.dart';
import 'about_page.dart';
import 'achievement_page.dart';
import 'crop_growth_page.dart';
import 'encyclopedia_page.dart';
import 'farm_actions.dart';
import 'fund_page.dart';
import 'match_game_page.dart';
import 'mission_page.dart';
import 'news_page.dart';
import 'point_shop_page.dart';
import 'trade_history_page.dart';

/// 농장 탭 (홈): 프로필·자금·날씨, 밭이 있는 농장 풍경, 바로가기
class FarmPage extends ConsumerWidget {
  const FarmPage({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _onPlot(BuildContext context, WidgetRef ref, Plot p, DateTime now) {
    if (p.isEmpty) {
      showPlantSheet(context, ref, p);
    } else if (p.isReady(now)) {
      harvestPlot(context, ref, p);
    } else {
      _push(context, CropGrowthPage(initialPlot: p.index));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final plots = ref.watch(plotsProvider);
    final now = ref.watch(tickProvider).valueOrNull ?? DateTime.now();
    final tag = dayTag(now);
    final dailyDone = dailyMissions.where((m) => periodCount(user.daily, tag, m.key) >= m.target).length;
    final lv = user.level;

    final shortcuts = <(String, String, VoidCallback, String?)>[
      ('📋', '미션', () => _push(context, const MissionPage()), '$dailyDone/${dailyMissions.length}'),
      ('🧩', '작물 매칭', () => _push(context, const MatchGamePage()), null),
      ('📖', '작물 도감', () => _push(context, const EncyclopediaPage()), null),
      ('📰', '농부 뉴스', () => _push(context, const NewsPage()), null),
      ('🏡', '마을 기금', () => _push(context, const FundPage()), null),
      ('🏆', '업적', () => _push(context, const AchievementPage()), null),
      ('⭐', '포인트 상점', () => _push(context, const PointShopPage()), null),
      ('🧾', '거래 기록', () => _push(context, const TradeHistoryPage()), null),
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.line, width: 2)),
          child: const Text('👩‍🌾', style: TextStyle(fontSize: 26, height: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
              const SizedBox(width: 6),
              Text('Lv.${lv.level}', style: const TextStyle(fontSize: 12, color: AppColors.greenDark, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            SizedBox(width: 90, child: ThinBar(value: lv.ratio, height: 6)),
          ]),
        ),
        MoneyPill(money: user.money),
        IconButton(onPressed: () => _push(context, const AboutPage()), icon: const Icon(Icons.settings_rounded, color: AppColors.ink)),
      ]),
      const SizedBox(height: 10),
      _WeatherCard(weather: ref.watch(weatherProvider)),
      const SizedBox(height: 12),
      plots.when(
        loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SoftCard(child: Text('밭을 불러오지 못했어요\n${errMsg(e)}')),
        data: (list) => FarmYard(plots: list, now: now, decor: user.decor, onTapPlot: (p) => _onPlot(context, ref, p, now)),
      ),
      const SizedBox(height: 12),
      GreenButton(label: '작물 관리', icon: const Icon(Icons.eco_rounded, size: 20), onPressed: () => _push(context, const CropGrowthPage())),
      const SectionTitle('바로가기'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .86,
        children: [
          for (final s in shortcuts)
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              onTap: s.$3,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(s.$1, style: const TextStyle(fontSize: 26, height: 1.1)),
                const SizedBox(height: 4),
                Text(s.$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                if (s.$4 != null) Text(s.$4!, style: const TextStyle(fontSize: 10, color: AppColors.greenDark, fontWeight: FontWeight.w800)),
              ]),
            ),
        ],
      ),
    ]);
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});
  final AsyncValue<Weather?> weather;

  static String _tip(String label) {
    if (label.contains('비') || label.contains('소나기') || label.contains('이슬비') || label.contains('뇌우')) return '우산 챙기고\n농장 둘러봐요!';
    if (label.contains('눈')) return '따뜻하게 입고\n농장에 가요!';
    if (label.contains('맑')) return '농장 나들이\n하기 좋은 날이에요!';
    return '선선한 날,\n농장을 살펴봐요!';
  }

  @override
  Widget build(BuildContext context) {
    final w = weather.valueOrNull;
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Text(w?.emoji ?? '🌤️', style: const TextStyle(fontSize: 34, height: 1)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('오늘의 날씨', style: TextStyle(fontSize: 11, color: AppColors.sub)),
            Text(w == null ? (weather.isLoading ? '불러오는 중…' : '날씨를 불러오지 못했어요') : '${w.label} ${w.tempC.round()}°C',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
        if (w != null) Text(_tip(w.label), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.sub, height: 1.3)),
      ]),
    );
  }
}
