import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/korean.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../services/weather_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/greenhouse_art.dart';
import '../widgets/farm_life.dart';
import '../widgets/pond_fish.dart';
import 'about_page.dart';
import 'ai_assistant_page.dart';
import 'achievement_page.dart';
import 'crop_growth_page.dart';
import 'encyclopedia_page.dart';
import 'fund_page.dart';
import 'match_game_page.dart';
import 'mission_page.dart';
import 'news_page.dart';
import 'point_shop_page.dart';
import 'trade_history_page.dart';
import '../widgets/weather_icon.dart';
import 'profile_sheet.dart';

export '../widgets/greenhouse_art.dart' show GreenhousePainter, greenhouseTier;

/// 농장 탭 (홈): 프로필·자금·날씨, 밭이 있는 농장 풍경, 바로가기
class FarmPage extends ConsumerWidget {
  const FarmPage({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// 농장의 하우스를 누르면: 하우스 모양·채 수·성장 시간 단축 효과를 보여 주고 바로 더 지을 수 있다.
  void _showGreenhouseSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.bg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _GreenhouseSheet(),
      );

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
      ('⭐', '특별 상점', () => _push(context, const PointShopPage()), null),
      ('🧾', '거래 기록', () => _push(context, const TradeHistoryPage()), null),
      ('🤖', 'AI 도우미', () => _push(context, const AiAssistantPage()), null),
    ];

    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(builder: (context, box) {
      // 시안처럼 첫 화면에는 농장 화면(프로필·날씨 → 농장 그림)만 하단 탭 위까지 꽉 차게 보이고,
      // 작물 관리·바로가기는 아래로 스크롤해야 나온다.
      final heroH = box.maxHeight.isFinite && box.maxHeight > 560 ? box.maxHeight : 560.0;
      // 안드로이드 12+의 '늘어나는' 당김 효과 때문에 맨 위에서 당기면 농장 그림이 늘어나 보여서 끈다.
      // (스크롤은 그대로 되고, 아래로 내리면 작물 관리·바로가기가 나온다)
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: ListView(padding: EdgeInsets.zero, physics: const ClampingScrollPhysics(), children: [
        SizedBox(
          height: heroH,
          child: _FarmHero(
            topInset: topInset,
            header: Column(mainAxisSize: MainAxisSize.min, children: [
              // 시안: 노란 원 안의 농부 아바타 · 닉네임 · Lv · 금화 알약 · 톱니바퀴
              // 아바타·닉네임·레벨을 누르면 프로필 창(캐릭터 고르기)이 열린다
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showProfileSheet(context),
                    child: Row(children: [
                      FarmerAvatar(size: 60, boy: user.isBoy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(user.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
                          const SizedBox(height: 4),
                          // 아랫줄: 레벨·칭호(자리가 모자라면 글자가 줄어 끝까지 보인다) 와 포인트 알약이 같은 높이에 나란히
                          Row(children: [
                            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Lv. ${lv.level}  ·  ${farmerTitles[user.titleIndex].emoji} ${farmerTitles[user.titleIndex].name}', maxLines: 1, style: const TextStyle(fontSize: 14, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)))),
                            const SizedBox(width: 10), // 칭호와 포인트 사이 간격 (알약이 칭호 바로 옆에 붙는다)
                            MoneyPill(money: user.money),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
                // 톱니바퀴: 오른쪽 위 구름에 겹치지 않게 아랫줄(레벨·포인트) 높이로 내려 두었다
                Padding(
                  padding: const EdgeInsets.only(top: 26, left: 4),
                  child: IconButton(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 40, height: 36), onPressed: () => _push(context, const AboutPage()), icon: const Icon(Icons.settings_outlined, color: AppColors.ink, size: 28)),
                ),
              ]),
              const SizedBox(height: 10),
              _WeatherCard(weather: ref.watch(weatherProvider)),
            ]),
            // 그림 속 밭을 누르면 작물 관리(심기·물주기·수확)로 간다
            onField: () => _push(context, const CropGrowthPage()),
            decor: user.decor,
            greenhouses: user.greenhouses,
            level: lv.level,
            onGreenhouse: () => _showGreenhouseSheet(context),
            fishActive: ref.watch(shellIndexProvider) == 1,
            plots: ref.watch(plotsProvider).valueOrNull ?? const <Plot>[],
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
      ]),
      );
    });
  }
}

/// 시안의 농장 화면: 하늘 위 프로필·날씨 → 하단 탭 위까지 이어지는 농장 일러스트 전체(집·연못·밭).
/// 그림은 시안처럼 아무것도 올리지 않고 그대로 보여 주고, 그림 속 밭을 누르면 작물 관리 화면으로 간다.
class _FarmHero extends StatelessWidget {
  const _FarmHero({required this.topInset, required this.header, required this.onField, required this.decor, required this.greenhouses, required this.level, required this.onGreenhouse, required this.fishActive, required this.plots});
  final double topInset;
  final Widget header;
  final VoidCallback onField;
  final int decor;

  /// 상점에서 하우스를 지었으면 농장에 유리 온실이 나타난다
  final int greenhouses;

  /// 농부 레벨 (레벨이 오를수록 농장 집이 조금씩 커진다)
  final int level;

  /// 농장의 하우스를 눌렀을 때 (하우스 정보·더 짓기 창을 연다)
  final VoidCallback onGreenhouse;

  /// 농장 탭을 보고 있는지 (아니면 물고기 움직임을 멈춰 배터리·메모리를 아낀다)
  final bool fishActive;

  /// 내 밭들 (작물이 심어진 밭의 작물이 농장 그림 속 흙 위에서 흔들린다)
  final List<Plot> plots;

  /// 하우스를 올려 놓을 자리 (그림 원본 픽셀: 집 왼쪽 앞 풀밭, 크게).
  /// 아래 끝(566)이 갈색 밭이 시작되는 높이(약 590)보다 위라서 밭과 겹치지 않는다.
  static const _house = Rect.fromLTWH(2, 402, 238, 162);

  // 그림(farm_scene.jpg) 좌표 기준 크기 (실제 파일은 2배 고해상도 1872×1428)
  static const _srcW = 936.0, _srcH = 714.0;

  /// 그림 속 집을 키우는 배율 (집만)
  static const houseScale = 1.08;

  /// 그림 확대 한도. 원본이 작아서 이보다 키우면 깨져 보인다.
  static const maxScale = 1.4; // 그림 확대 한도. 더 키우면 원본의 네모 얼룩이 커져 집이 깨져 보인다

  /// 그림 맨 위에서 잘라 내는 비율 (옅은 안개색 부분)
  static const _cropTop = .15;

  /// 프로필·날씨 카드 아래 끝 (그림은 이보다 36px 위에서 시작해 하늘과 겹친다)
  static double _headerBottom(double topInset) => topInset + 150;

  /// 하우스 그림 자리: 기본 자리(_house)의 왼쪽 아래를 고정하고 [scale]배로 키운다. 화면 왼쪽 밖으로 나가지 않게 한다.
  Rect _houseRect(double imgLeft, double imgTop, double k, double scale) {
    final w = _house.width * k * scale, h = _house.height * k * scale;
    final left = math.max(10.0, imgLeft + _house.left * k);
    final bottom = imgTop + _house.bottom * k;
    return Rect.fromLTWH(left, bottom - h, w, h);
  }

  /// 그림 속 연못 물(파란 부분)이 있는 자리 (원본 픽셀)
  static const _pond = Rect.fromLTRB(668, 448, 826, 520);

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
        // 그림 윗부분 10%는 옅은 안개·흐린 하늘색이라 잘라 낸다 (그 아래부터는 또렷한 산과 나무). 하늘은 이 높이에서 그림 속 하늘색으로 이어진다.
        final cropPx = imgH * _cropTop;
        final seam = imgTop + cropPx;

        final stage = greenhouseStage(level, greenhouses);
        final field = Rect.fromLTRB(imgLeft + _field.left * k, imgTop + _field.top * k, imgLeft + _field.right * k, imgTop + _field.bottom * k);

        return Stack(clipBehavior: Clip.hardEdge, children: [
          // 하늘: 맨 위는 맑은 하늘색, 그림 쪽으로 내려오면 그림 맨 윗줄(아주 옅은 하늘·구름색)과 같은 색으로 이어진다
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0xFF58B6EE), Color(0xFF78D0F8), Color(0xFF86D6F4), Color(0xFF86D6F4)],
                  stops: [0, ((seam / h) * .55).clamp(0.0, 1.0).toDouble(), (seam / h).clamp(0.0, 1.0).toDouble(), 1],
                ),
              ),
            ),
          ),
          Positioned(left: -20, top: topInset + 58, child: const _Cloud(width: 130)),
          // 오른쪽 위 구름: 톱니바퀴와 겹치지 않게 위로 올려 두었다
          Positioned(right: -10, top: topInset - 26, child: const _Cloud(width: 110)),
          Positioned(right: 60, top: topInset + 125, child: const _Cloud(width: 84)),
          // 날씨 카드와 그림 사이 하늘이 넓을 때 채워 주는 구름
          if (imgTop - (topInset + 150) > 70) ...[
            Positioned(left: 24, top: topInset + 170, child: const _Cloud(width: 92)),
            Positioned(right: 18, top: (topInset + 150 + imgTop) / 2 - 10, child: const _Cloud(width: 120)),
          ],
          // 농장 일러스트: 윗부분 10%만 잘라 내고 나머지는 흐림·번짐 효과 없이 그대로 또렷하게 보여 준다
          Positioned(
            left: imgLeft,
            top: imgTop,
            width: imgW,
            height: imgH,
            child: ClipRect(
              clipper: _TopCropClipper(cropPx),
              child: Image.asset(AppImages.farmScene, width: imgW, height: imgH, fit: BoxFit.fill, filterQuality: FilterQuality.high),
            ),
          ),
          // 하늘과 그림이 만나는 곳의 숲 가장자리: 잘린 나무 윗부분을 둥근 덤불 선으로 자연스럽게 마무리한다 (그림 아님, 코드로 그린 또렷한 도형)
          if (seam > 12)
            Positioned(left: 0, right: 0, top: seam - 14, height: math.max(40.0, imgH * .12), child: const IgnorePointer(child: CustomPaint(painter: _TreeLinePainter()))),
          // 연못에서 헤엄치는 물고기 (농장 탭을 보고 있을 때만 움직인다)
          Positioned.fromRect(
            rect: Rect.fromLTRB(imgLeft + _pond.left * k, imgTop + _pond.top * k, imgLeft + _pond.right * k, imgTop + _pond.bottom * k),
            child: IgnorePointer(child: PondFish(active: fishActive)),
          ),
          // 그림 윗가장자리를 가리는 구름 띠: 나무가 잘린 가장자리가 딱 끊겨 보이지 않고 하늘과 자연스럽게 이어져 보인다
          // 레벨이 오를수록 집이 조금씩 커진다 (최대 8%, 그림 속 집 둘레만 부드럽게 겹쳐 그린다)
          // (예전에는 레벨이 오르면 그림 속 집을 늘려 한 번 더 겹쳐 그렸는데, 늘린 가장자리가 흐릿하게 번져서 화질이 깨져 보여 뺐다. 하우스는 코드로 그려서 계속 커진다)
          // 그림 속 집만 조금 더 크게 (집 바닥 가운데를 기준으로 커지고, 집 둘레는 서서히 투명해져 풀밭·나무와 이어진다). 집 외의 부분은 그대로.
          Positioned(
            left: imgLeft,
            top: imgTop,
            width: imgW,
            height: imgH,
            child: IgnorePointer(child: ClipRect(clipper: _TopCropClipper(cropPx), child: const GrowingHouseLayer(scale: _FarmHero.houseScale))),
          ),
          // 농장에서 움직이는 것들: 밭에서 흔들리는 작물 + 길을 순찰하며 물을 주는 최첨단 로봇 (농장 탭을 볼 때만 움직인다)
          Positioned(
            left: imgLeft,
            top: imgTop,
            width: imgW,
            height: imgH,
            child: FarmLife(k: k, active: fishActive, plots: plots, robot: greenhouses == 0),
          ),
          // 프로필·날씨
          Positioned(left: 16, right: 6, top: topInset + 2, child: header),
          // 그림 속 밭: 눌러서 작물 관리로 (화면에는 아무것도 덧그리지 않는다)
          Positioned.fromRect(
            rect: field,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onField),
          ),
          // 상점에서 지은 하우스: 코드로 그린 유리 온실 (그림이 아니라 확대해도 선명하다)
          if (greenhouses > 0)
            Positioned.fromRect(
              // 하우스를 지을 때마다 조금씩 커진다 (왼쪽 아래 모서리를 기준으로 위·오른쪽으로 커짐)
              rect: _houseRect(imgLeft, imgTop, k, greenhouseSizeScale(stage)),
              // 누르면 하우스 정보와 "더 짓기" 창이 열린다
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onGreenhouse, child: GreenhouseView(count: greenhouses, tier: greenhouseTierOfStage(stage), name: greenhouseStageName(stage), stage: stage, active: fishActive)),
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

