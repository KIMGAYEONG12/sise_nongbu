// 판매 완료 문구, 스플래시 연출, 판매 포인트 규칙을 확인한다 (Firebase 없이).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/views/sell_page.dart';
import 'package:sise_nongbu/views/splash_page.dart';

void main() {
  test('판매 완료 문구: 작물 이름에 맞는 조사를 붙인다', () {
    expect(soldMessage(['배추']), '배추가 판매되었습니다!');
    expect(soldMessage(['무']), '무가 판매되었습니다!');
    expect(soldMessage(['양파']), '양파가 판매되었습니다!');
    expect(soldMessage(['배추', '배추']), '배추가 판매되었습니다!');
    expect(soldMessage(['배추', '무']), '배추, 무가 판매되었습니다!');
    expect(soldMessage(['배추', '무', '사과']), '배추 외 2종이 판매되었습니다!');
  });

  test('판매 1건당 포인트는 10P', () {
    expect(sellPointReward, 10);
  });

  testWidgets('스플래시: 연출이 돌아가고 진행 막대가 차면 onDone이 한 번 불린다', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(home: SplashPage(onDone: () => done++)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('농부의 꿈이 자라고 있어요...'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 그림 읽기는 실제 비동기라 runAsync로 기다리고, 막대가 차는 시간은 pump로 흘려 보낸다
    for (var i = 0; i < 40 && done == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(done, 1);
    // 반복 연출(fx)은 화면이 사라질 때 정리되어야 한다
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
