// AI 도우미: 인사말, 사진으로 질문, 음성으로 질문, 오프라인 도우미의 사진 안내.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/ai/ai_agent.dart';
import 'package:sise_nongbu/ai/gemini_llm.dart';
import 'package:sise_nongbu/ai/rule_llm.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/ai_input_service.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/ai_assistant_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 1×1 크기의 진짜 PNG (사진 대신 쓰는 아주 작은 그림)
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _FakePhoto implements PhotoInput {
  bool? lastFromCamera;
  @override
  Future<AiImage?> pick({required bool fromCamera}) async {
    lastFromCamera = fromCamera;
    return AiImage(Uint8List.fromList(_png), 'image/png');
  }
}

class _FakeVoice implements VoiceInput {
  _FakeVoice(this.said, {this.fail});
  final String said;
  final String? fail;
  bool started = false;
  @override
  bool get isListening => started;
  @override
  Future<bool> init() async => fail == null;
  @override
  Future<void> start({required void Function(String text, bool done) onText, required void Function(String message) onError}) async {
    started = true;
    if (fail != null) {
      onError(fail!);
      return;
    }
    onText(said.substring(0, 2), false); // 말하는 중간
    onText(said, true); // 말이 끝남
  }

  @override
  Future<void> stop() async => started = false;
}

class _EmptyMarket extends MarketViewModel {
  @override
  Future<Map<String, AuctionPrice>> build() async => <String, AuctionPrice>{};
}

/// 마지막으로 받은 질문과 사진을 기억하는 가짜 두뇌
class _SpyLlm implements Llm {
  String? question;
  AiImage? image;
  @override
  Future<String> complete(String question, AiContext ctx, {AiImage? image}) async {
    this.question = question;
    this.image = image;
    return '답변이에요';
  }
}

Widget _app({required PhotoInput photo, required VoiceInput voice, required Llm llm}) => ProviderScope(
      overrides: [
        userDataProvider.overrideWithValue(const UserData({})),
        weatherProvider.overrideWith((ref) async => const Weather(20, '맑음', '☀️')),
        marketViewModelProvider.overrideWith(_EmptyMarket.new),
        lotsProvider.overrideWith((ref) => Stream.value(const <Lot>[])),
        plotsProvider.overrideWith((ref) => Stream.value(const <Plot>[])),
        photoInputProvider.overrideWithValue(photo),
        voiceInputProvider.overrideWithValue(voice),
        aiAgentProvider.overrideWithValue(AiAgent(llm)),
      ],
      child: const MaterialApp(home: AiAssistantPage()),
    );

