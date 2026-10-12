// 미리보기 그림(PREVIEW_DIR)을 저장하는 테스트에서만 쓴다.
// 테스트 환경에는 글꼴이 없어서 글자가 네모로 나오므로, Windows의 맑은 고딕(한글·영문)과 Segoe UI Emoji를 불러와서
// 실제 앱과 비슷한 글자로 그려 본다. 글꼴 파일이 없으면 아무것도 하지 않는다(그림 저장만 네모 글자로 나온다).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadPreviewFonts() async {
  final dir = Platform.environment['PREVIEW_FONT_DIR'] ?? 'C:/Windows/Fonts';
  Future<void> load(String family, List<String> files) async {
    final bytes = <Future<ByteData>>[];
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) bytes.add(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    if (bytes.isEmpty) return;
    final loader = FontLoader(family);
    for (final b in bytes) {
      loader.addFont(b);
    }
    await loader.load();
  }

  // 앱 기본 글꼴 이름(Roboto)으로 등록하면 모든 글자가 한글까지 제대로 나온다
  await load('Roboto', ['malgun.ttf', 'malgunbd.ttf']);
  await load('Segoe UI Emoji', ['seguiemj.ttf']);
}

/// 환경변수 PREVIEW_DIR 이 있을 때만 [key] 화면을 PNG로 저장한다.
Future<void> savePreview(WidgetTester tester, GlobalKey key, String name, {double pixelRatio = 2}) async {
  final dir = Platform.environment['PREVIEW_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: pixelRatio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
