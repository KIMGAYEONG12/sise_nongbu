// 레벨 업 창과 판매 완료 창이 작은 화면에서도 넘침 없이 뜨고, 작물 이름 문구가 맞게 나온다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/views/home_shell.dart';
import 'package:sise_nongbu/views/sell_page.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';

void main() {
  for (final size in const [Size(360, 640), Size(411, 891)]) {
    testWidgets('레벨 업 창 ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showLevelUpDialog(c, 4, 5, levelInfo(250)), child: const Text('열기'))))),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Lv.5'), findsOneWidget);
      expect(find.text('레벨이 올랐어요!'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('레벨이 올랐어요!'), findsNothing);
    });
  }

  testWidgets('판매 완료 창: 토마토 그림과 "토마토가 판매되었습니다!"', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showSoldDialog(c, ['TOMATO'], ['토마토'], 38000, 5), child: const Text('열기'))))),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CropArt), findsOneWidget);
    expect(find.text('토마토가 판매되었습니다!'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('판매 완료 창: 여러 작물도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showSoldDialog(c, ['TOMATO', 'CABBAGE', 'POTATO', 'APPLE'], ['토마토', '배추', '감자', '사과'], 120000, 20), child: const Text('열기'))))),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CropArt), findsNWidgets(4));
    expect(find.text('토마토 외 3종이 판매되었습니다!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