/// 그림 맨 위 [top]만큼을 잘라 내는 자르기 영역
class _TopCropClipper extends CustomClipper<Rect> {
  const _TopCropClipper(this.top);
  final double top;
  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top, size.width, size.height);
  @override
  bool shouldReclip(_TopCropClipper old) => old.top != top;
}

/// 하늘과 농장 그림 사이의 숲 가장자리: 그림 속 나무와 같은 청록·초록으로 둥근 덤불을 이어 붙인 또렷한 선.
/// 그림 윗부분을 잘라 낸 자리를 가려서 하늘과 그림이 띠 없이 이어져 보이게 한다 (흐림 효과 없음).
class _TreeLinePainter extends CustomPainter {
  const _TreeLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 뒤줄(진한 청록) → 앞줄(초록): 반지름과 높이를 다르게 해서 들쭉날쭉한 숲 선이 된다
    void row(double baseY, double rMin, double rMax, int seed, List<Color> colors) {
      var x = -rMax * .6;
      var i = seed;
      while (x < w + rMax) {
        final r = rMin + (rMax - rMin) * (((i * 37) % 100) / 100);
        final c = Offset(x + r, baseY - r * .55 + (((i * 53) % 7) - 3));
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawCircle(c, r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect));
        x += r * 1.35;
        i++;
      }
    }

    row(h * .5, h * .22, h * .36, 3, const [Color(0xFF6CC9B4), Color(0xFF3FA88F)]);
    row(h * .72, h * .2, h * .34, 7, const [Color(0xFF3FB29A), Color(0xFF2A9488)]);
    row(h * .96, h * .2, h * .32, 11, const [Color(0xFF5CBF6E), Color(0xFF2F9A5A)]);
    // 맨 아래는 그림과 이어지는 초록 띠
    canvas.drawRect(Rect.fromLTWH(0, h * .9, w, h * .1), Paint()..color = const Color(0xFF3FA45E));
  }

  @override
  bool shouldRepaint(_TreeLinePainter old) => false;
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
      color: Colors.white.withValues(alpha: .97),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        // 날씨 그림은 이모티콘 글자가 아니라 코드로 그린 벡터 (기기 글꼴과 상관없이 맑음은 노란 해로 또렷하게 나온다)
        WeatherIcon(label: w?.label ?? '대체로 맑음', size: 46),
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

