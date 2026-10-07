// 위젯 테스트: Firebase 없이 그릴 수 있는 공용 위젯과 밭 격자를 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/widgets/common.dart';
import 'package:sise_nongbu/widgets/farm_scene.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))));

void main() {
  testWidgets('등락 표시: 오르면 ▲, 내리면 ▼', (tester) async {
    await tester.pumpWidget(_wrap(const Column(children: [ChangeChip(percent: 12.4), ChangeChip(percent: -5.2)])));
    expect(find.text('▲'), findsOneWidget);
    expect(find.text('+12.4%'), findsOneWidget);
    expect(find.text('▼'), findsOneWidget);
    expect(find.text('-5.2%'), findsOneWidget);
  });

  testWidgets('변동 없음(0.0%)은 ▲가 아니라 – 로 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(const ChangeChip(percent: 0.0)));
    expect(find.text('▲'), findsNothing);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
  });

  testWidgets('초록 버튼을 누르면 콜백이 불린다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(GreenButton(label: '다음', onPressed: () => tapped++)));
    await tester.tap(find.text('다음'));
    expect(tapped, 1);
  });

  testWidgets('밭 6칸은 3열 × 2줄로 놓이고 빈 밭을 누를 수 있다', (tester) async {
    final plots = [for (var i = 0; i < 6; i++) Plot(i, null, null)];
    Plot? tappedPlot;
    await tester.pumpWidget(_wrap(SoilBoard(plots: plots, now: DateTime(2026, 10, 7), onTap: (p) => tappedPlot = p)));
    final tiles = find.byType(PlotTile);
    expect(tiles, findsNWidgets(6));
    // 첫 줄 세 칸은 같은 높이(y)에 있어야 한다 (예전에는 2열로 밀리는 버그가 있었다)
    final y0 = tester.getTopLeft(tiles.at(0)).dy;
    expect(tester.getTopLeft(tiles.at(1)).dy, y0);
    expect(tester.getTopLeft(tiles.at(2)).dy, y0);
    expect(tester.getTopLeft(tiles.at(3)).dy, greaterThan(y0));
    await tester.tap(tiles.at(4));
    expect(tappedPlot?.index, 4);
  });
}
