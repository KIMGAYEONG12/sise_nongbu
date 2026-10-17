// 농장 우체통: 새 버전이 있으면 숫자 1이 보이고, 누르면 편지 창(업데이트하기)이 열린다.
// 환경변수 PREVIEW_DIR 이 있으면 편지가 온 농장 화면과 편지 창을 그림으로 저장한다.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/update_service.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/farm_page.dart';
import 'package:sise_nongbu/widgets/farm_mailbox.dart';
import 'preview_font.dart';

class _FakeUpdate extends UpdateService {
  int updates = 0;
  @override
  Future<bool> update() async {
    updates++;
    return true;
  }
}

void main() {
  testWidgets('편지가 없으면 숫자가 없고, 누르면 빈 우체통 안내가 나온다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: FarmMailbox(hasLetter: false, onTap: () => taps++)))));
    expect(find.text('1'), findsNothing);
    await tester.tap(find.byType(FarmMailbox));
    expect(taps, 1);
  });

  final shot = GlobalKey();
  for (final letter in [true, false]) {
    testWidgets('농장 우체통 (새 버전 ${letter ? '있음' : '없음'})', (tester) async {
      if (Platform.environment['PREVIEW_DIR'] != null) await loadPreviewFonts();
      tester.view.physicalSize = const Size(411, 891) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final now = DateTime(2026, 10, 10, 12);
      final fake = _FakeUpdate();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(const UserData({'exp': 1500, 'money': 50000, 'greenhouses': 0})),
          weatherProvider.overrideWith((ref) async => const Weather(18, '맑음', '☀️')),
          tickProvider.overrideWith((ref) => Stream.value(now)),
          plotsProvider.overrideWith((ref) => Stream.value(const <Plot>[])),
          updateAvailableProvider.overrideWith((ref) async => letter ? 12 : null),
          updateServiceProvider.overrideWithValue(fake),
        ],
        child: RepaintBoundary(key: shot, child: const MaterialApp(home: Scaffold(body: FarmPage()))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await precacheImage(const AssetImage('assets/images/farm_scene_gemini.jpg'), tester.element(find.byType(FarmPage)));
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FarmMailbox), findsOneWidget);
      expect(find.descendant(of: find.byType(FarmMailbox), matching: find.text('1')), letter ? findsOneWidget : findsNothing);
      await savePreview(tester, shot, 'mailbox_farm_${letter ? 'letter' : 'empty'}');

      await tester.tap(find.byType(FarmMailbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(letter ? '농부님께 편지가 도착했어요' : '아직 도착한 편지가 없어요'), findsOneWidget);
      // 우체통 색 고르기 (분홍)
      expect(find.text('우체통 색을 골라 주세요'), findsOneWidget);
      await savePreview(tester, shot, 'mailbox_sheet_${letter ? 'letter' : 'empty'}');
      if (letter) {
        await tester.tap(find.text('지금 업데이트하기'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(fake.updates, 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
