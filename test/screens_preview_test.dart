// 시안에 맞춰 다시 만든 화면들(뉴스·시세 상세·판매·작물 성장·특별 상점)이 에러 없이 그려지고 제대로 동작하는지 확인한다.
// 환경변수 PREVIEW_DIR 이 있으면 화면을 PNG로 저장한다 (Firebase 없이 가짜 데이터로).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/core/price_alert.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/crop_growth_page.dart';
import 'package:sise_nongbu/views/news_page.dart';
import 'package:sise_nongbu/views/point_shop_page.dart';
import 'package:sise_nongbu/views/price_detail_page.dart';
import 'package:sise_nongbu/views/sell_page.dart';
import 'package:sise_nongbu/widgets/common.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';
import 'preview_font.dart';

final _day = DateTime(2026, 10, 12, 12);

/// 시안과 같은 값(배추 1,850원 ▲12.4%, 토마토 ▼5.2% …)
final _prices = <String, AuctionPrice>{
  'CABBAGE': AuctionPrice('CABBAGE', 1850, _day, prevPerKg: 1646),
  'TOMATO': AuctionPrice('TOMATO', 1641, _day, prevPerKg: 1731),
  'APPLE': AuctionPrice('APPLE', 3337, _day, prevPerKg: 3215),
  'ONION': AuctionPrice('ONION', 763, _day, prevPerKg: 767),
  'POTATO': AuctionPrice('POTATO', 3205, _day, prevPerKg: 3247),
  'RADISH': AuctionPrice('RADISH', 1500, _day, prevPerKg: 1500),
};

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => _prices;
}

final _shot = GlobalKey();

