import 'dart:convert';
import 'package:http/http.dart' as http;

class Weather {
  const Weather(this.tempC, this.label, this.emoji);
  final double tempC;
  final String label, emoji;
}

/// Open-Meteo(무료, API 키 없음)로 현재 날씨를 가져온다. 실패하면 null.
class WeatherService {
  WeatherService(this.client);
  final http.Client client;

  // 기준 위치: 서울 (원하는 도시 좌표로 바꾸면 된다)
  static const latitude = 37.5665, longitude = 126.9780;

  Future<Weather?> current() async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'current': 'temperature_2m,weather_code',
        'timezone': 'Asia/Seoul',
      });
      final res = await client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final cur = jsonDecode(utf8.decode(res.bodyBytes))['current'];
      if (cur is! Map) return null;
      final temp = (cur['temperature_2m'] as num?)?.toDouble();
      final code = (cur['weather_code'] as num?)?.toInt();
      if (temp == null || code == null) return null;
      final d = describe(code);
      return Weather(temp, d.$1, d.$2);
    } catch (_) {
      return null;
    }
  }

  /// WMO 날씨 코드 → (설명, 이모지)
  static (String, String) describe(int code) {
    if (code == 0) return ('맑음', '☀️');
    if (code == 1) return ('대체로 맑음', '🌤️');
    if (code == 2) return ('구름 조금', '⛅');
    if (code == 3) return ('흐림', '☁️');
    if (code == 45 || code == 48) return ('안개', '🌫️');
    if (code >= 51 && code <= 57) return ('이슬비', '🌦️');
    if (code >= 61 && code <= 67) return ('비', '🌧️');
    if (code >= 71 && code <= 77) return ('눈', '❄️');
    if (code >= 80 && code <= 82) return ('소나기', '🌧️');
    if (code == 85 || code == 86) return ('눈', '🌨️');
    if (code >= 95) return ('뇌우', '⛈️');
    return ('구름', '☁️');
  }
}
