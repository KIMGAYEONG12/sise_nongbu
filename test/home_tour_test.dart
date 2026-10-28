// 하우스 → 아파트 성장 규칙, 그림(10단계 외관 + 방 안), 둘러보기·집 안 화면, 캐시 동전, 스크롤 안내 알림창을 확인한다.
// 환경변수 PREVIEW_DIR 이 있으면 단계별 그림을 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/home_rules.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/home_tour_page.dart';
import 'package:sise_nongbu/widgets/common.dart';
import 'package:sise_nongbu/widgets/farm_mailbox.dart';
import 'package:sise_nongbu/widgets/home_art.dart';
import 'package:sise_nongbu/widgets/home_interior_art.dart';
import 'package:sise_nongbu/widgets/scroll_hint.dart';

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['PREVIEW_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  test('하우스 1~4단계 → 아파트 5~10단계, 그 위는 스카이 아파트 +n', () {
    expect(homeLevels.length, 10);
    expect([for (var s = 1; s <= 10; s++) isApartmentStage(s)], [false, false, false, false, true, true, true, true, true, true]);
    expect(homeLevelOf(0), 1);
    expect(homeLevelOf(-3), 1);
    expect(homeLevelOf(25), 10);
    expect(homeName(1), '작은 농장 하우스');
    expect(homeName(5), '기본 아파트');
    expect(homeName(10), '스카이 아파트');
    expect(homeName(12), '스카이 아파트 +2');
    // 지은 채 수를 주면 +숫자가 채 수와 같다
    expect(homeName(325, houses: 320), '스카이 아파트 +320');
    expect(homeUnit(3), '채');
    expect(homeUnit(5), '세대');
    expect(homeHouseholds(320), 320);
    expect(homeHousesNeeded(10, 5), 5);
    expect(homeHousesNeeded(3, 5), 1);
    expect(homeBadge(3), '3레벨 하우스');
    expect(homeBadge(5), '아파트 Lv.1');
    expect(homeBadge(10), '아파트 Lv.6');
    expect(homeLevels.map((e) => e.name).toSet().length, homeLevels.length, reason: '단계마다 이름이 달라요');
    for (var s = 1; s < 10; s++) {
      expect(homeSizeScale(s + 1), greaterThan(homeSizeScale(s)), reason: '단계가 오를수록 커져요');
    }
    expect(homeSizeScale(10), closeTo(1.45, 1e-9));
    expect(homeSizeScale(30), homeSizeScale(10));
    // 방과 편의 시설
    expect(homeRoomsOf(1), [HomeRoom.living, HomeRoom.kitchen, HomeRoom.bedroom]);
    expect(homeRoomsOf(3).contains(HomeRoom.balcony), isTrue);
    expect(homeRoomsOf(4).contains(HomeRoom.greenhouse), isTrue);
    expect(homeRoomsOf(5).contains(HomeRoom.greenhouse), isFalse);
    expect(homeFacilitiesOf(4), isEmpty);
    expect(homeFacilitiesOf(5).length, 1);
    expect(homeFacilitiesOf(10).length, homeFacilities.length);
    expect(homeFacilitiesOf(99).length, homeFacilities.length);
  });

  test('캐시 표기', () {
    expect(cash(0), '0 캐시');
    expect(cash(1500), '1,500 캐시');
  });

  testWidgets('하우스·아파트 10단계 외관이 모두 에러 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(2000, 440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFF6F8EB),
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            for (var s = 1; s <= 11; s++) Expanded(child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: HomeBuildingPainter(stage: s)))),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await _save(tester, key, 'home_levels');
  });

  testWidgets('모든 단계의 모든 방이 에러 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(2400, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          child: Column(children: [
            for (final s in const [1, 4, 5, 8, 10])
              Expanded(
                child: Row(children: [
                  for (final r in HomeRoom.values) Expanded(child: CustomPaint(size: Size.infinite, painter: HomeInteriorPainter(stage: s, room: r))),
                ]),
              ),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await _save(tester, key, 'home_rooms');
  });

  testWidgets('캐시 그림 4가지와 우체통(닫힘·편지 도착·열림)이 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Row(children: [for (final k in CashKind.values) CashCoin(size: 60, kind: k)]),
          CashPill(amount: 12345),
          Row(children: [
            SizedBox(width: 78, height: 90, child: CustomPaint(painter: MailboxPainter(flagUp: false))),
            SizedBox(width: 78, height: 90, child: CustomPaint(painter: MailboxPainter(flagUp: true))),
            SizedBox(width: 78, height: 90, child: CustomPaint(painter: MailboxPainter(flagUp: true, open: true, color: Color(0xFF4DA8F5)))),
          ]),
        ]),
      ),
    ));
    expect(find.text('12,345 캐시'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Widget tourApp(Map<String, dynamic> data, Widget home) => ProviderScope(
        overrides: [userDataProvider.overrideWithValue(UserData(data))],
        child: MaterialApp(home: home),
      );

  testWidgets('하우스가 없으면 미리보기만 되고 들어가기는 잠겨 있다', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(tourApp({'money': 5000}, const HomeTourPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('하우스 둘러보기'), findsOneWidget);
    expect(find.text('🔒 미리보기'), findsOneWidget);
    final locked = find.text('하우스를 1채 더 지으면 열려요');
    await tester.scrollUntilVisible(locked, 200, scrollable: find.byType(Scrollable).first);
    expect(locked, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아파트가 되면 둘러보기 → 자동 둘러보기 → 집 안으로 들어가 방을 옮겨 다닐 수 있다', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(tourApp({'money': 50000, 'greenhouses': 6}, const HomeTourPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('🔒 미리보기'), findsNothing);
    // 자동 둘러보기: 끝까지 돌면 다시 '자동' 단추가 된다
    await tester.tap(find.text('자동'));
    await tester.pump();
    expect(find.text('멈춤'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('자동'), findsOneWidget);
    // 집 안으로
    final enter = find.textContaining('안으로 들어가기');
    await tester.scrollUntilVisible(enter, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('거실'), findsWidgets);
    await tester.tap(find.text('주방'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('아파트 편의 시설', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('스크롤 안내 알림창: 잠시 뒤 나타나고, 누르면 아래로 내려가며 사라진다', (tester) async {
    FarmScrollHint.closed = false;
    final ctrl = ScrollController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(controller: ctrl, children: [
          SizedBox(height: 500, child: Stack(children: const [Positioned(left: 10, right: 10, bottom: 10, child: FarmScrollHint(scrollTo: 480))])),
          const SizedBox(height: 900, child: Text('작물 관리')),
        ]),
      ),
    ));
    expect(find.text('아래로 내리면 작물 관리가 있어요!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('아래로 내리면 작물 관리가 있어요!'), findsOneWidget);
    await tester.tap(find.text('아래로 내리면 작물 관리가 있어요!'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600)); // 숨는 애니메이션(0.42초)이 끝날 때까지
    expect(ctrl.offset, greaterThan(100));
    expect(find.text('아래로 내리면 작물 관리가 있어요!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
