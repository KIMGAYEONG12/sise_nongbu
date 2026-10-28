import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/home_decor_rules.dart';
import 'package:sise_nongbu/core/home_rules.dart';
import 'package:sise_nongbu/core/progress_rules.dart';

void main() {
  test('방 이름은 저택과 하우스·아파트가 따로 저장된다', () {
    expect(decorRoomKey(mansion: true, room: HomeRoom.living), 'mansion_living');
    expect(decorRoomKey(mansion: false, room: HomeRoom.kitchen), 'home_kitchen');
  });

  test('저장된 가구를 읽을 때 잘못된 값은 건너뛰고 바닥 안쪽으로 맞춘다', () {
    final saved = {
      'home_living': [
        {'k': 'plant', 'x': .5, 'y': .4},
        {'k': 'unknown', 'x': .5, 'y': .5},
        {'k': 'piano', 'x': 2, 'y': -1},
        'broken',
      ],
    };
    final list = decorOfRoom(saved, 'home_living');
    expect(list.length, 2);
    expect(list[0].key, 'plant');
    expect(list[1].x, .94);
    expect(list[1].y, .08);
    expect(decorOfRoom(null, 'home_living'), isEmpty);
    expect(decorOfRoom(saved, 'home_bedroom'), isEmpty);
  });

  test('가구는 앞쪽(바닥 x+y가 큰 것)이 나중에 그려진다', () {
    const list = [DecorPlacement('plant', .9, .9), DecorPlacement('rug', .1, .1), DecorPlacement('bear', .5, .5)];
    expect(decorDrawOrder(list), [1, 2, 0]);
  });

  test('저장하는 값은 짧은 숫자로 바뀌고 다시 읽으면 같다', () {
    const p = DecorPlacement('cat', .123456, .654321);
    final back = DecorPlacement.fromMap(p.toMap())!;
    expect(back.key, 'cat');
    expect(back.x, closeTo(.123, 1e-9));
    expect(back.y, closeTo(.654, 1e-9));
  });

  test('편의 시설은 아파트 단계가 될 때만 쓸 수 있고 하루 한 번이다', () {
    expect(canUseFacility(4, 0), isFalse); // 하우스에는 편의 시설이 없다
    expect(canUseFacility(5, 0), isTrue); // 기본 아파트: 단지 카페
    expect(canUseFacility(5, 1), isFalse);
    expect(canUseFacility(10, 5), isTrue); // 스카이 아파트: 전망대까지
    expect(facilityPerks.length, homeFacilities.length);
    final now = DateTime.utc(2026, 10, 28, 3);
    final used = markClaimed(null, dayTag(now), facilityId(0));
    expect(facilityUsedToday(used, 0, now), isTrue);
    expect(facilityUsedToday(used, 1, now), isFalse);
    expect(facilityUsedToday(used, 0, now.add(const Duration(days: 1))), isFalse); // 다음 날은 다시 이용
    expect(facilityPerks[0].rewardText, '물통 3개');
  });
}
