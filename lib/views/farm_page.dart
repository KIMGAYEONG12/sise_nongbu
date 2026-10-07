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

    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(builder: (context, box) {
      // 첫 화면 한 장(시안의 농장 화면)을 꽉 채우고, 그 아래로 작물 관리·바로가기가 이어진다.
      final heroH = box.maxHeight.isFinite && box.maxHeight > 640 ? box.maxHeight : 640.0;
      return ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: heroH,
          child: _FarmHero(
            topInset: topInset,
            header: Column(mainAxisSize: MainAxisSize.min, children: [
              // 시안: 노란 원 안의 농부 아바타 · 닉네임 · Lv · 금화 알약 · 톱니바퀴
              Row(children: [
                const FarmerAvatar(size: 60),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
                    const SizedBox(height: 3),
                    Text('Lv.${lv.level}', style: const TextStyle(fontSize: 14, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    SizedBox(width: 84, child: ThinBar(value: lv.ratio, height: 5, track: Colors.white70)),
                  ]),
                ),
                MoneyPill(money: user.money),
                IconButton(onPressed: () => _push(context, const AboutPage()), icon: const Icon(Icons.settings_outlined, color: AppColors.ink, size: 28)),
              ]),
              const SizedBox(height: 10),
              _WeatherCard(weather: ref.watch(weatherProvider)),
            ]),
            board: plots.when(
              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SoftCard(child: Text('밭을 불러오지 못했어요\n${errMsg(e)}')),
              data: (list) => SoilBoard(plots: list, now: now, maxTile: 64, grass: true, onTap: (p) => _onPlot(context, ref, p, now)),
            ),
            decor: user.decor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          ]),
        ),
      ]);
    });
  }
}

/// 시안의 농장 화면 한 장: 하늘(프로필·날씨) → 집이 있는 농장 일러스트(가리지 않고 전부 보이게) → 아래 들판의 밭 판
class _FarmHero extends StatelessWidget {
  const _FarmHero({required this.topInset, required this.header, required this.board, required this.decor});
  final double topInset;
  final Widget header;
  final Widget board;
  final int decor;

  static const _imgAspect = 936 / 714;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final imgH = w / _imgAspect;
        // 일러스트 위치: 날씨 카드 바로 아래쪽이 일러스트 윗부분과 살짝 겹치게 (시안과 같은 배치)
        final imgTop = topInset + 150;
        return Stack(children: [
          // 하늘
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: imgTop + 40,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7CCDF4), Color(0xFFB4E6F7), Color(0xFFCDF0F6)]),
              ),
            ),
          ),
          Positioned(left: -20, top: topInset + 58, child: const _Cloud(width: 130)),
          Positioned(right: -10, top: topInset + 8, child: const _Cloud(width: 110)),
          Positioned(right: 70, top: topInset + 120, child: const _Cloud(width: 80)),
          // 들판 (일러스트 아래쪽 색을 이어 받는다)
          Positioned(
            left: 0,
            right: 0,
            top: imgTop + imgH - 30,
            bottom: 0,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8DA94A), Color(0xFF8FC25A), Color(0xFFB5DC86)]),
              ),
            ),
          ),
          // 농장 일러스트 (위·아래 가장자리는 하늘·들판에 자연스럽게 녹아들게)
          Positioned(
            left: 0,
            right: 0,
            top: imgTop,
            height: imgH,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                stops: [0, .07, .9, 1],
              ).createShader(r),
              child: Image.asset(AppImages.farmScene, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
          ),
          if (decor > 0)
            Positioned(left: 14, top: imgTop + imgH - 44, child: Text('🌻' * decor, style: const TextStyle(fontSize: 22, height: 1))),
          // 프로필·날씨
          Positioned(left: 16, right: 6, top: topInset + 8, child: header),
          // 밭 판: 일러스트 아래 들판에 놓는다. 화면이 짧으면 일러스트 맨 아래(그림 속 밭 자리)와만 겹친다.
          Positioned(left: w * .1, right: w * .1, bottom: 16, child: board),
        ]);
      });
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) {
    final h = width * .42;
    Widget puff(double l, double t, double d) => Positioned(
          left: l,
          top: t,
          child: Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .92))),
        );
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(children: [
          puff(width * .08, h * .35, h * .6),
          puff(width * .28, h * .05, h * .85),
          puff(width * .55, h * .22, h * .7),
          Positioned(
            left: width * .05,
            right: width * .05,
            bottom: 0,
            height: h * .4,
            child: Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(h))),
          ),
        ]),
      ),
    );
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
      color: Colors.white.withValues(alpha: .92),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Text(w?.emoji ?? '🌤️', style: const TextStyle(fontSize: 40, height: 1)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('오늘의 날씨', style: TextStyle(fontSize: 12, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(w == null ? (weather.isLoading ? '불러오는 중…' : '날씨를 불러오지 못했어요') : '${w.label}  ${w.tempC.round()}°C',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
          ]),
        ),
        if (w != null) Text(_tip(w.label), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5A4E), height: 1.35)),
      ]),
    );
  }
}
