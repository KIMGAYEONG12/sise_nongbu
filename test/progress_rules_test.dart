import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/core/progress_rules.dart';

void main() {
  test('레벨 계산: 누적 경험치 → 레벨', () {
    expect(levelInfo(0).level, 1);
    expect(levelInfo(199).level, 1);
    expect(levelInfo(200).level, 2);
    expect(levelInfo(200).exp, 0);
    expect(levelInfo(499).level, 2); // 200 + 300 = 500부터 Lv3
    expect(levelInfo(500).level, 3);
    expect(levelInfo(100).ratio, closeTo(.5, 1e-9));
  });

  test('창고 용량과 확장 비용', () {
    expect(warehouseCapKg(0, 0), 200);
    expect(warehouseCapKg(2, 50), 450);
    expect(warehouseCost(0), 20000);
    expect(warehouseCost(2), 60000);
  });

  test('밭 확장 비용: 6칸 5만, 9칸 10만, 12칸은 최대', () {
    expect(plotExpandCost(6), 50000);
    expect(plotExpandCost(9), 100000);
    expect(plotExpandCost(12), isNull);
  });

  test('하우스는 성장 시간을 20% 줄인다', () {
    expect(applyGreenhouse(const Duration(hours: 10), true), const Duration(hours: 8));
    expect(applyGreenhouse(const Duration(hours: 10), false), const Duration(hours: 10));
  });

  test('씨앗은 파종비의 85%', () {
    expect(seedPrice(cropOf('CABBAGE')), 10200);
  });

  test('일일·주간 카운터는 태그가 바뀌면 새로 시작한다', () {
    var m = bumpPeriod(null, '2026-10-06', 'water');
    m = bumpPeriod(m, '2026-10-06', 'water', 2);
    expect(periodCount(m, '2026-10-06', 'water'), 3);
    expect(periodCount(m, '2026-10-07', 'water'), 0);
    final n = bumpPeriod(m, '2026-10-07', 'water');
    expect(periodCount(n, '2026-10-07', 'water'), 1);
  });

  test('주간 태그는 그 주 월요일', () {
    expect(weekTag(DateTime(2026, 10, 6)), '2026-10-05'); // 화요일
    expect(weekTag(DateTime(2026, 10, 11)), '2026-10-05'); // 일요일
    expect(weekTag(DateTime(2026, 10, 12)), '2026-10-12');
  });

  test('수령 기록', () {
    final m = markClaimed(null, 't', 'a');
    expect(periodClaimed(markClaimed(m, 't', 'b'), 't'), ['a', 'b']);
    expect(periodClaimed(m, 'other'), isEmpty);
  });

  test('업적 진행도', () {
    final user = {'money': 250000, 'stats': {'harvest': 4}};
    final rich = achievementById('rich')!;
    final h10 = achievementById('harvest10')!;
    final big = achievementById('big_farm')!;
    expect(achievementProgress(rich, user, 6), 250000);
    expect(achievementProgress(h10, user, 6), 4);
    expect(achievementProgress(big, user, 9), 9);
  });

  test('매칭 게임 보상 한도', () {
    expect(gameRewardMoney(100), 2000);
    expect(gameRewardMoney(1000), 5000);
    expect(gameRewardPoints(100), 5);
    expect(gameRewardPoints(10000), 30);
  });

  test('시세 변화율', () {
    expect(changePercent(110, 100), closeTo(10, 1e-9));
    expect(changePercent(90, 100), closeTo(-10, 1e-9));
    expect(changePercent(100, null), isNull);
    expect(changePercent(100, 0), isNull);
  });

  test('아이템 이름', () {
    expect(itemName('water'), '물통');
    expect(itemName(seedKey('APPLE')), '사과 씨앗');
  });
}
