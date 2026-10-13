import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 날씨 종류 (날씨 카드의 설명 글에서 고른다)
enum WeatherKind { sun, mostlySunny, partlyCloudy, cloudy, drizzle, rain, snow, thunder, fog }

/// "맑음", "대체로 맑음", "구름 조금", "흐림", "이슬비", "비", "소나기", "눈", "안개", "뇌우" 같은 날씨 설명 → 그림 종류.
/// 모르는 말이면 구름.
WeatherKind weatherKindOf(String label) {
  if (label.contains('뇌우')) return WeatherKind.thunder;
  if (label.contains('눈')) return WeatherKind.snow;
  if (label.contains('안개')) return WeatherKind.fog;
  if (label.contains('이슬비')) return WeatherKind.drizzle;
  if (label.contains('소나기') || label.contains('비')) return WeatherKind.rain;
  if (label.contains('대체로')) return WeatherKind.mostlySunny;
  if (label.contains('구름 조금')) return WeatherKind.partlyCloudy;
  if (label.contains('맑')) return WeatherKind.sun;
  return WeatherKind.cloudy;
}

/// 날씨 그림: 이모티콘 글자가 아니라 코드로 그린 벡터라서 기기·글꼴과 상관없이 같은 색(맑음은 노란 해)으로 나오고, 아무리 키워도 선명하다.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.label, this.size = 44});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: WeatherPainter(weatherKindOf(label))),
      );
}

class WeatherPainter extends CustomPainter {
  const WeatherPainter(this.kind);
  final WeatherKind kind;

  static const _rain = Color(0xFF4DA3F0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);
    switch (kind) {
      case WeatherKind.sun:
        _sun(canvas, p(.5, .5), s * .24, s);
      case WeatherKind.mostlySunny:
        _sun(canvas, p(.42, .42), s * .2, s);
        _cloud(canvas, Rect.fromLTWH(s * .36, s * .5, s * .56, s * .34), light: true);
      case WeatherKind.partlyCloudy:
        _sun(canvas, p(.36, .36), s * .18, s);
        _cloud(canvas, Rect.fromLTWH(s * .26, s * .38, s * .68, s * .46), light: true);
      case WeatherKind.cloudy:
        _cloud(canvas, Rect.fromLTWH(s * .3, s * .14, s * .6, s * .4), light: false);
        _cloud(canvas, Rect.fromLTWH(s * .08, s * .34, s * .72, s * .48), light: true);
      case WeatherKind.drizzle:
        _sun(canvas, p(.34, .3), s * .15, s);
        _cloud(canvas, Rect.fromLTWH(s * .22, s * .3, s * .7, s * .42), light: true);
        _drops(canvas, s, const [(.38, .78), (.58, .78)]);
      case WeatherKind.rain:
        _cloud(canvas, Rect.fromLTWH(s * .1, s * .14, s * .8, s * .5), light: false);
        _drops(canvas, s, const [(.3, .72), (.5, .72), (.7, .72)]);
      case WeatherKind.snow:
        _cloud(canvas, Rect.fromLTWH(s * .1, s * .14, s * .8, s * .5), light: false);
        for (final f in const [(.3, .78), (.5, .84), (.7, .78)]) {
          _flake(canvas, p(f.$1, f.$2), s * .06, s);
        }
      case WeatherKind.thunder:
        _cloud(canvas, Rect.fromLTWH(s * .1, s * .12, s * .8, s * .5), light: false, dark: true);
        _bolt(canvas, s);
      case WeatherKind.fog:
        _cloud(canvas, Rect.fromLTWH(s * .12, s * .12, s * .76, s * .46), light: true);
        final line = Paint()
          ..color = const Color(0xFFB4C2CE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .06
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p(.18, .7), p(.82, .7), line);
        canvas.drawLine(p(.3, .82), p(.9, .82), line);
    }
  }

  /// 노란 해: 은은한 빛 번짐 + 둥근 광선 8개 + 그라데이션 몸통 + 하이라이트
  void _sun(Canvas canvas, Offset c, double r, double s) {
    canvas.drawCircle(c, r * 2.1, Paint()..shader = const RadialGradient(colors: [Color(0x55FFD24D), Color(0x00FFD24D)]).createShader(Rect.fromCircle(center: c, radius: r * 2.1)));
    final ray = Paint()
      ..color = const Color(0xFFFFB400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .26
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r * 1.38), c + Offset(math.cos(a), math.sin(a)) * (r * 1.8), ray);
    }
    final disc = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), radius: 1.1, colors: [Color(0xFFFFF59A), Color(0xFFFFCB1F), Color(0xFFFF9F0A)], stops: [0, .55, 1]).createShader(disc));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(.8, s * .014)..color = const Color(0xFFE08A00));
    canvas.drawCircle(c + Offset(-r * .3, -r * .34), r * .22, Paint()..color = const Color(0x66FFFFFF));
  }

  /// 구름: 둥근 덩어리들을 하나로 합친 모양 + 위는 밝고 아래는 옅은 파랑 그림자
  void _cloud(Canvas canvas, Rect b, {required bool light, bool dark = false}) {
    final w = b.width, h = b.height;
    var path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b.left, b.top + h * .42, w, h * .58), Radius.circular(h * .29)));
    path = Path.combine(PathOperation.union, path, Path()..addOval(Rect.fromCircle(center: Offset(b.left + w * .3, b.top + h * .5), radius: h * .32)));
    path = Path.combine(PathOperation.union, path, Path()..addOval(Rect.fromCircle(center: Offset(b.left + w * .6, b.top + h * .4), radius: h * .4)));
    final colors = dark
        ? const [Color(0xFF9AA8B8), Color(0xFF5E6E80)]
        : light
            ? const [Color(0xFFFFFFFF), Color(0xFFD3E4F4)]
            : const [Color(0xFFE3EBF3), Color(0xFF9FB3C8)];
    canvas.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(b));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(.8, b.width * .02)..color = dark ? const Color(0xFF4A5868) : const Color(0xFF9DB4CB));
  }

  void _drops(Canvas canvas, double s, List<(double, double)> at) {
    final p = Paint()
      ..color = _rain
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .065
      ..strokeCap = StrokeCap.round;
    for (final d in at) {
      canvas.drawLine(Offset(d.$1 * s, d.$2 * s), Offset((d.$1 - .05) * s, (d.$2 + .13) * s), p);
    }
  }

  void _flake(Canvas canvas, Offset c, double r, double s) {
    final p = Paint()
      ..color = const Color(0xFF7FB8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r, c - Offset(math.cos(a), math.sin(a)) * r, p);
    }
  }

  void _bolt(Canvas canvas, double s) {
    final bolt = Path()
      ..moveTo(s * .54, s * .56)
      ..lineTo(s * .38, s * .8)
      ..lineTo(s * .5, s * .8)
      ..lineTo(s * .42, s * .98)
      ..lineTo(s * .66, s * .7)
      ..lineTo(s * .54, s * .7)
      ..lineTo(s * .62, s * .56)
      ..close();
    canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFCB1F));
    canvas.drawPath(bolt, Paint()..style = PaintingStyle.stroke..strokeWidth = s * .02..strokeJoin = StrokeJoin.round..color = const Color(0xFFE08A00));
  }

  @override
  bool shouldRepaint(WeatherPainter old) => old.kind != kind;
}
