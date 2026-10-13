// 2차 수정 확인: 한국 시간 기준 하루, 칭호 장착, 수확 경험치, 전체 받기(위), 뉴스 눌러서 이동, 매칭 첫 힌트,
// 움직이는 하우스·위성, 통계 창 넘침, API 요청 속도 제한 (Firebase 없이 가짜 데이터로).
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/auction_api_service.dart';
import 'package:sise_nongbu/services/auth_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/harvest_result_page.dart';
import 'package:sise_nongbu/views/match_game_page.dart';
import 'package:sise_nongbu/views/mission_page.dart';
import 'package:sise_nongbu/views/my_page.dart';
import 'package:sise_nongbu/views/news_page.dart';
import 'package:sise_nongbu/widgets/common.dart';
import 'package:sise_nongbu/widgets/greenhouse_art.dart';
import 'package:sise_nongbu/widgets/level_up_art.dart';

final _day = DateTime(2026, 10, 12, 12);

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => {
        'CABBAGE': AuctionPrice('CABBAGE', 1850, _day, prevPerKg: 1646),
        'FIG': AuctionPrice('FIG', 7200, _day, prevPerKg: 7000),
      };
}

/// 서버 없이 기록만 하는 가짜 농장 뷰모델
class _FakeVm extends FarmViewModel {
  _FakeVm(super.ref);
  static final claimed = <String>[];
  static final titles = <int?>[];
  @override
  Future<void> claimMission(MissionDef d) async => claimed.add(d.id);
  @override
  Future<void> setTitle(int? index) async => titles.add(index);
}

class _FakeAuth implements AuthService {
  @override
  bool get isGuest => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _screen(WidgetTester tester, [Size size = const Size(411, 891)]) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  group('한국 시간 기준 하루', () {
    test('기기 시간대와 상관없이 한국 자정에 하루가 바뀐다', () {
      // UTC 10/11 16:00 = 한국 10/12 01:00
      expect(dayTag(DateTime.utc(2026, 10, 11, 16)), '2026-10-12');
      // UTC 10/12 14:59 = 한국 10/12 23:59 → 아직 12일
      expect(dayTag(DateTime.utc(2026, 10, 12, 14, 59)), '2026-10-12');
      // UTC 10/12 15:00 = 한국 10/13 00:00 → 13일
      expect(dayTag(DateTime.utc(2026, 10, 12, 15)), '2026-10-13');
      expect(toKst(DateTime.utc(2026, 10, 12, 0)).hour, 9);
    });

    test('주간 태그는 한국 월요일 00시에 바뀐다', () {
      expect(weekTag(DateTime.utc(2026, 10, 11, 15)), '2026-10-12'); // 한국 월요일 00:00
      expect(weekTag(DateTime.utc(2026, 10, 11, 14, 59)), '2026-10-05'); // 한국 일요일 23:59
      expect(weekTag(DateTime.utc(2026, 10, 14, 3)), '2026-10-12');
    });

    test('지금 한국 시각은 UTC보다 9시간 빠르다', () {
      final k = kstNow();
      final diff = k.difference(DateTime.now().toUtc());
      expect(diff.inMinutes.abs() - 540, lessThanOrEqualTo(1));
    });
  });

  group('수확 경험치와 칭호 규칙', () {
    test('수확 경험치는 100 이상', () {
      expect(harvestExp, greaterThanOrEqualTo(100));
    });

    test('장착한 칭호는 얻은 것만 쓰고, 아니면 레벨에 맞는 가장 높은 칭호', () {
      expect(effectiveTitleIndex(13, null), farmerTitleIndex(13)); // 농업 명인
      expect(effectiveTitleIndex(13, 1), 1); // 초보 농부를 골랐다
      expect(effectiveTitleIndex(13, 6), farmerTitleIndex(13)); // 전설의 농부(Lv.17)는 아직 못 얻었다
      expect(effectiveTitleIndex(13, -1), farmerTitleIndex(13));
      expect(effectiveTitleIndex(13, 99), farmerTitleIndex(13));
      expect(effectiveTitleIndex(99, 6), 6);
    });

    test('칭호 단계와 다음 칭호까지 진행률', () {
      expect(titleRankOf(13, 5), 1); // 농업 명인은 Lv.13부터 → Lv.13은 1단계 (MY 화면의 "1단계")
      expect(titleRankOf(14, 5), 2);
      expect(titleRankOf(13, 1), 11); // 초보 농부(Lv.3부터)를 달고 있으면 11단계
      final lv = levelInfo(9100); // Lv.13
      expect(lv.level, 13);
      // 농업 명인(Lv.13) → 전설의 농부(Lv.17): 4레벨 구간에서 경험치 막대만큼
      expect(titleProgress(lv), closeTo(lv.ratio / 4, 1e-9));
      expect(titleProgress(levelInfo(9100 + 100 * 14 + 100 * 15)), greaterThan(titleProgress(lv))); // 레벨이 오르면 진행률도 오른다
      expect(titleProgress(levelInfo(999999)), 1.0); // 마지막 칭호
      expect(titleProgress(levelInfo(0)), closeTo(0.0, 1e-9));
    });
  });

