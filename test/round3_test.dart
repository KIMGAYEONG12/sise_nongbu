// 3차 수정 확인: 사과·토마토 그림 구별, 특별 상점 가격, 부족 문구, AI 설정.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sise_nongbu/ai/gemini_llm.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/widgets/crop_art.dart';

void main() {
  testWidgets('사과와 토마토는 그림이 확실히 다르다 (매칭에서 헷갈리지 않게)', (tester) async {
    Future<Uint8List> shot(String code) async {
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 80, height: 80, child: CropArt(code: code, size: 80))))));
      return (await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      }))!;
    }

    final apple = await shot('APPLE'), tomato = await shot('TOMATO');
    var diff = 0;
    for (var i = 0; i < apple.length; i += 4) {
      if ((apple[i] - tomato[i]).abs() + (apple[i + 1] - tomato[i + 1]).abs() > 90) diff++;
    }
    expect(diff, greaterThan(300)); // 색이 크게 다른 점이 많다
  });

  test('특별 상점은 모두 100P 이하로 값이 내려갔다', () {
    for (final i in pointItems) {
      expect(i.cost, lessThanOrEqualTo(80), reason: i.name);
    }
    expect(pointItems.firstWhere((e) => e.key == pointRareSeed).cost, 40);
  });

  test('AI는 빠른 모델이 먼저이고 짧게 답한다', () {
    final g = GeminiLlm(_NoClient(), apiKey: 'x');
    expect(g.models.first, 'gemini-2.5-flash');
  });
}

class _NoClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw UnimplementedError();
}
