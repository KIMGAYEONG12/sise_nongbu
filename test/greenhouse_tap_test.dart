// 농장의 하우스를 누르면 정보 창이 열리고, 창고가 비어 있어도 "판매하기"를 누르면 이유를 알려 준다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart' show maxGreenhouses;
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/views/inventory_page.dart';
import 'package:sise_nongbu/widgets/home_art.dart';

void main() {
  final shot = GlobalKey();

  testWidgets('농장 하우스를 누르면 정보 창이 열린다 (모양 이름·채 수·단축 효과·더 짓기)', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // exp 4000 → 높은 레벨, 하우스 2채
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataProvider.overrideWithValue(const UserData({'exp': 4000, 'money': 500000, 'greenhouses': 2})),
        weatherProvider.overrideWith((ref) async => const Weather(18, '맑음', '☀️')),
        tickProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 10, 12))),
      ],
      child: RepaintBoundary(key: shot, child: const MaterialApp(home: Scaffold(body: FarmPage()))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(FarmPage));
      await precacheImage(const AssetImage('assets/images/farm_scene.jpg'), ctx);
    });
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final dir = Platform.environment['PREVIEW_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final b = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/farm.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    // 농장에 그려진 하우스(단계가 오르면 아파트) 그림을 누른다
    final house = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HomeBuildingPainter);
    expect(house, findsOneWidget);
    await tester.tap(house);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('지은 하우스'), findsOneWidget);
    expect(find.text('2채 / 최대 $maxGreenhouses채'), findsOneWidget);
    expect(find.text('성장 시간 단축'), findsOneWidget);
    expect(find.textContaining('하우스 더 짓기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('창고가 비어 있어도 판매하기를 누르면 안내가 나온다', (tester) async {
    tester.view.physicalSize = const Size(411, 891) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataProvider.overrideWithValue(const UserData({'money': 50000})),
        lotsProvider.overrideWith((ref) => Stream.value(const <Lot>[])),
      ],
      child: const MaterialApp(home: Scaffold(body: InventoryPage())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('판매하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('판매할 작물이나 아이템이 없어요. 밭에서 작물을 수확하면 여기에 쌓여요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
