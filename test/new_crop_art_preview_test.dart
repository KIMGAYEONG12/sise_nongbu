// 새로 그린 작물 그림(무화과·호박·바나나·복숭아·양상추)이 에러 없이 그려지는지 확인하고,
// 환경변수 PREVIEW_DIR 이 있으면 한 장으로 모아 PNG로 저장한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';
import 'preview_font.dart';

void main() {
  testWidgets('무화과·호박·바나나·복숭아·양상추 그림', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1000, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFF6F8EB),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final c in const ['FIG', 'PUMPKIN', 'BANANA', 'PEACH', 'LETTUCE']) CropArt(code: c, size: 180),
          ]),
        ),
      ),
    ));
    expect(find.byType(CropArt), findsNWidgets(5));
    expect(tester.takeException(), isNull);
    await savePreview(tester, key, 'new_crops', pixelRatio: 1);
  });
}
