// 3차 수정 확인: 사과·토마토 그림 구별, 특별 상점 가격, 부족 문구, AI 설정.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sise_nongbu/ai/ai_agent.dart';
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

  test('AI는 빠른 모델이 먼저이고, 예비 모델도 있다', () {
    final g = GeminiLlm(_NoClient(), apiKey: 'x');
    expect(g.models.first, 'gemini-2.5-flash'); // 2026-10-16 측정: 약 1초로 가장 빠르고, flash-latest는 계속 503
    expect(g.models.length, greaterThanOrEqualTo(2));
  });

  test('AI 답에서 ** 같은 마크다운 기호를 지운다', () {
    expect(cleanAnswer('**배추**는 지금 *비싸요*.\n# 팁\n* 물 주기'), '배추는 지금 비싸요.\n팁\n• 물 주기');
  });

  test('앞 모델이 실패하면 다음 모델로 넘어가고, lite 모델에는 thinkingBudget을 보내지 않는다', () async {
    final seen = <String, String>{};
    final client = MockClient((req) async {
      final model = req.url.pathSegments.last.split(':').first;
      seen[model] = req.body;
      if (model != 'gemini-flash-lite-latest') return http.Response('busy', 404);
      return http.Response(jsonEncode({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': '**토마토**를 심어 보세요.'}
              ]
            }
          }
        ]
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final g = GeminiLlm(client, apiKey: 'x');
    final a = await g.complete('뭘 심을까?', const AiContext(prices: {}, money: 0, lots: [], plots: []));
    expect(a, '토마토를 심어 보세요.');
    expect(seen.keys, containsAll(GeminiLlm.defaultModels));
    expect(seen['gemini-flash-latest'], contains('thinkingBudget'));
    expect(seen['gemini-flash-lite-latest'], isNot(contains('thinkingBudget')));
  });

  test('인터넷 AI가 실패하면 오프라인 도우미가 대신 답한다', () async {
    final agent = AiAgent(_FailLlm());
    final a = await agent.ask('초보 농부 팁 알려줘', const AiContext(prices: {}, money: 0, lots: [], plots: []));
    expect(a, isNot(contains('답을 가져오지 못했어요')));
    expect(a, isNotEmpty);
  });

  test('고객센터 문의를 물으면 고객센터 가는 방법을 알려준다', () async {
    final agent = AiAgent(_FailLlm());
    for (final q in ['고객센터 문의', '고객 센터 어디야?', '문의하고 싶어요']) {
      expect(await agent.ask(q, const AiContext(prices: {}, money: 0, lots: [], plots: [])), contains('MY 탭 → 고객센터'));
    }
  });
}

class _FailLlm implements Llm {
  @override
  Future<String> complete(String question, AiContext ctx, {AiImage? image}) => throw StateError('끊김');
}

class _NoClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw UnimplementedError();
}
