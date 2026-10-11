// 작물 매칭(3개 맞추기) 게임의 순수 Dart 규칙. 화면과 분리해 단위 테스트한다.
import 'dart:math';

/// 오늘 시세가 전일보다 오른 작물일수록 점수를 더 준다 (상승률 10%면 2배, 오르지 않았거나 시세를 모르면 1배).
double matchWeight(double? changePct) => 1 + ((changePct ?? 0).clamp(0, 10) / 10);

class MatchResult {
  const MatchResult(this.cleared, this.combos, [this.byKind = const {}]);
  final int cleared; // 지워진 칸 수
  final int combos; // 연쇄 횟수
  final Map<int, int> byKind; // 작물 종류별로 지워진 칸 수

  int get score => cleared * 10 + (combos > 1 ? (combos - 1) * 20 : 0);

  /// 작물마다 다른 배율([weights])을 곱한 점수. 배율이 모두 1이면 [score]와 같다.
  int scoreWith(List<double> weights) {
    if (byKind.isEmpty) return score;
    var s = 0.0;
    byKind.forEach((k, n) => s += n * 10 * (k < weights.length ? weights[k] : 1.0));
    return s.round() + (combos > 1 ? (combos - 1) * 20 : 0);
  }
}

class MatchBoard {
  MatchBoard(this.rows, this.cols, this.kinds, [Random? rng])
      : _rng = rng ?? Random(),
        cells = List.generate(rows, (_) => List<int>.filled(cols, -1)) {
    fillNoMatches();
  }

  final int rows, cols, kinds;
  final Random _rng;
  final List<List<int>> cells;

  int at(int r, int c) => cells[r][c];

  /// 처음부터 3개가 이어진 곳이 없도록 채운다.
  void fillNoMatches() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        int v;
        do {
          v = _rng.nextInt(kinds);
        } while ((c >= 2 && cells[r][c - 1] == v && cells[r][c - 2] == v) ||
            (r >= 2 && cells[r - 1][c] == v && cells[r - 2][c] == v));
        cells[r][c] = v;
      }
    }
  }

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  bool adjacent(int r1, int c1, int r2, int c2) => (r1 - r2).abs() + (c1 - c2).abs() == 1;

  void _swap(int r1, int c1, int r2, int c2) {
    final t = cells[r1][c1];
    cells[r1][c1] = cells[r2][c2];
    cells[r2][c2] = t;
  }

  /// 3개 이상 이어진 칸의 위치(r * cols + c) 집합
  Set<int> findMatches() {
    final out = <int>{};
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        final v = cells[r][c];
        var e = c;
        while (e + 1 < cols && cells[r][e + 1] == v) {
          e++;
        }
        if (v >= 0 && e - c + 1 >= 3) {
          for (var k = c; k <= e; k++) {
            out.add(r * cols + k);
          }
        }
        c = e + 1;
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        final v = cells[r][c];
        var e = r;
        while (e + 1 < rows && cells[e + 1][c] == v) {
          e++;
        }
        if (v >= 0 && e - r + 1 >= 3) {
          for (var k = r; k <= e; k++) {
            out.add(k * cols + c);
          }
        }
        r = e + 1;
      }
    }
    return out;
  }

  void _gravityAndRefill() {
    for (var c = 0; c < cols; c++) {
      final col = <int>[];
      for (var r = rows - 1; r >= 0; r--) {
        if (cells[r][c] >= 0) col.add(cells[r][c]);
      }
      for (var r = rows - 1, i = 0; r >= 0; r--, i++) {
        cells[r][c] = i < col.length ? col[i] : _rng.nextInt(kinds);
      }
    }
  }

  /// 맞춰진 칸을 지우고 채우기를 더 이상 맞출 곳이 없을 때까지 반복한다.
  MatchResult resolve() {
    var cleared = 0, combos = 0;
    final byKind = <int, int>{};
    while (true) {
      final m = findMatches();
      if (m.isEmpty) break;
      combos++;
      cleared += m.length;
      for (final idx in m) {
        final k = cells[idx ~/ cols][idx % cols];
        byKind[k] = (byKind[k] ?? 0) + 1;
        cells[idx ~/ cols][idx % cols] = -1;
      }
      _gravityAndRefill();
    }
    return MatchResult(cleared, combos, byKind);
  }

  /// 인접한 두 칸을 바꿔 본다. 맞춰지면 처리하고 결과를, 아니면 되돌리고 null을 돌려준다.
  MatchResult? trySwap(int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2) || !adjacent(r1, c1, r2, c2)) return null;
    _swap(r1, c1, r2, c2);
    if (findMatches().isEmpty) {
      _swap(r1, c1, r2, c2);
      return null;
    }
    return resolve();
  }

  /// 바꿔서 맞출 수 있는 수가 하나라도 있는지
  bool hasMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (c + 1 < cols) {
          _swap(r, c, r, c + 1);
          final ok = findMatches().isNotEmpty;
          _swap(r, c, r, c + 1);
          if (ok) return true;
        }
        if (r + 1 < rows) {
          _swap(r, c, r + 1, c);
          final ok = findMatches().isNotEmpty;
          _swap(r, c, r + 1, c);
          if (ok) return true;
        }
      }
    }
    return false;
  }

  /// 바꾸면 맞춰지는 인접한 두 칸 하나를 (r1, c1, r2, c2)로 알려준다. 없으면 null. (힌트용)
  (int, int, int, int)? findHint() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final d in const [(0, 1), (1, 0)]) {
          final r2 = r + d.$1, c2 = c + d.$2;
          if (!inBounds(r2, c2)) continue;
          _swap(r, c, r2, c2);
          final ok = findMatches().isNotEmpty;
          _swap(r, c, r2, c2);
          if (ok) return (r, c, r2, c2);
        }
      }
    }
    return null;
  }

  /// 수가 없을 때 섞는다.
  void shuffle() {
    for (var tries = 0; tries < 50; tries++) {
      final all = <int>[for (final row in cells) ...row]..shuffle(_rng);
      var i = 0;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          cells[r][c] = all[i++];
        }
      }
      if (findMatches().isEmpty && hasMove()) return;
    }
    do {
      fillNoMatches();
    } while (!hasMove());
  }
}

