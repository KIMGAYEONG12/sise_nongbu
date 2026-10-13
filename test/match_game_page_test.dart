// 작물 매칭 화면: 시작 안내가 작은 화면에서도 넘치지 않고, 난이도마다 판과 작물 종류가 달라지며, 시작하면 칸을 눌러 플레이할 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart' show cropOf;
import 'package:sise_nongbu/core/match_logic.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/match_game_page.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';

void main() {
  for (final size in const [Size(360, 640), Size(411, 891)]) {
    for (var lv = 0; lv < matchLevels.length; lv++) {
      testWidgets('작물 매칭 ${size.width.toInt()}x${size.height.toInt()} ${matchLevels[lv].name}: 넘침 없이 시작해서 칸을 누를 수 있다', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          overrides: [userDataProvider.overrideWithValue(const UserData({}))],
          child: const MaterialApp(home: MatchGamePage()),
        ));
        await tester.pump();
        expect(find.text('시작하기'), findsOneWidget);
        expect(tester.takeException(), isNull); // RenderFlex overflow 같은 오류가 없어야 한다
        final level = matchLevels[lv];
        await tester.tap(find.text(level.name));
        await tester.pump();
        await tester.ensureVisible(find.text('시작하기'));
        await tester.pump();
        await tester.tap(find.text('시작하기'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('시작하기'), findsNothing);
        // 짝 맞추기 판: size×size 칸 (칸 수가 홀수면 가운데 한 칸은 비어 있다) + 위쪽 시세 배율 안내(작물 종류마다 1개)
        final (gr, gc) = matchGridFor(level.size * level.size, level.kinds); // 작물 종류에 맞춰 칸이 모두 차는 크기
        final tiles = gr * gc;
        expect(find.byType(CropArt), findsNWidgets(tiles + level.kinds));
        await tester.tap(find.byType(CropArt).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // 가만히 몇 초 있으면 시간이 흐른다 (타이머 정리를 위해 화면을 닫는다)
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('시작 전에 플레이할 작물을 직접 고를 수 있다 (3~6종)', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [userDataProvider.overrideWithValue(const UserData({}))],
      child: const MaterialApp(home: MatchGamePage()),
    ));
    await tester.pump();
    expect(find.text('플레이할 작물 고르기 (4종 · 3~6종)'), findsOneWidget);
    // 쉬움 기본은 배추·감자·토마토·사과. 사과를 끄고 양파를 켜면 여전히 4종이다.
    await tester.ensureVisible(find.text('사과'));
    await tester.pump();
    await tester.tap(find.text('사과'));
    await tester.pump();
    expect(find.text('플레이할 작물 고르기 (3종 · 3~6종)'), findsOneWidget);
    await tester.ensureVisible(find.text('배추'));
    await tester.pump();
    await tester.tap(find.text('배추')); // 3종 아래로는 못 줄인다
    await tester.pump();
    expect(find.text('플레이할 작물 고르기 (3종 · 3~6종)'), findsOneWidget);
    await tester.ensureVisible(find.text('양파'));
    await tester.pump();
    await tester.tap(find.text('양파'));
    await tester.ensureVisible(find.text('무'));
    await tester.pump();
    await tester.tap(find.text('무'));
    await tester.pump();
    expect(find.text('플레이할 작물 고르기 (5종 · 3~6종)'), findsOneWidget);
    await tester.ensureVisible(find.text('시작하기'));
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pump(const Duration(milliseconds: 300));
    // 5종이면 5줄×4칸 = 20칸(작물마다 4칸) + 위쪽 시세 배율 안내 5개
    expect(find.byType(CropArt), findsNWidgets(20 + 5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(360, 640), Size(411, 891), Size(320, 600)]) {
    testWidgets('작물 고르기 목록은 모든 줄의 개수가 똑같다 (${size.width.toInt()}폭)', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [userDataProvider.overrideWithValue(const UserData({}))],
        child: const MaterialApp(home: MatchGamePage()),
      ));
      await tester.pump();
      // 칩의 이름 글자가 놓인 높이가 같으면 같은 줄이다
      final ys = [for (final code in matchCrops) tester.getTopLeft(find.text(cropOf(code).name)).dy];
      final perRow = <int>[];
      for (final y in ys) {
        perRow.add(ys.where((o) => (o - y).abs() < 1).length);
      }
      expect(tester.takeException(), isNull);
      expect(perRow.reduce((a, b) => a < b ? a : b), greaterThan(1), reason: '한 줄에 하나만 있는 작물이 없다');
      final most = perRow.reduce((a, b) => a > b ? a : b), least = perRow.reduce((a, b) => a < b ? a : b);
      expect(most, least, reason: '모든 줄의 작물 개수가 똑같다 (21종은 3의 배수 줄 또는 7의 배수 줄)');
    });
  }

  test('작물 고르기 줄 구성: 약수가 있으면 모든 줄이 같고, 없으면 차이가 1개 이하', () {
    for (final width in [260.0, 300.0, 330.0, 360.0, 400.0, 500.0]) {
      final l = matchPickerLayout(21, width);
      expect(l.rows.reduce((a, b) => a + b), 21);
      expect(l.rows.toSet().length, 1, reason: '21종 · $width폭 → ${l.rows}');
      expect(l.chip, inInclusiveRange(46, 84));
    }
    expect(matchPickerLayout(21, 300).rows, List<int>.filled(7, 3)); // 좁으면 3칸 × 7줄
    expect(matchPickerLayout(21, 400).rows, List<int>.filled(3, 7)); // 넓으면 7칸 × 3줄
    expect(matchPickerLayout(20, 330).rows, List<int>.filled(4, 5)); // 20종이면 5칸 × 4줄
    for (final n in [1, 2, 7, 13, 23, 29]) {
      final l = matchPickerLayout(n, 330);
      expect(l.rows.reduce((a, b) => a + b), n);
      expect(l.rows.reduce((a, b) => a > b ? a : b) - l.rows.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1), reason: '$n종 → ${l.rows}');
    }
  });
}
