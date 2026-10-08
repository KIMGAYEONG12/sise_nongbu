// 한글 낱말이 줄 끝에서 글자 단위로 끊기지 않는지(ka), 돈 표기가 P인지 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/widgets/common.dart';

void main() {
  test('돈은 P, 시세는 원/kg', () {
    expect(won(199455), '199,455P');
    expect(krw(1850), '1,850원');
  });

  test('ka: 한글 글자 사이에만 붙이기 기호가 들어가고 다른 글자는 그대로', () {
    expect(ka('자라요'), '자⁠라⁠요');
    expect(ka('50분 걸리는'), '50⁠분 걸⁠리⁠는'); // 숫자와 한글 사이도 붙이고, 띄어쓰기는 그대로
    expect(ka('나눠 kg당'), '나⁠눠 kg⁠당');
    expect(ka('abc'), 'abc');
    expect(ka('☀️ 맑음'), '☀️ 맑⁠음');
  });

  testWidgets('ka를 쓰면 좁은 칸에서도 낱말 중간에서 줄이 바뀌지 않는다', (tester) async {
    const text = '발표·시연용으로 작물이 빨리 자라요. 켠 뒤에 새로 심는 작물부터 적용돼요.';
    List<String> lines(String t, double width) {
      final p = TextPainter(text: TextSpan(text: t, style: const TextStyle(fontSize: 14)), textDirection: TextDirection.ltr)..layout(maxWidth: width);
      final out = <String>[];
      for (final m in p.computeLineMetrics()) {
        final start = p.getPositionForOffset(Offset(1, m.baseline - m.ascent + 1)).offset;
        out.add('$start');
      }
      return out;
    }

    // 줄 시작 위치가 모두 낱말 시작(앞이 공백)이어야 한다
    for (final w in [120.0, 150.0, 200.0, 260.0]) {
      final t = ka(text);
      final p = TextPainter(text: TextSpan(text: t, style: const TextStyle(fontSize: 14)), textDirection: TextDirection.ltr)..layout(maxWidth: w);
      var y = 1.0;
      for (final m in p.computeLineMetrics()) {
        final i = p.getLineBoundary(p.getPositionForOffset(Offset(1, y))).start;
        if (i > 0) expect(t[i - 1] == ' ' || t[i - 1] == '\n', isTrue, reason: '폭 $w: "${t.substring(i - 1, i + 1)}"에서 낱말이 끊겼어요');
        y += m.height;
      }
    }
    expect(lines(text, 90).isNotEmpty, isTrue);
    expect(growDuration(cropOf('RADISH'), demoSpeed), const Duration(seconds: 1));
    expect(growDuration(cropOf('CABBAGE'), demoSpeed), const Duration(seconds: 1));
  });
}