/// 짝 맞추기 판: 같은 작물 두 칸을 차례로 누르면 둘 다 사라지고, 판이 모두 비면 다음 판으로 넘어간다.
/// (양배추는 양배추끼리, 토마토는 토마토끼리, 감자는 감자끼리)
/// 칸 수가 홀수(예: 5×5)면 가운데 한 칸은 비워 두어서 항상 모든 칸을 짝지을 수 있다.
class PairBoard {
  PairBoard(this.rows, this.cols, this.kinds, [Random? rng])
      : _rng = rng ?? Random(),
        cells = List<int>.filled(rows * cols, -1) {
    _fill();
  }

  /// 저장해 둔 판을 되살린다. [cells] 길이가 맞지 않거나 값이 범위를 벗어나면 null.
  static PairBoard? restore(int rows, int cols, int kinds, List<int> cells) {
    if (cells.length != rows * cols) return null;
    if (cells.any((v) => v < -1 || v >= kinds)) return null;
    final b = PairBoard(rows, cols, kinds);
    for (var i = 0; i < cells.length; i++) {
      b.cells[i] = cells[i];
    }
    return b;
  }

  final int rows, cols, kinds;
  final Random _rng;

  /// 칸마다 작물 번호 (비어 있으면 -1). 위치는 r * cols + c.
  final List<int> cells;

  int at(int r, int c) => cells[r * cols + c];

  /// 남은 칸 수
  int get remaining => cells.where((v) => v >= 0).length;

  bool get cleared => remaining == 0;

  void _fill() {
    final total = rows * cols;
    final slots = <int>[for (var i = 0; i < total; i++) i];
    if (total.isOdd) slots.remove(total ~/ 2); // 가운데 칸은 비운다
    slots.shuffle(_rng);
    // 모든 작물이 고르게 나오도록 짝을 돌아가며 나눠 준다
    final start = _rng.nextInt(kinds);
    for (var p = 0; p < slots.length ~/ 2; p++) {
      final kind = (start + p) % kinds;
      cells[slots[p * 2]] = kind;
      cells[slots[p * 2 + 1]] = kind;
    }
  }

  /// 두 칸이 서로 다른 칸이고, 둘 다 차 있고, 같은 작물이면 짝이 맞는다.
  bool canMatch(int a, int b) => a != b && a >= 0 && b >= 0 && a < cells.length && b < cells.length && cells[a] >= 0 && cells[a] == cells[b];

  /// 짝이 맞으면 두 칸을 비우고 true, 아니면 false.
  bool match(int a, int b) {
    if (!canMatch(a, b)) return false;
    cells[a] = -1;
    cells[b] = -1;
    return true;
  }

  /// 맞출 수 있는 짝 하나를 (칸 번호 a, 칸 번호 b)로 알려준다. 없으면 null. (힌트용)
  (int, int)? findHint() {
    final first = <int, int>{};
    for (var i = 0; i < cells.length; i++) {
      final k = cells[i];
      if (k < 0) continue;
      final j = first[k];
      if (j != null) return (j, i);
      first[k] = i;
    }
    return null;
  }
}
