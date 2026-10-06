import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';

void main() {
  test('신선도: 하루 5% 감소, 하한 70%', () {
    final t = DateTime(2026, 10, 1);
    expect(freshnessOf(t, t), 1.0);
    expect(freshnessOf(t, t.add(const Duration(days: 2))), closeTo(0.9, 1e-9));
    expect(freshnessOf(t, t.add(const Duration(days: 30))), minFreshness);
  });
  test('출하 대금 = 수량 × 시세 × 신선도', () => expect(saleAmount(20, 1000, 0.9), 18000));
  test('kg당 환산: 불가하면 null', () {
    expect(toPricePerKg(15000, 15), 1000);
    expect(toPricePerKg(15000, 0), isNull);
  });
  test('거래량 가중평균, 빈 입력은 null', () {
    expect(weightedPrice([const AuctionRow(1000, 100), const AuctionRow(2000, 300)]), 1750);
    expect(weightedPrice([]), isNull);
  });
  test('데모 배속은 성장 시간을 줄인다', () {
    final c = cropOf('CABBAGE');
    expect(growDuration(c, 600).inSeconds, 24);
  });
}
