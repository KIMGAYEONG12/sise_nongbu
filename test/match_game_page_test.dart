// 작물 매칭 화면: 시작 안내가 작은 화면에서도 넘치지 않고, 난이도마다 판과 작물 종류가 달라지며, 시작하면 칸을 눌러 플레이할 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        final tiles = level.size * level.size - (level.size.isOdd ? 1 : 0);
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
    // 5×5 판은 24칸 + 위쪽 시세 배율 안내 5개
    expect(find.byType(CropArt), findsNWidgets(24 + 5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
