import 'dart:convert';
import 'package:http/http.dart' as http;

class Weather {
  const Weather(this.tempC, this.label, this.emoji);
  final double tempC;
  final String label, emoji;
}

/// OpenWeather API 키 (env.json의 OPENWEATHER_API_KEY → --dart-define-from-file=env.json 으로 들어온다)
const openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');

/// 현재 날씨를 가져온다.
/// 1) OpenWeather 키가 있으면 OpenWeather(현재 날씨 API)를 먼저 쓰고,
/// 2) 키가 없거나 실패하면(새 키는 활성화까지 몇 시간 걸릴 수 있음) Open-Meteo(무료, 키 없음)로 가져온다.
/// 둘 다 실패하면 null.
class WeatherService {
  WeatherService(this.client);
  final http.Client client;

  // 기준 위치: 서울 (원하는 도시 좌표로 바꾸면 된다)
  static const latitude = 37.5665, longitude = 126.9780;

  Future<Weather?> current() async {
    if (openWeatherApiKey.isNotEmpty) {
      final w = await _openWeather();
      if (w != null) return w;
    }
    return _openMeteo();
  }

  Future<Weather?> _openWeather() async {
    try {
      final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
        'lat': '$latitude',
        'lon': '$longitude',
        'appid': openWeatherApiKey,
        'units': 'metric',
        'lang': 'kr',
      });
      final res = await client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null; // 401: 키가 아직 활성화 전이거나 잘못됨
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;
      final temp = (body['main'] is Map ? (body['main'] as Map)['temp'] : null) as num?;
      final list = body['weather'];
      final id = (list is List && list.isNotEmpty && list.first is Map) ? ((list.first as Map)['id'] as num?)?.toInt() : null;
      if (temp == null || id == null) return null;
      final d = describeOpenWeather(id);
      return Weather(temp.toDouble(), d.$1, d.$2);
    } catch (_) {
      return null;
    }
  }

  /// OpenWeather 날씨 코드 → (설명, 이모지). 설명은 Open-Meteo와 같은 말을 써서 날씨 카드 문구가 똑같이 나온다.
  static (String, String) describeOpenWeather(int id) {
    if (id >= 200 && id < 300) return ('뇌우', '⛈️');
    if (id >= 300 && id < 400) return ('이슬비', '🌦️');
    if (id == 511) return ('비', '🌧️');
    if (id >= 520 && id < 600) return ('소나기', '🌧️');
    if (id >= 500 && id < 600) return ('비', '🌧️');
    if (id >= 600 && id < 700) return ('눈', '❄️');
    if (id >= 700 && id < 800) return ('안개', '🌫️');
    if (id == 800) return ('맑음', '☀️');
    if (id == 801) return ('대체로 맑음', '🌤️');
    if (id == 802) return ('구름 조금', '⛅');
    if (id == 803 || id == 804) return ('흐림', '☁️');
    return ('구름', '☁️');
  }

  Future<Weather?> _openMeteo() async {
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
