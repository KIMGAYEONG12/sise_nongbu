import '../core/game_rules.dart';
import '../models/models.dart';

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
    return b.toString();
  }
}

/// 질문에 답을 만들어 주는 두뇌 (Gemini 또는 오프라인 규칙)
abstract class Llm {
  Future<String> complete(String question, AiContext ctx);
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
];

/// AI 농사 도우미: 두뇌(Llm)를 감싸고, 실패하면 알아듣기 쉬운 문구로 바꿔준다.
class AiAgent {
  AiAgent(this._llm);
  final Llm _llm;

  Future<String> ask(String question, AiContext ctx) async {
    final q = question.trim();
    if (q.isEmpty) return '궁금한 걸 입력해 주세요!';
    try {
      return await _llm.complete(q, ctx);
    } catch (_) {
      return '지금은 답을 가져오지 못했어요. 잠시 후 다시 물어봐 주세요.';
    }
  }
}
