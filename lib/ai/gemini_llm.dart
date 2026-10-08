import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_agent.dart';

/// 실행할 때 --dart-define=GEMINI_API_KEY=... (또는 env.json)로 넣는다. 없으면 오프라인 규칙 도우미를 쓴다.
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Google Gemini API(generateContent)를 두뇌로 쓰는 도우미.
/// 앞 모델이 바쁘거나(503) 한도에 걸리면(429) 다음 모델로 자동으로 넘어간다.
class GeminiLlm implements Llm {
  GeminiLlm(this._client, {required this.apiKey, this.models = const ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.5-flash-lite']});
  final http.Client _client;
  final String apiKey;
  final List<String> models;

  static const _system = '너는 실제 도매시장 경매 시세로 움직이는 농장 게임의 친절한 농사 도우미야. '
      '아래 [현재 상황]만 근거로 짧고 쉬운 한국어(3문장 이내)로 답해. 모르면 모른다고 말해.';

  @override
  Future<String> complete(String question, AiContext ctx) async {
    Object? lastError;
    for (final m in models) {
      try {
        return await _ask(m, question, ctx);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Gemini 응답 없음');
  }

  Future<String> _ask(String model, String question, AiContext ctx) async {
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
                  {'text': '[현재 상황]\n${ctx.toText()}\n[질문] $question'}
                ]
              }
            ],
            'generationConfig': {'maxOutputTokens': 500},
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) throw StateError('Gemini ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cands = body['candidates'];
    if (cands is! List || cands.isEmpty) throw StateError('Gemini 빈 응답');
    final parts = ((cands.first as Map)['content'] as Map?)?['parts'];
    if (parts is! List) throw StateError('Gemini 빈 응답');
    final text = parts.whereType<Map>().map((p) => p['text']).whereType<String>().join('\n').trim();
    if (text.isEmpty) throw StateError('Gemini 빈 응답');
    return text;
  }
}
