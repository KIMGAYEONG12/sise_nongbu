// 작물 고르는 창: 갈래 버튼 목록과 한 글자 검색
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/views/farm_actions.dart';

void main() {
  test('갈래 버튼은 전체·채소·과일·특수 네 개', () {
    expect(plantKinds, ['전체', '채소', '과일', '특수']);
  });

  test('"무"로 검색하면 무·무화과가 나온다', () {
    expect(filterCrops('무', '전체').map((c) => c.name).toSet(), {'무', '무화과'});
  });

}
