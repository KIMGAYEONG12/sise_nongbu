// 창고의 "판매하기" 버튼으로 작물이 없어도 물통·영양제 같은 아이템을 팔 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/inventory_page.dart';

void main() {
  testWidgets('작물이 없어도 판매하기를 누르면 아이템 팔기 창이 열리고 고를 수 있다', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataProvider.overrideWithValue(const UserData({
          'money': 50000,
          'items': {'water': 10, 'fertilizer': 4},
        })),
        lotsProvider.overrideWith((ref) => Stream.value(const <Lot>[])),
      ],
      child: const MaterialApp(home: Scaffold(body: InventoryPage())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('판매하기'));
    await tester.pumpAndSettle();
    expect(find.text('아이템 팔기'), findsOneWidget);
    expect(find.text('팔 것을 골라 주세요'), findsOneWidget);

    // 하나를 고르면 팔기 버튼이 켜진다
    await tester.tap(find.text('💧 물통'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1종 팔기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
