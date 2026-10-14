// 아바타가 에러 없이 그려지는지 확인하고, 눈으로 볼 수 있게 이미지로 저장한다 (저장 위치: 환경변수 AVATAR_OUT 이 있을 때만).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/common.dart';

void main() {
  testWidgets('여자 아이·남자 아이 아바타가 그려진다', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF79CBF3),
              padding: const EdgeInsets.all(16),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [FarmerAvatar(size: 240), SizedBox(width: 16), FarmerAvatar(size: 240, boy: true), SizedBox(width: 16), FarmerAvatar(size: 60, boy: true)]),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(FarmerAvatar), findsNWidgets(3));
    final out = Platform.environment['AVATAR_OUT'];
    if (out != null) {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
