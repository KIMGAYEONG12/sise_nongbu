// 하우스 모양이 레벨에 따라 4단계로 바뀌는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/greenhouse_art.dart';

void main() {
  stageTests();
  test('레벨 → 하우스 단계', () {
    expect([for (final l in [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13, 30]) greenhouseTier(l)], [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
    expect(greenhouseNames.length, greenhouseMaxTier + 1);
    expect(greenhouseNames.toSet().length, greenhouseNames.length); // 단계마다 이름이 다르다
    // 하우스를 한 채 지을 때마다 한 단계씩 커지고 이름이 바뀐다 (레벨로 오른 모양 단계가 더해진다)
    expect(greenhouseStage(8, 0), 0); // 하우스가 없으면 0
    expect(greenhouseStage(1, 1), 1);
    expect(greenhouseStage(1, 5), 5);
    expect(greenhouseStage(8, 1), 4); // Lv.8은 모양 단계 3이 더해진다
    expect(greenhouseStageName(1), '비닐하우스');
    expect(greenhouseStageName(2), '대형 비닐하우스');
    expect(greenhouseStageName(11), 'AI 퀀텀 팜');
    expect(greenhouseStageName(12), '나노 바이오 팜'); // AI 퀀텀 팜 다음에도 더 좋은 이름이 이어진다
    expect(greenhouseStageName(14), '플라즈마 에너지 팜');
    expect(greenhouseStageName(20), '우주 문명 농장');
    expect(greenhouseStageName(21), '은하 연합 농장'); // 20단계 뒤에는 세대 숫자 대신 새 이름이 이어진다
    final names = [for (var s = 1; s <= 900; s++) greenhouseStageName(s)];
    expect(names.toSet().length, names.length, reason: '900단계까지 이름이 겹치지 않아요');
    expect(names.any((e) => e.contains('세대')), isFalse);
    expect(greenhouseStageName(200).contains('200'), isFalse);
    expect(greenhouseStageNames.toSet().length, greenhouseStageNames.length);
    for (var s = 1; s < 40; s++) {
      expect(greenhouseStageName(s) == greenhouseStageName(s + 1), isFalse, reason: '$s단계와 ${s + 1}단계 이름이 달라야 해요');
    }
    expect([for (var s = 1; s <= 12; s++) greenhouseTierOfStage(s)], [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
    expect(greenhouseTierFor(8, 10), 5);
    expect(greenhouseTierFor(1, -2), 0);
    expect(greenhouseSizeScale(1), 1.0);
    expect(greenhouseSizeScale(2), closeTo(1.05, 1e-9));
    expect(greenhouseSizeScale(100), 1.5);
    for (var s = 1; s < 10; s++) {
      expect(greenhouseSizeScale(s + 1), greaterThan(greenhouseSizeScale(s)), reason: '하우스를 지을 때마다 커져야 해요');
    }
  });

  testWidgets('하우스 6단계가 모두 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1800, 400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF86C75A),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Row(children: [
            for (var t = 0; t <= greenhouseMaxTier; t++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: AspectRatio(aspectRatio: 260 / 176, child: CustomPaint(painter: GreenhousePainter(count: t + 1, tier: t))))),
          ]),
        ),
      ),
    ));
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/greenhouses.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}

// 11~20단계 하우스(첨단 장치가 하나씩 더 붙는다)가 모두 에러 없이 그려지는지 확인한다. 위성은 15단계부터.
void stageTests() {
  testWidgets('11~20단계 하우스가 모두 그려진다', (tester) async {
    tester.view.physicalSize = const Size(2400, 560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF86C75A),
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          child: Row(children: [
            for (var s = 11; s <= 20; s++)
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: AspectRatio(aspectRatio: 260 / 176, child: CustomPaint(painter: GreenhousePainter(count: s, tier: greenhouseTierOfStage(s), name: greenhouseStageName(s), stage: s))))),
          ]),
        ),
      ),
    ));
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/greenhouse_stages.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
