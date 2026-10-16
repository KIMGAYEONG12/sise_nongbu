// AI 도우미에 보내는 상황 글: 아이템과 게임 안내(작물 매칭 점수 등)가 들어가야 한다
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/ai/ai_agent.dart';

void main() {
  test('아이템과 게임 안내가 함께 들어간다', () {
    final t = const AiContext(prices: {}, money: 1000, lots: [], plots: [], items: {'water': 10, 'seed_FIG': 2, 'booster': 0}).toText();
    expect(t, contains('물통 10개'));
    expect(t, contains('무화과 씨앗 2개'));
    expect(t, isNot(contains('성장촉진제 0개')));
    expect(t, contains('[게임 안내]'));
    expect(t, contains('작물 매칭'));
  });
}
