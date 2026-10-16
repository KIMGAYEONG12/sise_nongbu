// 작물 매칭(짝 맞추기): 같은 작물끼리만 맞고, 판을 다 비우면 끝나며, 저장하고 나가면 "이어서 하기"로 다시 할 수 있다.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sise_nongbu/core/game_rules.dart' show crops;
import 'package:sise_nongbu/core/match_logic.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/match_game_page.dart';

void main() {
  cropPickerTests();
  group('PairBoard', () {
    test('모든 작물이 똑같은 짝수 개라서 하나도 남지 않고 전부 짝지을 수 있다 (홀수 칸이면 가운데는 빈칸)', () {
      for (final size in [5, 6]) {
        for (var kinds = 3; kinds <= 6; kinds++) {
          for (var seed = 0; seed < 20; seed++) {
            final b = PairBoard(size, size, kinds, Random(seed));
            final count = <int, int>{};
            for (final v in b.cells) {
              if (v >= 0) count[v] = (count[v] ?? 0) + 1;
            }
            expect(count.length, kinds, reason: '모든 작물이 나온다');
            expect(count.values.toSet().length, 1, reason: '작물마다 개수가 같다');
            expect(count.values.first.isEven, isTrue);
            final maxPairs = (size * size) ~/ 2;
            expect(b.remaining, (maxPairs ~/ kinds) * kinds * 2);
            if (size.isOdd) expect(b.cells[size * size ~/ 2], -1);
          }
        }
      }
    });

    test('판 크기는 작물 종류에 맞춰져서 칸이 모두 차고, 작물마다 똑같은 짝수 개이며 하나도 남지 않는다', () {
      for (final target in [24, 36]) {
        for (var kinds = 3; kinds <= 6; kinds++) {
          final (rows, cols) = matchGridFor(target, kinds);
          expect((rows * cols) % (2 * kinds), 0, reason: '$kinds종 · $target칸 → $rows×$cols');
          expect(cols, inInclusiveRange(4, 6));
          expect(rows, inInclusiveRange(4, 8));
          for (var seed = 0; seed < 10; seed++) {
            final b = PairBoard(rows, cols, kinds, Random(seed));
            expect(b.cells.every((v) => v >= 0), isTrue, reason: '빈칸이 없다');
            final count = <int, int>{};
            for (final v in b.cells) {
              count[v] = (count[v] ?? 0) + 1;
            }
            expect(count.length, kinds);
            expect(count.values.toSet().length, 1, reason: '작물마다 개수가 같다');
            expect(count.values.first.isEven, isTrue);
            // 모든 작물을 짝지어 끝까지 맞출 수 있다
            var guard = 0;
            for (var h = b.findHint(); h != null && guard < 1000; h = b.findHint(), guard++) {
              expect(b.match(h.$1, h.$2), isTrue);
            }
            expect(b.cleared, isTrue);
          }
        }
      }
      // 대표 크기: 쉬움 4종 → 24칸, 5종 → 20칸, 보통 3종 → 36칸
      expect(matchGridFor(24, 4), (6, 4));
      expect(matchGridFor(24, 5), (5, 4));
      expect(matchGridFor(36, 3), (6, 6));
    });

    test('같은 작물끼리만 맞고, 다른 작물·같은 칸·빈 칸은 안 맞는다', () {
      final b = PairBoard(2, 2, 2);
      b.cells.setAll(0, [0, 1, 0, 1]);
      expect(b.canMatch(0, 1), isFalse); // 양배추 + 토마토
      expect(b.canMatch(0, 0), isFalse); // 같은 칸
      expect(b.match(0, 1), isFalse);
      expect(b.remaining, 4);
      expect(b.match(0, 2), isTrue); // 양배추끼리
      expect(b.cells, [-1, 1, -1, 1]);
      expect(b.canMatch(0, 2), isFalse); // 이미 비었다
      expect(b.findHint(), (1, 3));
      expect(b.cleared, isFalse);
      expect(b.match(1, 3), isTrue);
      expect(b.cleared, isTrue);
      expect(b.findHint(), isNull);
    });

    test('저장한 판을 그대로 되살린다 (모양이 안 맞으면 null)', () {
      final b = PairBoard(5, 5, 4, Random(3));
      final r = PairBoard.restore(5, 5, 4, List<int>.of(b.cells))!;
      expect(r.cells, b.cells);
      expect(PairBoard.restore(5, 5, 4, [0, 1]), isNull);
      expect(PairBoard.restore(5, 5, 4, List<int>.filled(25, 9)), isNull);
    });

    test('저장 글이 깨졌거나 규칙에 안 맞으면 이어 하기를 쓰지 않는다', () {
      final (gr, gc) = matchGridFor(25, 4); // 쉬움(25칸 목표)에서 4종이면 6줄×4칸
      final b = PairBoard(gr, gc, 4, Random(1));
      final ok = MatchSave(level: 0, stage: 2, score: 120, left: 90, streak: 1, cells: b.cells, crops: matchCrops.take(4).toList());
      final back = MatchSave.fromJson(ok.toJson())!;
      expect([back.level, back.stage, back.score, back.left, back.streak], [0, 2, 120, 90, 1]);
      expect(back.cells, b.cells);
      expect(MatchSave.fromJson('엉터리'), isNull);
      expect(MatchSave.fromJson({...ok.toJson(), 'level': 9}), isNull);
      expect(MatchSave.fromJson({...ok.toJson(), 'left': 0}), isNull);
      expect(MatchSave.fromJson({...ok.toJson(), 'cells': [1, 2, 3]}), isNull);
    });
  });

  testWidgets('게임 도중에 나가면 저장하고 나갈 수 있고, 다시 오면 이어서 할 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<void> open() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [userDataProvider.overrideWithValue(const UserData({}))],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MatchGamePage())), child: const Text('열기'))),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('이어서 하기'), findsNothing);
    await tester.ensureVisible(find.text('시작하기'));
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5)); // 시간이 조금 흐른다

    // 뒤로 가기를 누르면 물어본다. 계속하기를 누르면 게임이 그대로 이어진다.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('게임을 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // 닫히는 연출
    expect(find.text('게임을 나갈까요?'), findsNothing);
    expect(find.text('시작하기'), findsNothing);

    // 저장하고 나가기
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하고 나가기'));
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget); // 게임 화면이 닫혔다

    // 다시 들어오면 저장된 게임을 이어서 할 수 있다
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('이어서 하기'), findsOneWidget);
    expect(find.text('새로 시작하기'), findsOneWidget);
    await tester.ensureVisible(find.text('이어서 하기'));
    await tester.pump();
    await tester.tap(find.text('이어서 하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('이어서 하기'), findsNothing);
    expect(tester.takeException(), isNull);

    // 저장 없이 나가면 저장분이 남지 않는다 (이어 하기를 쓰면 저장분은 사라진다)
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장 안 하고 나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('이어서 하기'), findsNothing);
    expect(find.text('시작하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

// 고른 작물만 판에 나오고, 3~6종이어야 하며, 저장에도 함께 남는다.
void cropPickerTests() {
  test('작물 목록 규칙: 3~6종, 겹치지 않고, 모르는 작물은 안 된다', () {
    expect(validMatchCrops(['CABBAGE', 'POTATO', 'TOMATO']), isTrue);
    expect(validMatchCrops(matchCrops.take(6).toList()), isTrue);
    expect(validMatchCrops(matchCrops.take(7).toList()), isFalse); // 최대 6종
    expect(validMatchCrops(['FIG', 'CORN', 'STRAWBERRY']), isTrue); // 새로 열린 작물도 고를 수 있다
    expect(matchCrops.toSet().length, matchCrops.length);
    expect(matchCrops.length, crops.length);
    expect(validMatchCrops(['CABBAGE', 'POTATO']), isFalse);
    expect(validMatchCrops(['CABBAGE', 'CABBAGE', 'POTATO']), isFalse);
    expect(validMatchCrops(['CABBAGE', 'POTATO', 'DURIAN']), isFalse); // 게임에 없는 작물
  });

  test('고른 작물이 저장에 남고, 작물 목록이 없는 예전 저장은 기본 작물로 읽는다', () {
    final crops = ['POTATO', 'TOMATO', 'APPLE'];
    final (gr, gc) = matchGridFor(25, crops.length);
    final b = PairBoard(gr, gc, crops.length, Random(2));
    final save = MatchSave(level: 0, stage: 1, score: 0, left: 60, streak: 0, cells: b.cells, crops: crops);
    expect(MatchSave.fromJson(save.toJson())!.crops, crops);
    final old = Map<String, dynamic>.from(save.toJson())..remove('crops');
    expect(MatchSave.fromJson(old)!.crops, matchCrops.take(4).toList()); // 목록이 없으면 난이도 기본 작물
    final (gr4, gc4) = matchGridFor(25, 4);
    final b4 = PairBoard(gr4, gc4, 4, Random(2));
    final old4 = Map<String, dynamic>.from(MatchSave(level: 0, stage: 1, score: 0, left: 60, streak: 0, cells: b4.cells, crops: matchCrops.take(4).toList()).toJson())..remove('crops');
    expect(MatchSave.fromJson(old4)!.crops, matchCrops.take(4).toList());
  });
}
