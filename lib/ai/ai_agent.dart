import 'dart:typed_data';
import '../core/game_rules.dart';
import '../models/models.dart';
import 'rule_llm.dart';

/// 도우미가 답할 때 참고하는 현재 농장 상황
class AiContext {
  const AiContext({
    required this.prices,
    required this.money,
    required this.lots,
    required this.plots,
    this.level = 1,
    this.expLeft = 0,
    this.greenhouses = 0,
    this.weather,
    this.items = const {},
  });
  final Map<String, AuctionPrice> prices;
  final int money;
  final List<Lot> lots;
  final List<Plot> plots;

  /// 현재 레벨과 다음 레벨까지 남은 경험치
  final int level, expLeft;

  /// 지은 하우스 수
  final int greenhouses;

  /// 오늘 날씨 (예: "맑음 23°C"), 모르면 null
  final String? weather;

  /// 가지고 있는 아이템·씨앗 (키 → 개수)
  final Map<String, int> items;

  /// LLM에 넘길 요약 글
  String toText() {
    final b = StringBuffer('보유 금화: $money\n레벨: Lv.$level (다음 레벨까지 경험치 $expLeft)\n하우스: $greenhouses채\n');
    if (weather != null) b.writeln('오늘 날씨: $weather');
    b.writeln('[오늘 시세(원/kg)]');
    for (final c in crops) {
      final p = prices[c.code];
      if (p == null) continue;
      final prev = p.prevPerKg;
      final diff = prev == null || prev == 0 ? '' : ' (전일 대비 ${((p.pricePerKg - prev) / prev * 100).toStringAsFixed(1)}%)';
      b.writeln('- ${c.name}: ${p.pricePerKg.round()}$diff, 씨앗 ${c.seedCost}원, 수확 ${c.yieldKg.toStringAsFixed(0)}kg, 성장 ${c.growMinutes}분');
    }
    b.writeln('[창고]');
    if (lots.isEmpty) b.writeln('- 비어 있음');
    for (final l in lots) {
      b.writeln('- ${cropOf(l.cropCode).name} ${l.kg.toStringAsFixed(1)}kg');
    }
    final planted = plots.where((p) => p.cropCode != null).length;
    b.writeln('[밭] 전체 ${plots.length}칸 중 $planted칸에 작물이 있어요');
    final owned = items.entries.where((e) => e.value > 0).toList();
    b.writeln('[가진 아이템]');
    if (owned.isEmpty) b.writeln('- 없음');
    for (final e in owned) {
      b.writeln('- ${_itemLabel(e.key)} ${e.value}개');
    }
    b.write(aiGameGuide);
    return b.toString();
  }
}

String _itemLabel(String key) {
  const names = {'water': '물통', 'fertilizer': '영양제', 'booster': '성장촉진제'};
  if (names.containsKey(key)) return names[key]!;
  if (key.startsWith('seed_')) {
    try {
      return '${cropOf(key.substring(5)).name} 씨앗';
    } catch (_) {}
  }
  return key;
}

/// 게임 규칙 안내: 도우미가 시세·창고 말고 게임 방법(작물 매칭, 레벨, 하우스, 상점 등)도 답할 수 있게 함께 보낸다.
const aiGameGuide = '''
[게임 안내]
- 작물 매칭: 같은 작물 3개 이상을 한 줄로 맞추면 지워진다. 한 칸에 10점, 한 번에 이어서 여러 번 지워지면(연쇄) 2번째부터 20점씩 더 준다. 오늘 시세가 오른 작물일수록 점수 배율이 높다(10% 오르면 2배). 난이도가 높을수록(작물 종류가 많고 시간이 짧을수록) 배율이 높다. 한 판을 다 맞추면 시간과 점수를 더 받는다.
- 레벨: 심기·수확·판매·구매·미션·기부·게임으로 경험치를 얻는다. 수확 경험치가 가장 크다. 레벨이 오르면 캐시와 씨앗 보상, 칭호가 바뀐다.
- 하우스: 상점 농장 시설에서 짓는다. 지을 때마다 성장 시간이 줄어든다(5채까지 10%씩, 이후 4%씩, 최대 70%).
- 아이템: 물통은 성장 시간 3% 단축, 영양제·성장촉진제(30% 단축)도 횟수 제한 없이 쓸 수 있다. 상점에서 사거나 묶음으로 싸게 산다.
- 판매: 창고에서 작물을 눌러 판다. 받는 돈 = kg × 오늘 시세 × 신선도. 오래 두면 신선도가 하루 5%씩 떨어진다.
- 미션·업적을 깨면 캐시를 받고, 캐시로 특별 상점에서 산다. (작물을 사고파는 돈은 P, 보상 재화는 캐시)
- 고객센터·문의: 아래 MY 탭 → 고객센터에서 자주 묻는 질문을 보고, '의견 보내기'에 적어 보내기를 누르면 메일 앱이 열려 운영자에게 보낼 수 있다.
''';

