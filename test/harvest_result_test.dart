// 수확 완료 화면: 경험치 카드가 보이고 작은 화면에서도 넘치지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/harvest_result_page.dart';

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => {'CABBAGE': AuctionPrice('CABBAGE', 911, DateTime(2026, 10, 8))};
}

void main() {
  for (final size in const [Size(360, 640), Size(411, 891)]) {
    testWidgets('수확 완료 ${size.height.toInt()}: 경험치·금액이 보이고 넘침이 없다', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [userDataProvider.overrideWithValue(const UserData({'exp': 338})), marketViewModelProvider.overrideWith(_FakeMarket.new)],
        child: const MaterialApp(home: HarvestResultPage(cropCode: 'CABBAGE', kg: 20)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('+$harvestExp EXP'), findsOneWidget);
      expect(find.textContaining('Lv.'), findsOneWidget);
      expect(find.text('18,220P'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
