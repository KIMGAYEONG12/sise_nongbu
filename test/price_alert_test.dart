// 시세 알림(목표 가격) 규칙과 저장을 확인한다 (Firebase 없이).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sise_nongbu/core/price_alert.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';

void main() {
  group('규칙', () {
    test('이상 / 이하 조건', () {
      const up = PriceAlert(code: 'CABBAGE', above: true, target: 2000);
      const down = PriceAlert(code: 'CABBAGE', above: false, target: 1500);
      expect(up.hit(1999), isFalse);
      expect(up.hit(2000), isTrue);
      expect(up.hit(2500), isTrue);
      expect(down.hit(1501), isFalse);
      expect(down.hit(1500), isTrue);
      expect(down.hit(900), isTrue);
    });

    test('저장했다가 다시 읽으면 같다', () {
      final alerts = {
        'CABBAGE': const PriceAlert(code: 'CABBAGE', above: true, target: 2000),
        'APPLE': const PriceAlert(code: 'APPLE', above: false, target: 3300.5, fired: true),
      };
      final back = decodeAlerts(encodeAlerts(alerts.values));
      expect(back, alerts);
    });

    test('비었거나 깨진 저장값은 빈 맵', () {
      expect(decodeAlerts(null), isEmpty);
      expect(decodeAlerts(''), isEmpty);
      expect(decodeAlerts('이상한 글자'), isEmpty);
      expect(decodeAlerts('{"a":1}'), isEmpty);
      // 목표 가격이 0 이하이거나 모양이 틀린 항목은 건너뛴다
      expect(decodeAlerts('[{"c":"X","a":true,"t":0},{"c":"Y","a":true},{"c":"Z","a":false,"t":10}]').keys, ['Z']);
    });

    test('울려야 할 알림만 고른다 (조건을 채웠고 아직 안 울린 것)', () {
      final alerts = {
        'A': const PriceAlert(code: 'A', above: true, target: 100),
        'B': const PriceAlert(code: 'B', above: true, target: 100, fired: true),
        'C': const PriceAlert(code: 'C', above: false, target: 50),
        'D': const PriceAlert(code: 'D', above: true, target: 100),
      };
      final due = dueAlerts(alerts, {'A': 120, 'B': 500, 'C': 60, 'D': 99});
      expect(due.map((e) => e.code), ['A']);
      // 시세가 없는 작물은 건너뛴다
      expect(dueAlerts(alerts, const {}), isEmpty);
    });

    test('처음 보여 줄 목표 가격은 지금 시세의 ±5%를 10원 단위로', () {
      expect(suggestedTarget(1850, above: true), 1940); // 1942.5 → 1940
      expect(suggestedTarget(1850, above: false), 1760); // 1757.5 → 1760
      expect(suggestedTarget(1, above: false), 10);
    });
  });

  group('저장소 (알림 걸기·끄기·한 번만 울림)', () {
    Future<ProviderContainer> make([Map<String, Object> initial = const {}]) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    final now = DateTime(2026, 10, 12);
    Map<String, AuctionPrice> prices(double cabbage) => {'CABBAGE': AuctionPrice('CABBAGE', cabbage, now)};

    test('알림을 걸고 시세가 목표에 닿으면 한 번만 울린다', () async {
      final c = await make();
      final n = c.read(priceAlertsProvider.notifier);
      n.set('CABBAGE', above: true, target: 2000);
      expect(c.read(priceAlertsProvider)['CABBAGE']!.fired, isFalse);

      expect(n.check(prices(1900)), isEmpty); // 아직 못 닿음
      final first = n.check(prices(2100));
      expect(first.map((e) => e.code), ['CABBAGE']);
      expect(c.read(priceAlertsProvider)['CABBAGE']!.fired, isTrue);
      expect(n.check(prices(2300)), isEmpty); // 같은 알림은 또 울리지 않는다

      // 다시 걸면 새로 시작한다
      n.set('CABBAGE', above: true, target: 2000);
      expect(n.check(prices(2300)).length, 1);
    });

    test('알림을 끄면 사라지고, 저장된 값은 앱을 다시 켜도 남는다', () async {
      final c = await make();
      final n = c.read(priceAlertsProvider.notifier);
      final prefs = c.read(prefsProvider);
      n.set('APPLE', above: false, target: 3000);
      final saved = prefs.getString(priceAlertsKey)!;
      expect(decodeAlerts(saved)['APPLE']!.target, 3000);

      n.clear('APPLE');
      expect(c.read(priceAlertsProvider), isEmpty);
      expect(decodeAlerts(prefs.getString(priceAlertsKey)), isEmpty);
      n.clear('APPLE'); // 없는 알림을 또 꺼도 문제없다

      // 새로 시작한 앱에서도 저장된 알림을 읽는다
      final again = await make({priceAlertsKey: saved});
      expect(again.read(priceAlertsProvider)['APPLE']!.above, isFalse);
    });
  });
}