  group('칭호 고르기 (MY)', () {
    testWidgets('얻은 칭호를 눌러 장착하고, 못 얻은 칭호는 잠겨 있다', (tester) async {
      _FakeVm.titles.clear();
      await _screen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(const UserData({'exp': 9100, 'nickname': '농부'})),
          farmViewModelProvider.overrideWith(_FakeVm.new),
        ],
        child: const MaterialApp(home: Scaffold(body: TitleSheet())),
      ));
      await tester.pump();
      expect(find.text('나의 칭호'), findsOneWidget);
      expect(find.text('전설의 농부'), findsOneWidget);
      expect(find.textContaining('Lv.17에 열려요'), findsOneWidget); // 잠김
      expect(find.text('농업 명인'), findsOneWidget);
      // 지금은 자동이라 "자동" 버튼은 눌러도 소용없다(비활성)
      expect(find.text('자동으로 쓰는 중 (가장 높은 칭호)'), findsOneWidget);
      await tester.tap(find.text('초보 농부'));
      await tester.pump();
      expect(_FakeVm.titles, [1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MY 화면: 칭호 카드를 누르면 칭호 창이 열린다', (tester) async {
      await _screen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(const UserData({'exp': 9100, 'nickname': '농부', 'titleIdx': 1})),
          authServiceProvider.overrideWithValue(_FakeAuth()),
          isGuestProvider.overrideWith((ref) => Stream.value(false)),
          farmViewModelProvider.overrideWith(_FakeVm.new),
        ],
        child: const MaterialApp(home: Scaffold(body: MyPage())),
      ));
      await tester.pump();
      expect(find.text('초보 농부'), findsOneWidget); // 장착한 칭호가 카드에 나온다
      expect(find.text('장착 중 · 눌러서 칭호 바꾸기'), findsOneWidget);
      await tester.tap(find.text('장착 중 · 눌러서 칭호 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.text('Lv.13 · 레벨이 오르면 더 멋진 칭호가 열려요'), findsOneWidget);
      expect(find.text('자동으로 바꾸기 (가장 높은 칭호)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('농작물 통계 창', () {
    for (final size in const [Size(360, 640), Size(411, 891)]) {
      testWidgets('작물 21종이 있어도 넘치지 않고 끝까지 스크롤된다 ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await _screen(tester, size);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            userDataProvider.overrideWithValue(const UserData({'exp': 100, 'totalProfit': 1519993, 'stats': {'harvest': 77, 'plant': 70, 'sell': 77, 'crop_FIG': 3}})),
          ],
          child: MaterialApp(home: Scaffold(body: Builder(builder: (c) => Center(child: ElevatedButton(onPressed: () => showCropStats(c), child: const Text('열기')))))),
        ));
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(find.text('농작물 통계'), findsOneWidget);
        expect(find.text('1,519,993P'), findsOneWidget);
        expect(tester.takeException(), isNull); // "BOTTOM OVERFLOWED" 오류가 없어야 한다
        await tester.scrollUntilVisible(find.text('브로콜리 수확'), 200, scrollable: find.byType(Scrollable).last);
        expect(find.text('브로콜리 수확'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('미션: 전체 받기가 위에도 있다', () {
    testWidgets('위·아래 전체 받기를 누르면 받을 수 있는 미션을 모두 받는다', (tester) async {
      _FakeVm.claimed.clear();
      await _screen(tester);
      final tag = dayTag(DateTime.now());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(UserData({'exp': 100, 'daily': {'tag': tag, 'water': 3, 'plant': 2, 'harvest': 1}})),
          farmViewModelProvider.overrideWith(_FakeVm.new),
        ],
        child: const MaterialApp(home: MissionPage()),
      ));
      await tester.pump();
      // 물 20 + 파종 20 + 수확 20 = 60P, 3개 → 위·아래 버튼이 같은 문구
      expect(find.text('전체 받기 +60P (3개)'), findsNWidgets(2));
      await tester.tap(find.text('전체 받기 +60P (3개)').first); // 위쪽 버튼
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_FakeVm.claimed, ['d_water', 'd_plant', 'd_harvest']);
      expect(tester.takeException(), isNull);
    });
  });

  group('뉴스를 눌러서 이동', () {
    test('시세 소식은 그 작물 시세 상세로, 게임 소식은 해당 화면으로 연결돼 있다', () {
      final news = buildNews({'CABBAGE': AuctionPrice('CABBAGE', 1850, _day, prevPerKg: 1646)});
      expect(news.firstWhere((n) => n.cropCode == 'CABBAGE').openCrop, 'CABBAGE');
      expect(news.every((n) => n.tappable), isTrue); // 모든 뉴스가 눌러서 갈 곳이 있다
      expect(news.firstWhere((n) => n.title.startsWith('미션')).go, NewsGo.missions);
      expect(news.firstWhere((n) => n.title.startsWith('마을')).go, NewsGo.fund);
      expect(news.firstWhere((n) => n.title.startsWith('작물 매칭')).go, NewsGo.match);
      expect(news.firstWhere((n) => n.title.startsWith('하우스')).go, NewsGo.shop);
      expect(news.firstWhere((n) => n.title.startsWith('특별 보관함')).go, NewsGo.pointShop);
      expect(news.firstWhere((n) => n.title.startsWith('감자')).openCrop, 'POTATO');
    });

    testWidgets('이벤트 소식(미션)을 누르면 미션 화면이 열린다', (tester) async {
      await _screen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new), userDataProvider.overrideWithValue(const UserData({'exp': 100}))],
        child: const MaterialApp(home: NewsPage()),
      ));
      await tester.pump();
      await tester.tap(find.descendant(of: find.byType(PillTabs), matching: find.text('이벤트')));
      await tester.pump();
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets); // 눌러서 갈 수 있다는 표시
      await tester.tap(find.byWidgetPredicate((w) => w is KoText && w.data == '미션을 완료하고 포인트를 받아요'));
      await tester.pumpAndSettle();
      expect(find.text('일일 미션'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('작물 매칭: 노란 힌트는 처음 한 쌍에만', () {
    testWidgets('쉬움: 시작하면 두 칸이 노랗게 나오고, 한 쌍을 맞추면 그 뒤로는 나오지 않는다', (tester) async {
      await _screen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [userDataProvider.overrideWithValue(const UserData({}))],
        child: const MaterialApp(home: MatchGamePage()),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('시작하기'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await tester.pump(const Duration(milliseconds: 300));
      final hint = find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == const Color(0xFFFFF3B0));
      expect(hint, findsNWidgets(2)); // 처음 한 쌍
      await tester.tap(hint.first);
      await tester.pump();
      expect(hint, findsNWidgets(1)); // 하나를 누르면 그 칸은 선택 표시, 나머지 하나는 그대로
      await tester.tap(hint.first);
      await tester.pump();
      expect(hint, findsNothing); // 맞췄다 → 이제 노란 표시는 나오지 않는다
      expect(find.textContaining('짝이 맞았어요'), findsOneWidget);
      // 가만히 있어도(쉬움은 타이머 힌트가 없다) 다시 나오지 않는다
      await tester.pump(const Duration(seconds: 12));
      expect(hint, findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('수확 완료 화면', () {
    testWidgets('"무화과를 수확했습니다!" 옆에 이모티콘이 붙는다', (tester) async {
      await _screen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new), userDataProvider.overrideWithValue(const UserData({'exp': 9100}))],
        child: const MaterialApp(home: HarvestResultPage(cropCode: 'FIG', kg: 4)),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('무화과🫐를 수확했습니다!'), findsOneWidget);
      expect(find.text('+$harvestExp EXP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('움직이는 하우스·위성과 레벨업 그림', () {
    testWidgets('하우스(위성 달린 단계)는 시간이 흐르면 그림이 바뀐다', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(child: RepaintBoundary(key: key, child: Container(color: const Color(0xFF86C75A), width: 360, height: 244, child: GreenhouseView(count: 15, tier: greenhouseTierOfStage(15), stage: 15, name: '위성 연동 스마트팜')))),
      ));
      Future<Uint8List> shot() async => (await tester.runAsync(() async {
            final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final img = await b.toImage(pixelRatio: 1);
            final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
            return data!.buffer.asUint8List();
          }))!;
      await tester.pump(const Duration(milliseconds: 100));
      final a = await shot();
      await tester.pump(const Duration(milliseconds: 1500));
      final b = await shot();
      expect(a.length, b.length);
      expect(a, isNot(b)); // 위성·신호·작물이 움직여서 그림이 달라졌다
      expect(tester.takeException(), isNull);
      // active=false 이면 멈춘다 (화면에 안 보일 때 배터리 절약)
      await tester.pumpWidget(const MaterialApp(home: GreenhouseView(count: 15, tier: 5, stage: 15, active: false)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('레벨업 그림 두 층과 색종이가 에러 없이 그려진다', (tester) async {
      await _screen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 354,
              height: 486,
              child: Stack(children: [
                Positioned.fill(child: LevelUpCardArt(layer: LevelUpLayer.back)),
                Positioned.fill(child: LevelUpConfetti()),
                Positioned.fill(child: LevelUpCardArt(layer: LevelUpLayer.front)),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.textContaining('🎊'), findsNothing); // 이모지 색종이는 쓰지 않는다
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('시세 API 요청 속도', () {
    test('초당 요청 제한(429)을 알아본다', () {
      expect(AuctionApiService.isRateLimited(429, ''), isTrue);
      expect(AuctionApiService.isRateLimited(200, '{"errMsg":"LIMITED_NUMBER_OF_SERVICE_REQUESTS_PER_SECOND_EXCEEDS_ERROR"}'), isTrue);
      expect(AuctionApiService.isRateLimited(200, '{"response":{}}'), isFalse);
      expect(AuctionApiService.minGap, greaterThanOrEqualTo(const Duration(milliseconds: 300)));
    });
  });

  test('SharedPreferences 가짜값이 없어도 칭호·시세 규칙 테스트는 독립적이다', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
