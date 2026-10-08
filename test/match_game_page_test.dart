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
        await tester.tap(find.text('시작하기'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('시작하기'), findsNothing);
        // 판 size×size 칸 + 위쪽 시세 배율 안내(작물 종류마다 1개)
        expect(find.byType(CropArt), findsNWidgets(level.size * level.size + level.kinds));
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
}
