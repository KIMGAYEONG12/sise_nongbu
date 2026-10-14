// MY 화면이 비지 않고 그려진다 (보유 포인트·금액 카드, 나의 칭호, 메뉴).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/progress_rules.dart';
import 'package:sise_nongbu/models/models.dart';
import 'package:sise_nongbu/services/auth_service.dart';
import 'package:sise_nongbu/viewmodels/view_models.dart';
import 'package:sise_nongbu/views/my_page.dart';

/// 테스트용 가짜 로그인 서비스 (Firebase 없이도 MY 화면이 그려지게 한다)
class _FakeAuth implements AuthService {
  @override
  bool get isGuest => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('칭호는 레벨에 따라 바뀌고 이름이 모두 다르다', () {
    expect(farmerTitles[farmerTitleIndex(1)].name, '새싹 농부');
    expect(farmerTitles[farmerTitleIndex(2)].name, '새싹 농부');
    expect(farmerTitles[farmerTitleIndex(3)].name, '초보 농부');
    expect(farmerTitles[farmerTitleIndex(9)].name, '베테랑 농부');
    expect(farmerTitles[farmerTitleIndex(17)].name, '전설의 농부');
    expect(farmerTitles[farmerTitleIndex(30)].name, '대농장주');
    expect(farmerTitles[farmerTitleIndex(999)].name, '농부의 신');
    // 레벨 기준이 앞에서부터 차례대로 커진다
    for (var i = 1; i < farmerTitles.length; i++) {
      expect(farmerTitles[i].minLevel, greaterThan(farmerTitles[i - 1].minLevel));
    }
    // 레벨이 한 번 오를 때마다 칭호 단계가 1씩 오르고, 칭호가 바뀌면 1단계부터 다시 시작한다
    expect([for (final l in [1, 2, 3, 4, 5, 9, 10, 11]) farmerTitleRank(l)], [1, 2, 1, 2, 1, 3, 1, 2]);
    expect(farmerTitleRank(0), 1);
    expect(farmerTitles.map((t) => t.name).toSet().length, farmerTitles.length);
  });

  for (final size in const [Size(360, 640), Size(411, 891)]) {
    testWidgets('MY 화면 ${size.width.toInt()}x${size.height.toInt()}: 에러 없이 그려진다', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userDataProvider.overrideWithValue(const UserData({'exp': 1500, 'money': 79684, 'points': 1865, 'nickname': '농부이서'})),
          authServiceProvider.overrideWithValue(_FakeAuth()),
          isGuestProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: const MaterialApp(home: Scaffold(body: MyPage())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull); // "BoxConstraints forces an infinite height" 같은 오류가 없어야 한다
      expect(find.text('농부이서'), findsOneWidget);
      expect(find.text('보유 포인트'), findsOneWidget);
      expect(find.text('보유 금액'), findsOneWidget);
      expect(find.text('나의 칭호'), findsOneWidget);
      expect(find.text('업적'), findsOneWidget);
      expect(find.text('작물 도감'), findsOneWidget);
      expect(find.text('전국 농부 뉴스'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('로그아웃'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('로그아웃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
