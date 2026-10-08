// 하우스 모양이 레벨에 따라 4단계로 바뀌는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/greenhouse_art.dart';

void main() {
  test('레벨 → 하우스 단계', () {
    expect([for (final l in [1, 2, 3, 4, 5, 6, 7, 20]) greenhouseTier(l)], [0, 0, 1, 1, 2, 2, 3, 3]);
  });

  testWidgets('하우스 4단계가 모두 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1200, 400);
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
            for (var t = 0; t < 4; t++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: AspectRatio(aspectRatio: 260 / 176, child: CustomPaint(painter: GreenhousePainter(count: t + 1, tier: t))))),
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
