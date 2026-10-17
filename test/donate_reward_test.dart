// 마을 기금: 기부할 때마다 받는 포인트는 많이 기부할수록 비율이 좋아진다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';

void main() {
  test('기부 보상 포인트', () {
    expect(donateRewardPoints(0), 0);
    expect(donateRewardPoints(1000), 10);
    expect(donateRewardPoints(5000), 60);
    expect(donateRewardPoints(10000), 150);
    expect(donateRewardPoints(50000), 900);
    // 많이 기부할수록 1P당 받는 포인트가 많다
    expect(donateRewardPoints(50000) / 50000, greaterThan(donateRewardPoints(1000) / 1000));
  });
}
