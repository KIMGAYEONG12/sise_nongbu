// 돈 표기(P)와 한글 줄바꿈 위젯(KoText)을 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/core/match_logic.dart';
import 'package:sise_nongbu/widgets/common.dart';

void main() {
  test('돈은 P, 시세는 원/kg', () {
    expect(won(199455), '199,455P');
    expect(krw(1850), '1,850원');
  });

  test('데모 모드는 어떤 작물이든 1초', () {
    expect(growDuration(cropOf('RADISH'), demoSpeed), const Duration(seconds: 1));
    expect(growDuration(cropOf('CABBAGE'), demoSpeed), const Duration(seconds: 1));
  });

  test('작물 매칭 힌트: 알려 준 두 칸을 바꾸면 실제로 맞춰진다', () {
    for (var i = 0; i < 30; i++) {
      final b = MatchBoard(6, 5, 4);
      final h = b.findHint();
      if (h == null) continue;
      expect(b.trySwap(h.$1, h.$2, h.$3, h.$4), isNotNull);
    }
  });

  testWidgets('KoText: 좁은 칸에서도 낱말은 끊기지 않고 띄어쓰기에서만 줄이 바뀐다', (tester) async {
    const text = '시간이 지나면 작물이 성장하고,\n수확할 수 있게 됩니다.';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 120, child: KoText(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14))))),
    ));
    // 낱말 하나하나가 통째로 있다 (글자 단위로 쪼개지지 않는다)
    for (final w in ['시간이', '지나면', '작물이', '성장하고,', '수확할', '수', '있게', '됩니다.']) {
      expect(find.text(w), findsOneWidget, reason: w);
    }
    // 같은 줄에 두 낱말이 같이 놓일 때 말고는 낱말이 항상 한 덩어리(Text 하나)라서, 폭이 좁아도 낱말 중간에서 끊길 수 없다
    expect(tester.takeException(), isNull);
  });
}
