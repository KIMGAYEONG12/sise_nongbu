// 작물 고르는 창의 검색·갈래 고르기
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/views/farm_actions.dart';

void main() {
  test('전체는 모든 작물, 갈래를 고르면 그 종류만', () {
    expect(filterCrops('', '전체').length, crops.length);
    for (final k in ['채소', '과일', '특수']) {
      final list = filterCrops('', k);
      expect(list, isNotEmpty);
      expect(list.every((c) => c.kind == k), isTrue);
    }
    expect(filterCrops('', '채소').length + filterCrops('', '과일').length + filterCrops('', '특수').length, crops.length);
  });

  test('이름으로 검색하고, 띄어쓰기는 무시한다', () {
    expect(filterCrops('무화과', '전체').map((c) => c.code), ['FIG']);
    expect(filterCrops('무 화과', '전체').map((c) => c.code), ['FIG']);
    expect(filterCrops('무화과', '채소'), isEmpty); // 무화과는 과일
    expect(filterCrops('없는작물', '전체'), isEmpty);
  });
}