/// 질문과 함께 보내는 사진 (카메라·앨범에서 고른 것)
class AiImage {
  const AiImage(this.bytes, this.mime);
  final Uint8List bytes;

  /// 예) image/jpeg
  final String mime;
}

/// 사진만 보내고 글을 안 적었을 때 대신 쓰는 질문
const aiDefaultPhotoQuestion = '이 사진 속 작물이나 상태를 보고 알려줘';

/// 질문에 답을 만들어 주는 두뇌 (Gemini 또는 오프라인 규칙). 사진([image])이 있으면 함께 보고 답한다.
abstract class Llm {
  Future<String> complete(String question, AiContext ctx, {AiImage? image});
}

/// 도우미 화면에 보여줄 추천 질문 (눌러서 바로 물어볼 수 있다)
const aiSuggestions = [
  ('📈', '오늘 시세 요약해줘'),
  ('🌱', '지금 뭘 심으면 좋아?'),
  ('💰', '창고에서 뭐부터 팔까?'),
  ('⭐', '레벨 빨리 올리는 법 알려줘'),
  ('🏠', '하우스는 언제 지으면 좋아?'),
  ('🧺', '내 창고 상태 알려줘'),
  ('🌤️', '오늘 날씨에 뭘 하면 좋아?'),
  ('🥬', '배추 시세 어때?'),
  ('🍅', '토마토 시세 어때?'),
  ('🎮', '작물 매칭 점수 잘 받는 법'),
  ('🛒', '상점에서 뭘 사면 좋아?'),
  ('💡', '초보 농부 팁 알려줘'),
  ('📮', '고객센터 문의는 어떻게 해?'),
];

/// 고객센터·문의 질문에 대한 정해진 답 (AI가 엉뚱한 답을 하지 않도록 바로 답한다)
const aiSupportAnswer = '📮 고객센터는 아래 MY 탭 → 고객센터에 있어요.\n'
    '자주 묻는 질문을 먼저 확인하고, 해결이 안 되면 맨 아래 의견 보내기에 내용을 적은 뒤 보내기를 눌러 주세요. 메일 앱이 열리면 거기서 보내기를 누르면 운영자에게 전달돼요.';

/// 고객센터·문의·불편 신고 같은 질문인지
bool isSupportQuestion(String q) {
  final t = q.replaceAll(' ', '');
  return const ['고객센터', '고객센타', '문의', '상담', '건의', '신고', '버그', '오류신고', '운영자', '개발자', '연락처', '이메일'].any(t.contains);
}

/// AI 농사 도우미: 두뇌(Llm)를 감싸고, 실패하면 오프라인 규칙 도우미로 대신 답한다.
class AiAgent {
  AiAgent(this._llm, {Llm fallback = const RuleBasedLlm()}) : _fallback = fallback;
  final Llm _llm;
  final Llm _fallback;

  Future<String> ask(String question, AiContext ctx, {AiImage? image}) async {
    var q = question.trim();
    if (q.isEmpty) {
      if (image == null) return '궁금한 걸 입력해 주세요!';
      q = aiDefaultPhotoQuestion; // 사진만 보냈으면 사진 속 내용을 물어본 것으로 본다
    }
    if (image == null && isSupportQuestion(q)) return aiSupportAnswer;
    try {
      final a = await _llm.complete(q, ctx, image: image);
      if (a.trim().isNotEmpty) return a.trim();
    } catch (_) {}
    // 인터넷 AI가 실패하면(인터넷 끊김·한도 초과 등) 오프라인 도우미가 대신 답한다
    if (identical(_llm, _fallback)) return '지금은 답을 가져오지 못했어요. 잠시 후 다시 물어봐 주세요.';
    try {
      return await _fallback.complete(q, ctx, image: image);
    } catch (_) {
      return '지금은 답을 가져오지 못했어요. 잠시 후 다시 물어봐 주세요.';
    }
  }
}
