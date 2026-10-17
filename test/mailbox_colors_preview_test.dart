// 우체통 색 8가지가 모두 에러 없이 그려지는지 확인하고, 환경변수 PREVIEW_DIR 이 있으면 한 장에 모아 저장한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/widgets/farm_mailbox.dart';
import 'preview_font.dart';

void main() {
  testWidgets('우체통 색 8가지 (편지 있음)', (tester) async {
    await loadPreviewFonts();
    final key = GlobalKey();
    tester.view.physicalSize = const Size(960, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFFB9DC8A),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final c in mailboxColors)
              Column(mainAxisSize: MainAxisSize.min, children: [
                FarmMailbox(hasLetter: true, active: false, onTap: () {}, size: 78, color: c.$2),
                const SizedBox(height: 6),
                Text(c.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F3D2B))),
              ]),
          ]),
        ),
      ),
    ));
    expect(find.byType(FarmMailbox), findsNWidgets(mailboxColors.length));
    expect(tester.takeException(), isNull);
    await savePreview(tester, key, 'mailbox_colors', pixelRatio: 1);
  });
}
