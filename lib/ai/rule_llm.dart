import '../core/game_rules.dart';
import 'ai_agent.dart';

/// 인터넷·API 키 없이 동작하는 규칙 기반 도우미 (Gemini 키가 없을 때 대신 쓴다)
class RuleBasedLlm implements Llm {
  const RuleBasedLlm();

  static bool _has(String q, List<String> words) => words.any(q.contains);

  static String _trend(double now, double? prev) {
    if (prev == null || prev == 0) return '';
    final pct = (now - prev) / prev * 100;
    if (pct.abs() < .05) return ' (전일과 같아요)';
    return ' (${pct > 0 ? '▲' : '▼'}${pct.abs().toStringAsFixed(1)}%)';
  }

  @override
  Future<String> complete(String question, AiContext ctx, {AiImage? image}) async {
    final text = await _answer(question, ctx);
    if (image == null) return text;
    // 인터넷 AI(Gemini)가 없으면 사진 속 내용을 직접 알아보지는 못한다. 그 사실을 알려주고 글로 도울 수 있게 안내한다.
    const note = '📷 사진을 받았어요! 지금은 오프라인 도우미라서 사진 속 모습을 직접 분석하지는 못해요.\n';
    if (question == aiDefaultPhotoQuestion) {
      return '$note어떤 작물인지, 잎이나 열매가 어떻게 달라졌는지 글이나 음성으로 알려주시면 도와드릴게요 (예: "토마토 잎이 노랗게 변했어요").';
    }
    return '$note글로 적어 주신 내용으로 답해 드릴게요.\n\n$text';
  }

