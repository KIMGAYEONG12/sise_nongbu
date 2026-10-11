// 레벨이 오를수록 집이 조금씩 커지는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 레벨별 그림을 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/widgets/common.dart';

void main() {
  test('집 배율: Lv.1 그대로, 레벨마다 조금씩 커지고 최대 1.08배', () {
    expect(houseScaleFor(1), 1.0);
    expect(houseScaleFor(2), closeTo(1.008, 1e-9));
    expect(houseScaleFor(6), closeTo(1.04, 1e-9));
    expect(houseScaleFor(11), closeTo(1.08, 1e-9));
    expect(houseScaleFor(99), closeTo(1.08, 1e-9));
    expect(houseScaleFor(0), 1.0);
  });

  testWidgets('집이 커진 그림이 에러 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(2100, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Row(children: [
          for (final lv in [1, 6, 11])
            Expanded(
              child: AspectRatio(
                aspectRatio: 936 / 714,
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(AppImages.farmScene, fit: BoxFit.fill),
                  if (houseScaleFor(lv) > 1.0005) GrowingHouseLayer(scale: houseScaleFor(lv)),
                ]),
              ),
            ),
        ]),
      ),
    ));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Image).first);
      for (final f in [AppImages.farmScene]) {
        await precacheImage(AssetImage(f), ctx);
      }
    });
    await tester.pump();
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/house_growth.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
