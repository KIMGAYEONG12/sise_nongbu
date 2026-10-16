// 갤럭시 탭처럼 넓은 화면(세로·가로)에서 시작 화면·농장 화면이 에러 없이 그려지는지 확인하고,
// 환경변수 PREVIEW_DIR 이 있으면 그림을 저장한다.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/views/splash_page.dart';
import 'package:sise_nongbu/widgets/app_frame.dart';
import 'package:sise_nongbu/widgets/common.dart';
import 'preview_font.dart';

const _sizes = {'phone': Size(411, 891), 'tab_portrait': Size(800, 1280), 'tab_landscape': Size(1280, 800)};

void main() {
  final shot = GlobalKey();

  for (final e in _sizes.entries) {
    testWidgets('시작 화면 (${e.key})', (tester) async {
      if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(builder: appFrameBuilder, home: RepaintBoundary(key: shot, child: SplashPage(onDone: () {}))));
      await tester.runAsync(() async {
        await precacheImage(const AssetImage(AppImages.splash), tester.element(find.byType(SplashPage)));
      });
      await tester.pump(const Duration(milliseconds: 1600));
      expect(tester.takeException(), isNull);
      await savePreview(tester, shot, 'splash_${e.key}', pixelRatio: 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('농장 화면 (${e.key})', (tester) async {
      if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
      tester.view.physicalSize = e.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime(2026, 10, 10, 12);
      final plots = <Plot>[
        Plot(0, 'TOMATO', now.subtract(const Duration(minutes: 1)), growMs: 600000),
        Plot(1, 'FIG', now.add(const Duration(minutes: 20)), growMs: 2400000),
        Plot(2, 'PUMPKIN', now.add(const Duration(minutes: 250)), growMs: 16800000),
        const Plot(3, null, null),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(const UserData({'exp': 1500, 'money': 50000, 'greenhouses': 3})),
          weatherProvider.overrideWith((ref) async => const Weather(18, '맑음', '☀️')),
          tickProvider.overrideWith((ref) => Stream.value(now)),
          plotsProvider.overrideWith((ref) => Stream.value(plots)),
        ],
        child: MaterialApp(builder: appFrameBuilder, home: RepaintBoundary(key: shot, child: const Scaffold(body: FarmPage()))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await precacheImage(const AssetImage('assets/images/farm_scene.jpg'), tester.element(find.byType(FarmPage)));
      });
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await savePreview(tester, shot, 'farm_${e.key}', pixelRatio: 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
