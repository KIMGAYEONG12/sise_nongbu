// 날씨 그림: 날씨 설명 → 그림 종류, 모든 종류가 에러 없이 그려진다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/services/weather_service.dart';
import 'package:sise_nongbu/widgets/weather_icon.dart';

void main() {
  test('날씨 설명마다 알맞은 그림 종류가 고른다 (맑음은 해)', () {
    expect(weatherKindOf('맑음'), WeatherKind.sun);
    expect(weatherKindOf('대체로 맑음'), WeatherKind.mostlySunny);
    expect(weatherKindOf('구름 조금'), WeatherKind.partlyCloudy);
    expect(weatherKindOf('흐림'), WeatherKind.cloudy);
    expect(weatherKindOf('구름'), WeatherKind.cloudy);
    expect(weatherKindOf('이슬비'), WeatherKind.drizzle);
    expect(weatherKindOf('비'), WeatherKind.rain);
    expect(weatherKindOf('소나기'), WeatherKind.rain);
    expect(weatherKindOf('눈'), WeatherKind.snow);
    expect(weatherKindOf('안개'), WeatherKind.fog);
    expect(weatherKindOf('뇌우'), WeatherKind.thunder);
    expect(weatherKindOf('알 수 없음'), WeatherKind.cloudy);
  });

  test('날씨 서비스가 내는 모든 설명이 그림 종류에 연결된다', () {
    final labels = <String>{
      for (var c = 0; c <= 99; c++) WeatherService.describe(c).$1,
      for (final id in [200, 300, 500, 511, 520, 600, 700, 800, 801, 802, 803, 999]) WeatherService.describeOpenWeather(id).$1,
    };
    for (final l in labels) {
      expect(WeatherKind.values.contains(weatherKindOf(l)), isTrue, reason: l);
    }
    expect(weatherKindOf(WeatherService.describe(0).$1), WeatherKind.sun);
    expect(weatherKindOf(WeatherService.describeOpenWeather(800).$1), WeatherKind.sun);
  });

  testWidgets('모든 날씨 그림이 에러 없이 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(children: [
          for (final l in ['맑음', '대체로 맑음', '구름 조금', '흐림', '이슬비', '비', '눈', '안개', '뇌우']) WeatherIcon(label: l, size: 46),
        ]),
      ),
    ));
    expect(find.byType(WeatherIcon), findsNWidgets(9));
    expect(tester.takeException(), isNull);
  });
}
