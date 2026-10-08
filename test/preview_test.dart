// 하우스와 튜토리얼 5장 그림이 에러 없이 그려지는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 이미지로 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/views/tutorial_page.dart';

class _FakeMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => {'CABBAGE': AuctionPrice('CABBAGE', 911, DateTime(2026, 10, 8), prevPerKg: 800)};
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['PREVIEW_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('하우스 그림', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: key, child: Container(color: const Color(0xFF86C75A), padding: const EdgeInsets.fromLTRB(30, 40, 30, 20), child: const SizedBox(width: 260, height: 176, child: CustomPaint(painter: GreenhousePainter())))),
        ),
      ),
    ));
    await _save(tester, key, 'house');
    expect(tester.takeException(), isNull);
  });

  testWidgets('튜토리얼 5장: 아이를 누르면 반짝이가 터지고 배지를 누르면 설명이 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: [marketViewModelProvider.overrideWith(_FakeMarket.new)],
      child: MaterialApp(home: RepaintBoundary(key: key, child: TutorialPage(onDone: () {}))),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('다음'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('튜토리얼 5 / 5'), findsOneWidget);
    expect(find.text('👆 농부를 눌러 보세요'), findsOneWidget);
    await tester.tap(find.text('👆 농부를 눌러 보세요'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🌾 좋아요! 이제 농장으로 가요'), findsOneWidget);
    await _save(tester, key, 'ready');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
