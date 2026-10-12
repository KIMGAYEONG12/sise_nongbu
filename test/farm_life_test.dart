// 농장에서 작물이 흔들리고 로봇이 길을 따라 움직이는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 그림을 저장한다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';
import 'package:sise_nongbu/widgets/farm_life.dart';
import 'preview_font.dart';

void main() {
  test('로봇은 길을 따라 한 바퀴를 돌고 처음 자리로 돌아온다', () {
    final start = FarmLife.robotAt(0).$1;
    final end = FarmLife.robotAt(.999999).$1;
    expect((start - end).distance, lessThan(1));
    // 시간이 흐르면 위치가 바뀐다
    expect((FarmLife.robotAt(.25).$1 - start).distance, greaterThan(20));
    // 길 위의 모든 위치는 그림(936×714) 안에 있다
    for (var i = 0; i <= 100; i++) {
      final p = FarmLife.robotAt(i / 100).$1;
      expect(p.dx, inInclusiveRange(0, 936));
      expect(p.dy, inInclusiveRange(0, 714));
    }
    // 가다가 왼쪽으로 꺾는 구간이 있다 (로봇이 몸을 돌린다)
    expect([for (var i = 0; i < 100; i++) FarmLife.robotAt(i / 100).$2].toSet(), {true, false});
  });

  final shot = GlobalKey();
  testWidgets('심은 작물이 흙 위에서 보이고 로봇과 함께 에러 없이 움직인다', (tester) async {
    if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
    tester.view.physicalSize = const Size(411, 891) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 10, 10, 12);
    final plots = <Plot>[
      Plot(0, 'TOMATO', now.subtract(const Duration(minutes: 1)), growMs: 600000), // 다 자람
      Plot(1, 'CABBAGE', now.add(const Duration(minutes: 20)), growMs: 2400000), // 자라는 중
      Plot(2, 'FIG', now.add(const Duration(minutes: 250)), growMs: 16800000), // 새싹
      const Plot(3, null, null),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataProvider.overrideWithValue(const UserData({'exp': 1500, 'money': 50000, 'greenhouses': 3})),
        weatherProvider.overrideWith((ref) async => const Weather(18, '맑음', '☀️')),
        tickProvider.overrideWith((ref) => Stream.value(now)),
        plotsProvider.overrideWith((ref) => Stream.value(plots)),
      ],
      child: RepaintBoundary(key: shot, child: const MaterialApp(home: Scaffold(body: FarmPage()))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/images/farm_scene.jpg'), tester.element(find.byType(FarmPage)));
    });
    await tester.pump(const Duration(seconds: 9)); // 로봇이 움직인다
    // 심은 밭 3곳의 작물이 그려진다 (빈 밭은 안 그린다)
    expect(find.descendant(of: find.byType(FarmLife), matching: find.byType(CropArt)), findsNWidgets(3));
    expect(find.descendant(of: find.byType(FarmLife), matching: find.byType(CustomPaint)), findsWidgets);
    // 레벨·칭호 줄은 "…"로 잘리지 않고 전체가 보인다 (exp 1500 = Lv.5 성실한 농부)
    expect(find.text('Lv. 5  ·  🌾 성실한 농부'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/farm_life.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