Future<void> _open(WidgetTester tester, Widget page, {List<Override> overrides = const [], Size size = const Size(411, 891)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new), ...overrides],
    child: MaterialApp(debugShowCheckedModeBanner: false, home: RepaintBoundary(key: _shot, child: page)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(() async {
    if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
  });

  group('전국 농부 뉴스', () {
    test('시세로 소식을 만든다: 오르면 출하 추천·내리면 보관 추천, 값은 시세 그대로', () {
      final news = buildNews(_prices);
      final cabbage = news.firstWhere((n) => n.cropCode == 'CABBAGE');
      expect(cabbage.title, '배추 시세 상승 12.4%');
      expect(cabbage.price, 1850);
      expect(cabbage.tag, '출하 추천');
      expect(cabbage.isUp, isTrue);
      final tomato = news.firstWhere((n) => n.cropCode == 'TOMATO');
      expect(tomato.title, '토마토 시세 하락 5.2%');
      expect(tomato.tag, '보관 추천');
      expect(tomato.isDown, isTrue);
      final radish = news.firstWhere((n) => n.cropCode == 'RADISH');
      expect(radish.title, '무 시세 보합');
      expect(radish.tag, '보합');
      // 이전 시세가 없으면 등락 없이 가격만
      final lone = buildNews({'APPLE': AuctionPrice('APPLE', 3000, _day)}).first;
      expect(lone.percent, isNull);
      expect(lone.title, contains('3,000원'));
      // 게임 안내 소식(이벤트·특수)은 시세가 없어도 항상 있다
      final plain = buildNews(const {});
      expect(plain.where((n) => n.category == '이벤트').length, 3);
      expect(plain.where((n) => n.category == '특수').length, 3);
      expect(plain.every((n) => n.cropCode == null), isTrue);
    });

    testWidgets('작물 그림·가격·▲▼ 등락률이 카드에 나온다', (tester) async {
      await _open(tester, const NewsPage());
      expect(find.text('전국 농부 뉴스'), findsOneWidget);
      // 제목은 낱말마다 따로 그리는 KoText 라서 위젯의 글자로 찾는다
      Finder title(String t) => find.byWidgetPredicate((w) => w is KoText && w.data == t);
      expect(title('배추 시세 상승 12.4%'), findsOneWidget);
      expect(find.text('1,850원/kg'), findsOneWidget);
      expect(find.text('출하 추천'), findsNWidgets(2)); // 배추(+12.4%)와 사과(+3.8%)
      expect(find.text('보관 추천'), findsWidgets);
      expect(find.text('▲'), findsWidgets);
      expect(find.text('▼'), findsWidgets);
      expect(find.text('12.4%'), findsNWidgets(2)); // 제목 속 낱말 + 오른쪽 등락률
      expect(find.byType(CropArt), findsWidgets); // 이모지가 아니라 작물 그림
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'news');
      // 탭: 이벤트만 보기
      await tester.tap(find.descendant(of: find.byType(PillTabs), matching: find.text('이벤트')));
      await tester.pump();
      expect(title('배추 시세 상승 12.4%'), findsNothing);
      expect(title('마을 공동기금 모으기'), findsOneWidget);
    });
  });

  group('시세판 상세', () {
    List<Override> detailOverrides(SharedPreferences prefs) => [
          prefsProvider.overrideWithValue(prefs),
          priceHistoryProvider.overrideWith((ref, key) async => [for (var i = 0; i < key.$2; i++) i == 2 ? null : 1500.0 + (i * 37 % 300)]),
          priceVolumeProvider.overrideWith((ref, code) async => 1740000.0),
          plotsProvider.overrideWith((ref) => Stream.value([Plot(0, 'CABBAGE', _day.add(const Duration(hours: 1)), growMs: 3600000), const Plot(1, null, null)])),
          lotsProvider.overrideWith((ref) => Stream.value([Lot('a', 'CABBAGE', 20, _day)])),
          tradesProvider.overrideWith((ref) => Stream.value([Trade('CABBAGE', 12, 1800, 1, 21600, _day, _day)])),
        ];

    testWidgets('기간 탭 · 요약 · 시세 알림 설정 버튼이 보인다', (tester) async {
      final prefs = await tester.runAsync(_prefs) as SharedPreferences;
      await _open(tester, const PriceDetailPage(cropCode: 'CABBAGE'), overrides: detailOverrides(prefs));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('시세판 상세'), findsOneWidget);
      expect(find.text('1,850원/kg'), findsOneWidget);
      expect(find.text('12.4%'), findsOneWidget); // 등락 알약
      expect(find.text('7일'), findsOneWidget);
      expect(find.text('14일'), findsOneWidget);
      expect(find.text('30일'), findsOneWidget);
      expect(find.text('최근 7일 시세 (원/kg)'), findsOneWidget);
      expect(find.text('거래량'), findsOneWidget);
      expect(find.text('1,740,000kg'), findsOneWidget);
      expect(find.text('평균가'), findsOneWidget);
      expect(find.text('시세 알림 설정'), findsOneWidget);
      expect(find.byType(CropArt), findsWidgets);
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'price_detail');
    });

    testWidgets('14일·30일을 누르면 그래프 기간이 바뀐다', (tester) async {
      final prefs = await tester.runAsync(_prefs) as SharedPreferences;
      await _open(tester, const PriceDetailPage(cropCode: 'CABBAGE'), overrides: detailOverrides(prefs));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('14일'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('최근 14일 시세 (원/kg)'), findsOneWidget);
      await tester.tap(find.text('30일'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('최근 30일 시세 (원/kg)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'price_detail_30');
    });

    testWidgets('시세 알림 설정: 목표 가격을 저장하면 버튼에 조건이 나오고, 끄면 사라진다', (tester) async {
      final prefs = await tester.runAsync(_prefs) as SharedPreferences;
      await _open(tester, const PriceDetailPage(cropCode: 'CABBAGE'), overrides: detailOverrides(prefs));
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(find.byType(PriceDetailPage)));
      expect(container.read(priceAlertsProvider), isEmpty);

      await tester.tap(find.text('시세 알림 설정'));
      await tester.pumpAndSettle();
      expect(find.text('배추 시세 알림'), findsOneWidget);
      expect(find.text('알림 저장'), findsOneWidget);
      expect(find.text('알림 끄기'), findsNothing);
      // 처음 목표 가격은 지금 시세(1,850)의 +5% = 1,940
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1940');
      await savePreview(tester, _shot, 'price_alert_sheet');

      await tester.enterText(find.byType(TextField), '2000');
      await tester.pump();
      await tester.tap(find.text('알림 저장'));
      await tester.pumpAndSettle();
      expect(container.read(priceAlertsProvider)['CABBAGE'], const PriceAlert(code: 'CABBAGE', above: true, target: 2000));
      expect(find.text('시세 알림 설정 · 2,000원 이상'), findsOneWidget);
      // 화면 아래에 뜬 안내(스낵바)가 사라진 뒤에 버튼을 다시 누른다
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 다시 열어서 끄기
      await tester.tap(find.text('시세 알림 설정 · 2,000원 이상'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '2000');
      await tester.tap(find.text('알림 끄기'));
      await tester.pumpAndSettle();
      expect(container.read(priceAlertsProvider), isEmpty);
      expect(find.text('시세 알림 설정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('기간 요약: 평균·최고·최저와 현재 시세가 평균보다 몇 % 높은지', () {
      final s = PriceStats.of([1000, 2000, 3000], 3000)!;
      expect(s.avg, 2000);
      expect(s.high, 3000);
      expect(s.low, 1000);
      expect(s.vsAvg, closeTo(50, 1e-9));
      expect(PriceStats.of(const [], 1000), isNull);
      expect(PriceStats.of([1000], null)!.vsAvg, isNull);
    });

    test('그래프 날짜 글자는 겹치지 않게 띄엄띄엄 (최대 6개 안팎)', () {
      expect(LineChartPainter.labelStep(7), 2);
      expect(LineChartPainter.labelStep(6), 1);
      expect(LineChartPainter.labelStep(14), 3);
      expect(LineChartPainter.labelStep(30), 5);
      expect((30 / LineChartPainter.labelStep(30)).ceil(), lessThanOrEqualTo(6));
    });
  });

  group('판매할 작물 선택', () {
    final lots = [Lot('1', 'CABBAGE', 20, _day), Lot('2', 'RADISH', 15, _day), Lot('3', 'ONION', 12, _day)];
    testWidgets('작물 그림·무게·금액, 예상 수익(총 판매금액·판매이익·Point)이 시안처럼 나온다', (tester) async {
      await _open(tester, const SellPage(), overrides: [lotsProvider.overrideWith((ref) => Stream.value(lots))]);
      expect(find.text('판매할 작물 선택'), findsOneWidget);
      expect(find.text('배추'), findsOneWidget);
      expect(find.text('20kg'), findsOneWidget);
      expect(find.text(won(saleAmount(20, 1850, 1))), findsOneWidget); // 37,000P
      expect(find.byType(CropArt), findsNWidgets(3));
      expect(find.text('예상 수익'), findsOneWidget);
      expect(find.text('총 판매금액'), findsOneWidget);
      expect(find.text('판매이익'), findsOneWidget);
      expect(find.text('Point'), findsOneWidget);
      expect(find.text('+0P'), findsNWidgets(2)); // 아직 아무것도 안 골랐다 (판매이익·Point)
      await savePreview(tester, _shot, 'sell_none');

      await tester.tap(find.text('배추'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('+${won(saleAmount(20, 1850, 1))}'), findsOneWidget); // 판매이익
      expect(find.text('+${sellPointReward}P'), findsOneWidget); // +10P
      await savePreview(tester, _shot, 'sell_one');

      await tester.tap(find.text('전체 선택'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('+${3 * sellPointReward}P'), findsOneWidget);
      expect(find.text('선택 해제'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'sell_all');
    });
  });

  group('작물 성장 화면', () {
    test('흔들림은 아주 작다 (최대 3도 안쪽)이고 밭마다 박자가 다르다', () {
      for (var t = 0.0; t <= 1.0; t += .05) {
        for (var phase = 0; phase < 24; phase++) {
          for (final stage in const [0.0, .5, 1.0]) {
            expect(SwayingCrop.angleAt(t, phase, stage).abs(), lessThanOrEqualTo(.0481)); // 0.048rad ≈ 2.75°
          }
        }
      }
      // 다 자란 작물이 새싹보다 더 크게, 밭 번호가 다르면 다른 각도
      double peak(double stage) => [for (var i = 0; i < 100; i++) SwayingCrop.angleAt(i / 100, 0, stage).abs()].reduce((a, b) => a > b ? a : b);
      expect(peak(1.0), greaterThan(peak(0.1)));
      expect(SwayingCrop.angleAt(.3, 0, 1), isNot(SwayingCrop.angleAt(.3, 3, 1)));
    });

    testWidgets('심은 밭의 작물은 살랑살랑 움직이고 빈 밭은 그대로다', (tester) async {
      final plots = <Plot>[
        Plot(0, 'CABBAGE', _day.add(const Duration(minutes: 30)), growMs: 3000000),
        Plot(1, 'TOMATO', _day.subtract(const Duration(minutes: 1)), growMs: 600000),
        Plot(2, 'FIG', _day.add(const Duration(minutes: 250)), growMs: 16800000),
        for (var i = 3; i < 9; i++) Plot(i, null, null),
      ];
      await _open(tester, const CropGrowthPage(), overrides: [
        userDataProvider.overrideWithValue(const UserData({'exp': 1100, 'money': 64787, 'items': {'water': 4}})),
        plotsProvider.overrideWith((ref) => Stream.value(plots)),
        tickProvider.overrideWith((ref) => Stream.value(_day)),
      ]);
      expect(find.byType(SwayingCrop), findsNWidgets(3));
      Matrix4 rot(int i) => tester.widget<Transform>(find.descendant(of: find.byType(SwayingCrop).at(i), matching: find.byType(Transform)).first).transform;
      final before = rot(0).storage.toList();
      await tester.pump(const Duration(milliseconds: 900)); // 컨트롤러가 돌면서 각도가 바뀐다
      final after = rot(0).storage.toList();
      expect(after, isNot(before));
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'crop_growth');
      await tester.pumpWidget(const SizedBox()); // 반복 애니메이션이 화면을 닫을 때 정리된다
      expect(tester.takeException(), isNull);
    });
  });

  group('특별 상점', () {
    testWidgets('상품이 9가지이고 값이 낮아졌으며 모두 포인트로 산다', (tester) async {
      await _open(tester, const PointShopPage(), overrides: [
        userDataProvider.overrideWithValue(const UserData({'points': 3045, 'money': 64787})),
      ]);
      for (final item in pointItems.take(5)) {
        expect(find.text(item.name), findsOneWidget);
        expect(find.text('${item.cost}P'), findsWidgets);
      }
      expect(find.text('희귀 씨앗'), findsOneWidget);
      expect(find.text('60P'), findsWidgets);
      expect(find.text('모든 아이템을 살 수 있어요!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await savePreview(tester, _shot, 'point_shop');
      // 아래로 내리면 새 상품들이 나온다
      await tester.scrollUntilVisible(find.text('농부 교본'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('농부 교본'), findsOneWidget);
      await savePreview(tester, _shot, 'point_shop_bottom');
    });
  });

  group('작물 알림', () {
    testWidgets('수확·파종 알림은 작물 그림 없이 문구 끝의 이모티콘만 보인다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showCropMsg(c, 'WATERMELON', '🍉 수박을 수확했어요!'), child: const Text('열기'))))),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('🍉 수박을 수확했어요!'), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.byType(CropArt)), findsNothing); // 왼쪽 그림은 없다
      expect(tester.takeException(), isNull);
    });
  });
}
