import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_agent.dart';

/// 실행할 때 --dart-define=GEMINI_API_KEY=... (또는 env.json)로 넣는다. 없으면 오프라인 규칙 도우미를 쓴다.
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Google Gemini API(generateContent)를 두뇌로 쓰는 도우미.
/// 앞 모델이 바쁘거나(503) 한도에 걸리면(429) 다음 모델로 자동으로 넘어간다.
class GeminiLlm implements Llm {
  GeminiLlm(this._client, {required this.apiKey, this.models = const ['gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-flash-latest']});
  final http.Client _client;
  final String apiKey;
  final List<String> models;

  static const _system = '너는 실제 도매시장 경매 시세로 움직이는 농장 게임의 친절한 농사 도우미야. '
      '아래 [현재 상황]만 근거로 짧고 쉬운 한국어(3문장 이내)로 답해. 모르면 모른다고 말해. '
      '사진이 함께 오면 사진 속 작물·잎·열매의 상태나 병해충을 보고 농사에 도움이 되게 설명해 줘.';

  @override
  Future<String> complete(String question, AiContext ctx, {AiImage? image}) async {
    Object? lastError;
    for (final m in models) {
      try {
        return await _ask(m, question, ctx, image);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Gemini 응답 없음');
  }

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
            // 빠른 답: 생각하는 단계를 끄고(thinkingBudget 0) 답을 짧게(최대 300토큰) 받는다
            'generationConfig': {'maxOutputTokens': 300, 'thinkingConfig': {'thinkingBudget': 0}},
          }),
        )
        .timeout(Duration(seconds: image == null ? 10 : 30));
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
