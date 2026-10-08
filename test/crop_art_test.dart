// 작물 6종 × 성장 3단계가 모두 에러 없이 그려지고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';

void main() {
  testWidgets('작물 6종이 단계마다 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFF6F8EB),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final c in crops)
              Expanded(
                child: Row(children: [
                  for (final s in const [0.1, 0.5, 1.0]) Expanded(child: CropArt(code: c.code, size: 150, stage: s)),
                ]),
              ),
          ]),
        ),
      ),
    ));
    expect(find.byType(CropArt), findsNWidgets(crops.length * 3));
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/crops.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
