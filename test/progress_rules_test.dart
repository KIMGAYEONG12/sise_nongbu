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
    expect(warehouseCost(0), 2000);
    expect(warehouseCost(2), 6000);
  });

  test('밭 확장 비용: 6칸 5만, 9칸 10만, 12칸은 최대', () {
    expect(plotExpandCost(6), 5000);
    expect(plotExpandCost(9), 10000);
    expect(plotExpandCost(12), 15000);
    expect(plotExpandCost(21), 30000);
    expect(plotExpandCost(24), isNull);
  });

  test('하우스는 몇 채든 지을 수 있고 성장 시간을 줄인다', () {
    expect(applyGreenhouses(const Duration(hours: 10), 1), const Duration(hours: 9));
    expect(applyGreenhouses(const Duration(hours: 10), 5), const Duration(hours: 5));
    expect(applyGreenhouses(const Duration(hours: 10), 0), const Duration(hours: 10));
    // 5채를 넘겨도 계속 지을 수 있고, 한 채마다 4%씩 더 줄어서 10채에서 최대 70% 단축
    expect(greenhouseFactor(6), closeTo(0.46, 1e-9));
    expect(greenhouseFactor(6), lessThan(greenhouseFactor(5)));
    expect(greenhouseFactor(9), closeTo(0.34, 1e-9));
    expect(greenhouseFactor(10), closeTo(0.3, 1e-9));
    expect(greenhouseFactor(11), closeTo(0.3, 1e-9));
    expect(greenhouseFactor(1000), closeTo(0.3, 1e-9));
    expect(greenhouseFactor(-3), 1.0);
    // 하우스 값은 몇 채를 지어도 10,000으로 같다
    expect(greenhouseCostFor(0), 10000);
    expect(greenhouseCostFor(4), 10000);
    expect(greenhouseCostFor(5), 10000);
    expect(greenhouseCostFor(20), 10000);
  });

  test('레벨 업 보상은 레벨이 높을수록 커진다', () {
    expect(levelUpPointsFor(2), 500);
    expect(levelUpPointsFor(3), 600);
    expect(levelUpPointsFor(10), 1300);
    for (var l = 2; l < 40; l++) {
      expect(levelUpPointsFor(l + 1), greaterThan(levelUpPointsFor(l)));
      expect(levelUpSeedsFor(l + 1), greaterThanOrEqualTo(levelUpSeedsFor(l)));
    }
    expect([for (final l in [2, 5, 6, 10, 11, 16]) levelUpSeedsFor(l)], [1, 1, 2, 2, 3, 4]);
    // 여러 레벨을 한 번에 올라도 레벨마다 계산해서 더한다
    expect(levelUpTotals(1, 2), (500, 1));
    expect(levelUpTotals(2, 4), (600 + 700, 2));
    expect(levelUpTotals(4, 4), (0, 0));
  });

  test('씨앗은 파종비의 85%', () {
    expect(seedPrice(cropOf('CABBAGE')), 10200);
  });

  test('물주기는 한 번에 3% 단축 (횟수 제한 없음), 튜토리얼 연습은 10번', () {
    expect(waterCut, closeTo(0.03, 1e-9));
    expect(tutorialWaterCount, 10);
    expect(waterCut * tutorialWaterCount, closeTo(0.30, 1e-9));
  });

  test('미션은 기간마다 id·종류가 겹치지 않는다', () {
    final all = [...dailyMissions, ...weeklyMissions];
    expect(all.map((m) => m.id).toSet().length, all.length);
    expect(dailyMissions.map((m) => m.key).toSet().length, dailyMissions.length);
    expect(weeklyMissions.map((m) => m.key).toSet().length, weeklyMissions.length);
  });

  test('업적은 이름과 (조건·목표) 조합이 겹치지 않는다', () {
    expect(achievements.map((a) => a.title).toSet().length, achievements.length);
    expect(achievements.map((a) => '${a.statKey}:${a.target}').toSet().length, achievements.length);
  });

  test('씨앗 꾸러미는 기본 6종만 담아서 값이 터무니없이 커지지 않는다', () {
    expect(seedPackCrops.length, seedPackCropCount);
    expect(seedPackCrops.map((c) => c.code), ['CABBAGE', 'RADISH', 'ONION', 'APPLE', 'TOMATO', 'POTATO']);
    final alone = seedPackCrops.fold<int>(0, (a, c) => a + seedPrice(c));
    expect(seedPackPrice(), (alone * 0.9).round());
    expect(seedPackPrice(), lessThan(alone));
    expect(seedPackPrice(), lessThan(100000)); // 작물이 21종으로 늘었어도 18만 원대로 뛰지 않는다
  });

  test('특별 상점: 상품 번호가 겹치지 않고 값이 낮아졌으며 모두 포인트 400 이하', () {
    final keys = pointItems.map((e) => e.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(pointItems.length, greaterThanOrEqualTo(9));
    for (final i in pointItems) {
      expect(i.cost, greaterThan(0));
      expect(i.cost, lessThanOrEqualTo(400));
      expect(i.name, isNotEmpty);
      expect(i.desc, isNotEmpty);
    }
    int cost(String k) => pointItems.firstWhere((e) => e.key == k).cost;
    // 예전 값(100·80·200·150)보다 싸다
    expect(cost(pointRareSeed), lessThan(100));
    expect(cost(pointDecor), lessThan(80));
    expect(cost(pointVault), lessThan(200));
    expect(cost(pointLucky), lessThan(150));
  });

  test('판매 1건당 포인트는 10P (시안의 +10P)', () {
    expect(sellPointReward, 10);
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

  test('업적은 id가 모두 다르고 목표·보상이 0보다 크다', () {
    expect(achievements.map((a) => a.id).toSet().length, achievements.length);
    for (final a in achievements) {
      expect(a.target, greaterThan(0), reason: a.id);
      expect(a.points, greaterThan(0), reason: a.id);
      expect(const ['일반', '도전', '특별'], contains(a.category), reason: a.id);
    }
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