  Future<String> _answer(String question, AiContext ctx) async {
    final q = question;

    // 1) 작물 이름이 들어 있으면 그 작물 이야기
    for (final c in crops) {
      if (!q.contains(c.name)) continue;
      final p = ctx.prices[c.code];
      if (p == null) return '${c.label} 시세를 아직 불러오지 못했어요.';
      final prev = p.prevPerKg;
      final tip = prev == null || prev == 0
          ? ''
          : p.pricePerKg > prev
              ? '\n전일보다 올랐어요. 창고에 있다면 지금 팔기 좋아요 📈'
              : p.pricePerKg < prev
                  ? '\n전일보다 내렸어요. 오를 때까지 보관하거나 새로 심어 두세요 📉'
                  : '\n전일과 같아요. 급하지 않으면 지켜봐요.';
      return '${c.label}은(는) 지금 kg당 ${p.pricePerKg.round()}원이에요.$tip\n(씨앗 ${c.seedCost}원 · 수확 ${c.yieldKg.toStringAsFixed(0)}kg · 성장 ${c.growMinutes}분)';
    }

    // 2) 시세 요약
    if (_has(q, ['요약', '시세', '가격', '얼마'])) {
      final lines = <String>[];
      for (final c in crops) {
        final p = ctx.prices[c.code];
        if (p != null) lines.add('${c.label} ${p.pricePerKg.round()}원${_trend(p.pricePerKg, p.prevPerKg)}');
      }
      return lines.isEmpty ? '시세를 아직 불러오지 못했어요.' : '오늘 시세예요 (kg당)\n${lines.join('\n')}';
    }

    // 3) 팔 작물 추천
    if (_has(q, ['팔', '출하', '판매'])) {
      if (ctx.lots.isEmpty) return '창고가 비어 있어요. 먼저 수확해 보세요!';
      final best = ctx.lots.where((l) => ctx.prices[l.cropCode] != null).toList()
        ..sort((a, b) => ctx.prices[b.cropCode]!.pricePerKg.compareTo(ctx.prices[a.cropCode]!.pricePerKg));
      if (best.isEmpty) return '시세를 불러온 뒤에 추천해 드릴게요.';
      final c = cropOf(best.first.cropCode);
      return '창고에서는 ${c.label}이(가) kg당 ${ctx.prices[c.code]!.pricePerKg.round()}원으로 가장 비싸요. 신선도가 떨어지기 전에 출하해 보세요!';
    }

    // 4) 심을 작물 추천
    if (_has(q, ['심', '추천'])) {
      CropSpec? top;
      var topRate = -1e9;
      for (final c in crops) {
        final p = ctx.prices[c.code];
        final prev = p?.prevPerKg;
        if (p == null || prev == null || prev == 0) continue;
        final r = (p.pricePerKg - prev) / prev;
        if (r > topRate) {
          topRate = r;
          top = c;
        }
      }
      if (top != null) return '요즘 ${top.label} 시세가 가장 많이 올랐어요 (${(topRate * 100).toStringAsFixed(1)}%). 성장 ${top.growMinutes}분이니 지금 심어 볼까요?';
    }

    // 5) 레벨·경험치
    if (_has(q, ['레벨', '경험치', 'exp', 'EXP'])) {
      return '지금 Lv.${ctx.level}, 다음 레벨까지 경험치 ${ctx.expLeft} 남았어요.\n'
          '파종 +15, 수확 +60, 판매·구매·기부·매칭 게임으로도 경험치를 얻어요. 밭을 비우지 말고 계속 심고 수확하는 게 가장 빨라요!';
    }

    // 6) 하우스·상점
    if (_has(q, ['하우스', '온실'])) {
      return '하우스는 지을수록 성장 시간이 줄어요 (5채까지 10%씩, 10채에서 최대 70%). 지금 ${ctx.greenhouses}채예요. 한 채 지을 때마다 하우스가 커지고 이름도 바뀌어요 (비닐하우스 → 유리 온실 → 스마트 온실 → 황금 온실 → … → AI 퀀텀 팜 → … → 우주 문명 농장, 그 뒤로도 새 이름이 계속 나와요) 🏠';
    }
    if (_has(q, ['상점', '사면', '구매', '살'])) {
      return '처음엔 씨앗과 물통을 사서 밭을 채우세요. 자금이 모이면 밭 넓히기, 창고 넓히기, 하우스 순서로 투자하면 좋아요 🛒';
    }

    // 7) 창고·밭
    if (_has(q, ['창고', '재고'])) {
      if (ctx.lots.isEmpty) return '창고가 비어 있어요.';
      final sum = <String, double>{};
      for (final l in ctx.lots) {
        sum[l.cropCode] = (sum[l.cropCode] ?? 0) + l.kg;
      }
      return '창고 상태예요 🧺\n${sum.entries.map((e) => '${cropOf(e.key).label} ${e.value.toStringAsFixed(1)}kg').join('\n')}';
    }

    // 8) 날씨
    if (_has(q, ['날씨', '비', '맑'])) {
      return ctx.weather == null ? '날씨를 아직 불러오지 못했어요.' : '오늘은 ${ctx.weather}예요. 작물 상태를 둘러보고 물주기를 해 보세요 🌤️';
    }

    // 9) 게임
    if (_has(q, ['매칭', '게임', '퍼즐', '점수'])) {
      return '작물 매칭은 같은 작물 두 칸을 눌러 짝을 맞추는 게임이에요. 한 판을 다 맞추면 다음 판으로 넘어가고 시간이 늘어요. 오늘 시세가 오른 작물(▲)을 맞추면 점수가 최대 2배, 어려움 난이도는 점수 ×1.7! 연속으로 맞추면 보너스 점수도 있어요. 하고 싶은 작물을 3~6종 직접 고를 수도 있어요 🎮';
    }

    // 10) 초보 팁·기본
    if (_has(q, ['팁', '초보', '도움', '뭐', '어떻게'])) {
      return '1) 씨앗을 심고 물을 줘요 💧\n2) 다 자라면 수확해서 창고에 넣어요 🧺\n3) 시세가 높을 때 팔아요 📈\n4) 번 돈으로 밭·창고·하우스를 키워요 🏠';
    }

    return '작물 이름(예: 배추 시세)이나 아래 추천 질문을 눌러 물어봐 주세요 🌱';
  }
}
