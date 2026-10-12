// 위성이 달린 하우스(15단계 이상)가 에러 없이 그려지는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/greenhouse_art.dart';
import 'preview_font.dart';

void main() {
  testWidgets('위성 연동 스마트팜(15단계)부터 우주 문명 농장(20단계)까지 그려진다', (tester) async {
    if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
    final key = GlobalKey();
    const stages = [14, 15, 16, 20];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF86C75A),
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Wrap(spacing: 20, runSpacing: 44, children: [
              for (final st in stages)
                SizedBox(
                  width: 360,
                  height: 244,
                  child: CustomPaint(painter: GreenhousePainter(count: st, tier: greenhouseTierOfStage(st), name: greenhouseStageName(st), stage: st)),
                ),
            ]),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/greenhouse_satellite.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  test('위성은 15단계부터 붙는다 (단계 이름과 크기 규칙은 그대로)', () {
    expect(greenhouseStageName(15), '위성 연동 스마트팜');
    expect(greenhouseStageName(14), '플라즈마 에너지 팜');
    expect(greenhouseSizeScale(15), closeTo(1.5, 1e-9));
  });
}
