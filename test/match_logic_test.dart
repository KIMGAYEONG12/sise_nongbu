import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/match_logic.dart';

void main() {
  test('새 판에는 처음부터 이어진 3개가 없다', () {
    for (var seed = 0; seed < 20; seed++) {
      final b = MatchBoard(7, 6, 5, Random(seed));
      expect(b.findMatches(), isEmpty);
    }
  });

  test('가로 3개를 찾는다', () {
    final b = MatchBoard(3, 3, 5, Random(1));
    b.cells[0] = [1, 1, 1];
    b.cells[1] = [2, 3, 2];
    b.cells[2] = [3, 2, 3];
    expect(b.findMatches(), {0, 1, 2});
  });

  test('세로 4개를 찾는다', () {
    final b = MatchBoard(4, 3, 5, Random(1));
    b.cells[0] = [4, 0, 1];
    b.cells[1] = [3, 0, 2];
    b.cells[2] = [4, 0, 1];
    b.cells[3] = [3, 0, 2];
    expect(b.findMatches(), {1, 4, 7, 10});
  });

  test('맞춰지지 않는 교환은 되돌린다', () {
    final b = MatchBoard(3, 3, 5, Random(1));
    b.cells[0] = [0, 1, 2];
    b.cells[1] = [3, 4, 0];
    b.cells[2] = [1, 2, 3];
    final before = [for (final r in b.cells) [...r]];
    expect(b.trySwap(0, 0, 0, 1), isNull);
    expect(b.cells, before);
  });

  test('멀리 있는 칸은 바꿀 수 없다', () {
    final b = MatchBoard(3, 3, 5, Random(1));
    expect(b.trySwap(0, 0, 2, 2), isNull);
  });

  test('맞춰지는 교환은 점수를 주고 판에 3개 이음이 남지 않는다', () {
    final b = MatchBoard(4, 4, 5, Random(3));
    b.cells[0] = [1, 1, 2, 0];
    b.cells[1] = [3, 4, 1, 3];
    b.cells[2] = [0, 3, 4, 2];
    b.cells[3] = [2, 0, 3, 4];
    final r = b.trySwap(0, 2, 1, 2);
    expect(r, isNotNull);
    expect(r!.cleared, greaterThanOrEqualTo(3));
    expect(r.score, greaterThanOrEqualTo(30));
    expect(b.findMatches(), isEmpty);
  });

  test('섞은 뒤에는 둘 수 있는 수가 있다', () {
    final b = MatchBoard(5, 5, 5, Random(7));
    b.shuffle();
    expect(b.findMatches(), isEmpty);
    expect(b.hasMove(), isTrue);
  });
}
