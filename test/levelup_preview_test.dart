// 레벨 업 창이 시안처럼 그려지는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/views/home_shell.dart';
import 'preview_font.dart';

void main() {
  for (final withReward in [true, false]) {
    testWidgets('레벨 업 창 그림 ${withReward ? '(보상 있음)' : '(보상 없음)'}', (tester) async {
      if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
      tester.view.physicalSize = const Size(411, 891) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showLevelUpDialog(c, 8, 9, levelInfo(1500), reward: withReward ? const LevelUpReward(points: 500, seedCode: 'APPLE', seedCount: 1) : null), child: const Text('열기'))))),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        await precacheImage(const AssetImage('assets/images/levelup_card_hd.png'), tester.element(find.byType(Dialog)));
      });
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Lv.9'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
      expect(find.text(withReward ? '500P' : '레벨이 올랐어요!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final dir = Platform.environment['PREVIEW_DIR'];
      if (dir != null) {
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/levelup_${withReward ? 'reward' : 'plain'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}
