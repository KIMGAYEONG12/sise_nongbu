// 튜토리얼 2~4장을 직접 눌러 체험할 수 있는지 확인한다 (Firebase 없이 시세 뷰모델만 가짜로 대체).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/tutorial_page.dart';
import 'package:sise_nongbu/widgets/common.dart';

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
    tester.view.physicalSize = const Size(1080, 2700);
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
    // 그림은 틀을 덮도록 키워 가운데에 놓인다 → 그림 속 좌표(원본 810×801 픽셀)를 같은 배율로 화면 좌표로 옮긴다
    final r = tester.getRect(find.byType(IllustCard).first);
    final k = r.width / 810 > r.height / 801 ? r.width / 810 : r.height / 801;
    final ox = r.left + (r.width - 810 * k) / 2, oy = r.top + (r.height - 801 * k) / 2;
    Offset at(double x, double y) => Offset(ox + x * k, oy + y * k);
    await tester.tapAt(at(410, 495)); // 가운데 칸
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('무엇을 심을까요?'), findsOneWidget); // 작물 고르는 시트
    await tester.tap(find.text('배추'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('1칸 심었어요'), findsOneWidget);
    await tester.tapAt(at(177, 492)); // 왼쪽 가운데 칸
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
    await tester.tap(find.text('수확')); // 수확 카드
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('수확: 다 자라면'), findsOneWidget);
    // 물주기 체험: 40% → 물을 줄 때마다 3%씩 올라간다 (한 밭에 최대 10번)
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('40%'), findsOneWidget);
    await tester.tap(find.text('물주기'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('43%'), findsOneWidget);

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