/// 농부 레벨에 따른 집 크기 배율: Lv.1은 그대로, 레벨이 오를 때마다 0.8%씩 커져 Lv.11부터는 1.08배(최대).
double houseScaleFor(int level) => 1 + 0.008 * (level - 1).clamp(0, 10);

/// 농장 그림 속 집만 [scale]배로 키워서 같은 그림 위에 겹쳐 그린다. 집 바닥 가운데를 기준으로 커지고,
/// 집 둘레는 서서히 투명해져서 풀밭·나무와 자연스럽게 이어진다.
class GrowingHouseLayer extends StatelessWidget {
  const GrowingHouseLayer({super.key, required this.scale});
  final double scale;

  // 그림 원본(936×714) 좌표: 집 가운데와 집 바닥 가운데
  static const _center = Offset(390, 262);
  static const _base = Offset(400, 128); // 지붕 쪽을 기준으로 키워서 집이 위로 커져 지붕이 잘리지 않고 아래·옆으로 커진다

  @override
  Widget build(BuildContext context) {
    Alignment at(Offset o) => Alignment(o.dx / 936 * 2 - 1, o.dy / 714 * 2 - 1);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => RadialGradient(
        center: at(_center),
        radius: .46,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: const [0, .68, 1],
      ).createShader(r),
      child: Transform.scale(
        scale: scale,
        alignment: at(_base),
        child: Image.asset(AppImages.farmScene, fit: BoxFit.fill, filterQuality: FilterQuality.high),
      ),
    );
  }
}

