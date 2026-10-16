import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'ai_agent.dart';

/// 실행할 때 --dart-define=GEMINI_API_KEY=... (또는 env.json)로 넣는다. 없으면 오프라인 규칙 도우미를 쓴다.
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Google Gemini API(generateContent, 무료 등급)를 두뇌로 쓰는 도우미.
/// 앞 모델이 바쁘거나(503) 한도에 걸리면(429) 한 번 더 시도한 뒤 다음 모델로 넘어간다.
/// 2026-10-16 확인: gemini-2.0-flash·gemini-2.5-flash-lite는 새 사용자에게 막혔고(404),
/// lite 모델은 thinkingBudget 0을 넣으면 400을 돌려준다. 그래서 모델마다 설정을 다르게 보낸다.
class GeminiLlm implements Llm {
  GeminiLlm(this._client, {required this.apiKey, this.models = defaultModels});
  final http.Client _client;
  final String apiKey;
  final List<String> models;

  /// 빠른 모델 → 예비 모델 순서 (모두 무료 등급에서 쓸 수 있는 이름).
  /// 2026-10-16 측정: gemini-2.5-flash는 약 1초에 답하고, gemini-flash-latest는 계속 503(바쁨)이라 뒤로 뺐다.
  static const defaultModels = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-flash-lite-latest'];

  static const _system = '너는 실제 도매시장 경매 시세로 움직이는 농장 게임 "하루 농장:시세 농부 게임"의 친절한 농사 도우미야. '
      '아래 [현재 상황]과 [게임 안내]를 근거로 짧고 쉬운 한국어(3문장 이내)로 답해. 질문과 관계없는 이야기는 하지 마. '
      '모르면 모른다고 말해. 마크다운 기호(**, #, *)는 쓰지 말고 그냥 문장으로만 답해. '
      '사진이 함께 오면 사진 속 작물·잎·열매의 상태나 병해충을 보고 농사에 도움이 되게 설명해 줘.';

  @override
  Future<String> complete(String question, AiContext ctx, {AiImage? image}) async {
    Object? lastError;
    for (final m in models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _ask(m, question, ctx, image);
        } on _Retryable catch (e) {
          lastError = e;
          if (kDebugMode) debugPrint('Gemini $m 바쁨(${e.code})');
          // 바쁜 모델(503)은 기다리지 않고 바로 다음 모델로 넘어간다. 한도(429)만 잠깐 쉬고 한 번 더.
          if (e.code != 429) break;
          await Future<void>.delayed(const Duration(milliseconds: 400));
        } catch (e) {
          lastError = e;
          if (kDebugMode) debugPrint('Gemini $m 실패: $e');
          break; // 이 모델은 포기하고 다음 모델로
        }
      }
    }
    throw lastError ?? StateError('Gemini 응답 없음');
  }

  /// thinkingBudget 0(생각 단계 끄기)을 받아 주는 모델인지. lite 모델은 400 오류를 낸다.
  static bool _canSkipThinking(String model) => !model.contains('lite');

  Future<String> _ask(String model, String question, AiContext ctx, AiImage? image) async {
    final res = await _client
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'x-goog-api-key': apiKey, 'content-type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _system}
              ]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '[현재 상황]\n${ctx.toText()}\n[질문] $question'},
                  // 사진이 있으면 함께 보낸다 (base64)
                  if (image != null) {'inline_data': {'mime_type': image.mime, 'data': base64Encode(image.bytes)}},
                ]
              }
            ],
            // 3문장 답이 잘리지 않을 만큼(최대 500토큰)만 받아서 빠르게. 받아 주는 모델만 생각 단계를 꺼서 빠르게.
            'generationConfig': {
              'maxOutputTokens': 500,
              'temperature': 0.4,
              if (_canSkipThinking(model)) 'thinkingConfig': {'thinkingBudget': 0},
            },
          }),
        )
        // 한 모델이 오래 멈춰 있으면 다음 모델로 (글 15초, 사진 30초)
        .timeout(Duration(seconds: image == null ? 15 : 30));
    if (res.statusCode == 429 || res.statusCode == 500 || res.statusCode == 503) throw _Retryable(res.statusCode);
    if (res.statusCode != 200) throw StateError('Gemini ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cands = body['candidates'];
    if (cands is! List || cands.isEmpty) throw StateError('Gemini 빈 응답');
    final first = cands.first as Map;
    final parts = (first['content'] as Map?)?['parts'];
    if (parts is! List) throw StateError('Gemini 빈 응답');
    final raw = parts.whereType<Map>().where((p) => p['thought'] != true).map((p) => p['text']).whereType<String>().join('\n');
    final text = cleanAnswer(raw, cut: first['finishReason'] == 'MAX_TOKENS');
    if (text.isEmpty) throw StateError('Gemini 빈 응답');
    return text;
  }
}

class _Retryable implements Exception {
  _Retryable(this.code);
  final int code;
  @override
  String toString() => 'Gemini $code';
}

/// 답에서 마크다운 기호(**굵게**, # 제목, * 목록, `코드`)를 지워 글자만 남긴다.
/// [cut]이면(길이 한도로 잘린 답) 마지막 완성된 문장까지만 남긴다.
String cleanAnswer(String s, {bool cut = false}) {
  var t = s
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[\*\-•]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (cut) {
    final end = t.lastIndexOf(RegExp(r'[.!?요다]\s'));
    final last = [t.lastIndexOf('.'), t.lastIndexOf('!'), t.lastIndexOf('?'), t.lastIndexOf('요'), t.lastIndexOf('다')].reduce((a, b) => a > b ? a : b);
    final at = end > 0 ? end + 1 : last + 1;
    if (at > t.length * .4) t = t.substring(0, at).trim();
  }
  return t;
}
