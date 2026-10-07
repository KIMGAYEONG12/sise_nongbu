import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../services/weather_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'about_page.dart';
import 'achievement_page.dart';
import 'crop_growth_page.dart';
import 'encyclopedia_page.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
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
      // 시안처럼 첫 화면에는 농장 화면(프로필·날씨 → 농장 그림)만 하단 탭 위까지 꽉 차게 보이고,
      // 작물 관리·바로가기는 아래로 스크롤해야 나온다.
      final heroH = box.maxHeight.isFinite && box.maxHeight > 560 ? box.maxHeight : 560.0;
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
                    Text('Lv. ${lv.level}', style: const TextStyle(fontSize: 14, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)),
                  ]),
                ),
                MoneyPill(money: user.money),
                IconButton(onPressed: () => _push(context, const AboutPage()), icon: const Icon(Icons.settings_outlined, color: AppColors.ink, size: 28)),
              ]),
              const SizedBox(height: 10),
              _WeatherCard(weather: ref.watch(weatherProvider)),
            ]),
            // 그림 속 밭을 누르면 작물 관리(심기·물주기·수확)로 간다
            onField: () => _push(context, const CropGrowthPage()),
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

/// 시안의 농장 화면: 하늘 위 프로필·날씨 → 하단 탭 위까지 이어지는 농장 일러스트 전체(집·연못·밭).
/// 그림은 시안처럼 아무것도 올리지 않고 그대로 보여 주고, 그림 속 밭을 누르면 작물 관리 화면으로 간다.
class _FarmHero extends StatelessWidget {
  const _FarmHero({required this.topInset, required this.header, required this.onField, required this.decor});
  final double topInset;
  final Widget header;
  final VoidCallback onField;
  final int decor;

  // 그림(farm_scene.jpg) 좌표 기준 크기 (실제 파일은 2배 고해상도 1872×1428)
  static const _srcW = 936.0, _srcH = 714.0;

  /// 그림 확대 한도. 원본이 작아서 이보다 키우면 깨져 보인다.
  static const maxScale = 1.4;

  /// 프로필·날씨 카드 아래 끝 (그림은 이보다 36px 위에서 시작해 하늘과 겹친다)
  static double _headerBottom(double topInset) => topInset + 150;

  /// 그림 속 밭(갈색 흙)이 그려진 자리 (원본 픽셀 좌표: 왼쪽, 위, 오른쪽, 아래)
  static const _field = Rect.fromLTRB(280, 560, 680, 714);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        // 화면 폭에 맞춘 뒤 조금만(최대 1.4배) 키운다. 넘치는 양옆은 똑같이 잘라 집과 연못이 다 보이게.
        // 그림 아래 끝은 하단 탭 바로 위에 붙이고, 날씨 카드와 그림 사이는 하늘·구름으로 이어진다.
        final baseH = w * _srcH / _srcW;
        final headerBottom = _headerBottom(topInset);
        final scale = ((h - headerBottom + 36) / baseH).clamp(1.0, maxScale).toDouble();
        final imgW = w * scale, imgH = baseH * scale;
        final imgTop = h - imgH; // 그림 아래 끝 = 하단 탭 바로 위
        final imgLeft = -(imgW - w) / 2;
        final k = imgW / _srcW; // 원본 1px → 화면 크기

        final field = Rect.fromLTRB(imgLeft + _field.left * k, imgTop + _field.top * k, imgLeft + _field.right * k, imgTop + _field.bottom * k);

        return Stack(clipBehavior: Clip.hardEdge, children: [
          // 하늘 (그림 윗부분 색으로 이어진다)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF79CBF3), Color(0xFFB1E5F6), Color(0xFFD3F0F4)], stops: [0, .45, 1]),
              ),
            ),
          ),
          Positioned(left: -20, top: topInset + 58, child: const _Cloud(width: 130)),
          Positioned(right: -10, top: topInset + 8, child: const _Cloud(width: 110)),
          Positioned(right: 60, top: topInset + 125, child: const _Cloud(width: 84)),
          // 날씨 카드와 그림 사이 하늘이 넓을 때 채워 주는 구름
          if (imgTop - (topInset + 150) > 70) ...[
            Positioned(left: 24, top: topInset + 170, child: const _Cloud(width: 92)),
            Positioned(right: 18, top: (topInset + 150 + imgTop) / 2 - 10, child: const _Cloud(width: 120)),
          ],
          // 농장 일러스트: 원본에 가까운 크기로 선명하게, 윗가장자리만 하늘에 녹아들게
          Positioned(
            left: imgLeft,
            top: imgTop,
            width: imgW,
            height: imgH,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white],
                stops: [0, .12],
              ).createShader(r),
              child: Image.asset(AppImages.farmScene, fit: BoxFit.fill, filterQuality: FilterQuality.high),
            ),
          ),
          // 프로필·날씨
          Positioned(left: 16, right: 6, top: topInset + 8, child: header),
          // 그림 속 밭: 눌러서 작물 관리로 (화면에는 아무것도 덧그리지 않는다)
          Positioned.fromRect(
            rect: field,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onField),
          ),
          // 포인트 상점에서 산 농장 장식(해바라기)은 밭 왼쪽 위에 작게
          if (decor > 0)
            Positioned(
              left: (field.left - 6).clamp(4.0, w).toDouble(),
              top: field.top - 6,
              child: IgnorePointer(child: Text('🌻' * decor, style: const TextStyle(fontSize: 16, height: 1))),
            ),
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
    if (label.contains('맑')) return '작물 성장에\n좋은 날씨예요!';
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
