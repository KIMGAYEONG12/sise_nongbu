// 튜토리얼 1~5장이 모두 같은 틀(제목·설명·그림 틀·버튼·점)로 그려지는지 확인하고,
// 환경변수 PREVIEW_DIR 이 있으면 장마다 이미지로 저장한다.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/tutorial_page.dart';

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => {
        'CABBAGE': AuctionPrice('CABBAGE', 953, DateTime(2026, 10, 8), prevPerKg: 848),
        'RADISH': AuctionPrice('RADISH', 763, DateTime(2026, 10, 8), prevPerKg: 805),
        'ONION': AuctionPrice('ONION', 1641, DateTime(2026, 10, 8), prevPerKg: 1581),
        'APPLE': AuctionPrice('APPLE', 3337, DateTime(2026, 10, 8), prevPerKg: 3480),
        'TOMATO': AuctionPrice('TOMATO', 3993, DateTime(2026, 10, 8), prevPerKg: 3888),
      };
}

void main() {
  testWidgets('튜토리얼 1~5장이 모두 같은 틀로 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new)],
      child: MaterialApp(home: RepaintBoundary(key: key, child: TutorialPage(onDone: () {}))),
    ));
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      // 이미지로 저장해 눈으로 확인할 때만: 한글 글꼴과 그림 파일을 미리 읽어 둔다
      await tester.runAsync(() async {
        final f = File('C:/Windows/Fonts/malgun.ttf');
        if (f.existsSync()) {
          final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
          await loader.load();
        }
        final ctx = tester.element(find.byType(TutorialPage));
        for (final a in ['farm_scene.jpg', 'tut_plant.jpg', 'tut_ready.jpg', 'tut_hand.png', 'splash_bg.jpg']) {
          await precacheImage(AssetImage('assets/images/$a'), ctx);
        }
      });
    }
    final frames = <Rect>[];
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('튜토리얼 ${i + 1} / 5'), findsOneWidget);
      final f = find.byKey(ValueKey('tutorialFrame$i'));
      expect(f, findsOneWidget);
      frames.add(tester.getRect(f));
      if (dir != null) {
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/tut${i + 1}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      if (i < 4) {
        await tester.tap(find.text('다음'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    // 1~5장의 그림 틀 위치와 크기가 모두 같아야 한다
    for (final r in frames) {
      expect(r, frames.first);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
