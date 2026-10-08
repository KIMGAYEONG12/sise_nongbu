// 작물 매칭: 오늘 시세가 오른 작물일수록 점수 배율이 커진다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/match_logic.dart';

void main() {
  test('시세가 오르지 않았거나 모르면 배율 1, 10% 이상 오르면 2', () {
    expect(matchWeight(null), 1.0);
    expect(matchWeight(-5), 1.0);
    expect(matchWeight(5), closeTo(1.5, 1e-9));
    expect(matchWeight(30), 2.0);
  });

  test('배율을 곱한 점수: 배율이 모두 1이면 기존 점수와 같고, 오른 작물은 더 높다', () {
    const r = MatchResult(3, 1, {0: 3});
    expect(r.scoreWith([1, 1, 1]), r.score);
    expect(r.scoreWith([2, 1, 1]), 60);
    expect(r.scoreWith([1, 2, 2]), 30);
  });
}
