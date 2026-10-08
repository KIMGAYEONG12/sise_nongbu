// 튜토리얼 2~4장을 직접 눌러 체험할 수 있는지 확인한다 (Firebase 없이 시세 뷰모델만 가짜로 대체).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/tutorial_page.dart';

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => {'CABBAGE': AuctionPrice('CABBAGE', 911, DateTime(2026, 10, 7), prevPerKg: 800)};
}

Future<void> _next(WidgetTester t) async {
  await t.tap(find.text('다음'));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('튜토리얼 2~4장은 직접 눌러서 체험할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new)],
      child: MaterialApp(home: TutorialPage(onDone: () => done++)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('튜토리얼 1 / 5'), findsOneWidget);

    // 2장: 밭을 눌러 심기
    await _next(tester);
    expect(find.text('튜토리얼 2 / 5'), findsOneWidget);
    expect(find.textContaining('직접 심어보세요'), findsOneWidget);
    // 가운데 칸 위치(그림 비율 .506, .618)를 누른다: 안내 문구가 있는 그림 영역을 찾아 계산
    final art = find.ancestor(of: find.textContaining('직접 심어보세요'), matching: find.byType(AspectRatio)).first;
    final r = tester.getRect(art);
    await tester.tapAt(Offset(r.left + r.width * .506, r.top + r.height * .618));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('무엇을 심을까요?'), findsOneWidget); // 작물 고르는 시트
    await tester.tap(find.text('배추'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('1칸 심었어요'), findsOneWidget);
    await tester.tapAt(Offset(r.left + r.width * .2, r.top + r.height * .45)); // 왼쪽 가운데 칸
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('무'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('2칸 심었어요'), findsOneWidget);

    // 3장: 단계 눌러 보기
    await _next(tester);
    expect(find.text('튜토리얼 3 / 5'), findsOneWidget);
    expect(find.textContaining('단계를 눌러'), findsOneWidget);
    final art3 = find.ancestor(of: find.textContaining('단계를 눌러'), matching: find.byType(AspectRatio)).first;
    final r3 = tester.getRect(art3);
    await tester.tapAt(Offset(r3.left + r3.width * .85, r3.top + r3.height * .6)); // 수확 카드
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('수확: 다 자라면'), findsOneWidget);

    // 4장: 시세는 1,850원 고정, 판매하기를 누르면 판매 완료
    await _next(tester);
    expect(find.text('튜토리얼 4 / 5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('1,850원/kg'), findsOneWidget);
    await tester.tap(find.text('판매하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('판매 완료'), findsOneWidget);

    // 5장: 시작하기
    await _next(tester);
    await tester.tap(find.text('시작하기'));
    expect(done, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