void main() {
  testWidgets('첫 인사: "시세나 농사에 대해 물어보세요!" + 사진·음성 안내', (tester) async {
    await tester.pumpWidget(_app(photo: _FakePhoto(), voice: _FakeVoice('안녕하세요'), llm: _SpyLlm()));
    await tester.pump();
    expect(find.textContaining('시세나 농사에 대해 물어보세요!'), findsOneWidget);
    expect(find.textContaining('음성'), findsWidgets);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진을 고르면 미리보기가 뜨고, 글과 함께 보내면 AI가 사진을 받는다', (tester) async {
    final photo = _FakePhoto();
    final llm = _SpyLlm();
    await tester.pumpWidget(_app(photo: photo, voice: _FakeVoice('안녕하세요'), llm: llm));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    expect(find.text('카메라로 찍기'), findsOneWidget);
    expect(find.text('앨범에서 고르기'), findsOneWidget);
    await tester.tap(find.text('앨범에서 고르기'));
    await tester.pumpAndSettle();
    expect(photo.lastFromCamera, isFalse);
    // 사진 미리보기 + 닫기(✕)
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.enterText(find.byType(TextField), '이 잎 왜 이래요?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(llm.question, '이 잎 왜 이래요?');
    expect(llm.image, isNotNull);
    expect(llm.image!.mime, 'image/png');
    expect(find.text('답변이에요'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing); // 보낸 뒤에는 미리보기가 사라진다
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진만 보내도 된다 (글을 안 적으면 "사진 속 내용"을 물어본다)', (tester) async {
    final llm = _SpyLlm();
    await tester.pumpWidget(_app(photo: _FakePhoto(), voice: _FakeVoice('안녕하세요'), llm: llm));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 찍기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(llm.question, aiDefaultPhotoQuestion);
    expect(llm.image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진을 골랐다가 ✕로 빼면 사진 없이 보낸다', (tester) async {
    final llm = _SpyLlm();
    await tester.pumpWidget(_app(photo: _FakePhoto(), voice: _FakeVoice('안녕하세요'), llm: llm));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('앨범에서 고르기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '시세 알려줘');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(llm.image, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마이크를 누르고 말하면 알아들은 글로 바로 물어본다', (tester) async {
    final llm = _SpyLlm();
    await tester.pumpWidget(_app(photo: _FakePhoto(), voice: _FakeVoice('배추 시세 어때요'), llm: llm));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();
    expect(llm.question, '배추 시세 어때요');
    expect(find.text('배추 시세 어때요'), findsOneWidget); // 내가 한 말이 대화에 나온다
    expect(find.text('답변이에요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('음성 인식이 안 되는 기기에서는 안내 문구가 나오고 멈추지 않는다', (tester) async {
    await tester.pumpWidget(_app(photo: _FakePhoto(), voice: _FakeVoice('x', fail: '이 기기에서는 음성 인식을 쓸 수 없어요'), llm: _SpyLlm()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    expect(find.text('이 기기에서는 음성 인식을 쓸 수 없어요'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget); // 듣는 중 상태가 풀렸다
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  group('오프라인 도우미', () {
    final ctx = const AiContext(prices: {}, money: 0, lots: [], plots: []);

    test('사진만 오면 사진을 분석하지 못한다는 것을 솔직히 알리고 글로 도울 방법을 안내한다', () async {
      final a = await const RuleBasedLlm().complete(aiDefaultPhotoQuestion, ctx, image: AiImage(Uint8List.fromList(_png), 'image/png'));
      expect(a, contains('사진을 받았어요'));
      expect(a, contains('직접 분석하지는 못해요'));
      expect(a, contains('잎이 노랗게'));
    });

    test('사진과 글이 함께 오면 글로 답한다', () async {
      final a = await const RuleBasedLlm().complete('초보 팁 알려줘', ctx, image: AiImage(Uint8List.fromList(_png), 'image/png'));
      expect(a, contains('사진을 받았어요'));
      expect(a, contains('씨앗을 심고'));
    });

    test('사진이 없으면 예전과 똑같이 답한다', () async {
      final a = await const RuleBasedLlm().complete('초보 팁 알려줘', ctx);
      expect(a, isNot(contains('사진')));
    });
  });

  group('Gemini', () {
    test('사진이 있으면 요청에 base64 사진을 함께 보낸다', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'candidates': [{'content': {'parts': [{'text': '잎이 노랗다면 물이 부족할 수 있어요'}]}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final llm = GeminiLlm(client, apiKey: 'test-key', models: const ['m']);
      final a = await llm.complete('이 잎 왜 이래?', ctx(), image: AiImage(Uint8List.fromList(_png), 'image/png'));
      expect(a, contains('물이 부족'));
      final parts = (sent!['contents'] as List).first['parts'] as List;
      expect(parts.length, 2);
      expect(parts[1]['inline_data']['mime_type'], 'image/png');
      expect(parts[1]['inline_data']['data'], base64Encode(_png));
    });

    test('사진이 없으면 글만 보낸다', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'candidates': [{'content': {'parts': [{'text': '네'}]}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      await GeminiLlm(client, apiKey: 'k', models: const ['m']).complete('안녕', ctx());
      final parts = (sent!['contents'] as List).first['parts'] as List;
      expect(parts.length, 1);
    });
  });
}

AiContext ctx() => const AiContext(prices: {}, money: 0, lots: [], plots: []);