/// 하우스 정보 창: 지금 모양(레벨에 따라 바뀜), 지은 채 수, 성장 시간 단축 효과, 더 짓기 버튼.
/// 지으면 이 창의 숫자도 바로 바뀐다.
class _GreenhouseSheet extends ConsumerWidget {
  const _GreenhouseSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final level = user.level.level;
    final owned = user.greenhouses;
    final stage = greenhouseStage(level, owned);
    final tier = greenhouseTierOfStage(stage);
    final cost = greenhouseCostFor(owned);
    final cut = (100 - greenhouseFactor(owned) * 100).round();
    final nextCut = (100 - greenhouseFactor(owned + 1) * 100).round();
    // 하우스를 한 채 더 지으면 한 단계 커지고 이름이 바뀐다
    final nextName = greenhouseStageName(stage + 1);
    final scale = greenhouseSizeScale(stage);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 14),
          SizedBox(height: 150 * (0.8 + 0.2 * scale), child: AspectRatio(aspectRatio: 260 / 176, child: GreenhouseView(count: owned, tier: tier, name: greenhouseStageName(stage), stage: stage))),
          const SizedBox(height: 10),
          Text(greenhouseStageName(stage), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 4),
          KoText('하우스를 한 채 더 지으면 커지면서 ${withJosa(nextName, '으로', '로')} 바뀌어요', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SoftCard(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: [
              _line('지은 하우스', '$owned채'),
              const Divider(height: 16, color: AppColors.line),
              _line('성장 시간 단축', '$cut%'),
              const Divider(height: 16, color: AppColors.line),
              _line('한 채 더 지으면', '$nextCut% 단축'),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('지으면 지금 자라는 작물에도 바로 적용돼요', style: TextStyle(fontSize: 12.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          GreenButton(
            label: '하우스 더 짓기 ${won(cost)}',
            icon: const CoinIcon(size: 20),
            onPressed: user.money < cost ? null : () => runGuarded(context, ref.read(farmViewModelProvider).buyGreenhouse, ok: '하우스를 지었어요 🏠'),
          ),
          if (user.money < cost)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('포인트가 부족합니다', style: TextStyle(fontSize: 12.5, color: AppColors.sub))),
        ]),
      ),
    );
  }

  Widget _line(String a, String b) => Row(children: [
        Text(a, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF3D4A40))),
        const Spacer(),
        Text(b, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink)),
      ]);
}

