import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import '../services/auction_api_service.dart';

class MarketRepository {
  MarketRepository(this._src, this._prefs);
  final AuctionSource _src;
  final SharedPreferences _prefs;
  static const minInterval = Duration(minutes: 10);
  Map<String, AuctionPrice>? _cache;
  DateTime? _at;

  /// 마지막으로 시세를 조회한 시각
  DateTime? get fetchedAt => _at;

  Future<Map<String, AuctionPrice>> fetch({bool force = false}) async {
    if (_cache != null && _at != null && DateTime.now().difference(_at!) < minInterval && !force) return _cache!;
    final out = <String, AuctionPrice>{};
    final now = DateTime.now();
    // 품목 6개를 동시에 조회해 시세판이 빨리 뜨게 한다
    Future<void> one(CropSpec c) async {
      try {
        // 오늘 경매가 아직 없거나 휴장일(일요일·명절)이면 최근 7일 안에서 거래가 있었던 가장 최근 날을 쓴다
        double? p;
        var asOf = now;
        for (var i = 0; i < 7 && p == null; i++) {
          final d = now.subtract(Duration(days: i));
          final v = weightedPrice(await _src.rows(c.code, d));
          if (v != null) {
            p = v;
            asOf = d;
          }
        }
        if (p == null) throw StateError('no data');
        // 비교할 전일 시세: 그 전에 거래가 있었던 날 (휴장일은 건너뛴다). 못 구해도 오늘 시세는 그대로 쓴다.
        double? prev;
        try {
          for (var i = 1; i <= 7 && prev == null; i++) {
            prev = weightedPrice(await _src.rows(c.code, asOf.subtract(Duration(days: i))));
          }
        } catch (_) {
          prev = null;
        }
        out[c.code] = AuctionPrice(c.code, p, asOf, prevPerKg: prev);
        _prefs.setString('price_${c.code}', '$p|${asOf.toIso8601String()}');
      } catch (_) {
        final saved = _prefs.getString('price_${c.code}')?.split('|'); // 마지막 성공 시세로 계속 진행
        if (saved != null && saved.length == 2) {
          final v = double.tryParse(saved[0]), at = DateTime.tryParse(saved[1]);
          if (v != null && at != null) out[c.code] = AuctionPrice(c.code, v, at);
        }
      }
    }

    await Future.wait(crops.map(one));
    _at = now;
    return _cache = out;
  }

  /// 최근 [days]일의 kg당 시세(오래된 날 → 오늘). 그날 데이터가 없으면 null.
  Future<List<double?>> history(String cropCode, {int days = 7}) async {
    final now = DateTime.now();
    final out = <double?>[];
    for (var i = days - 1; i >= 0; i--) {
      try {
        out.add(weightedPrice(await _src.rows(cropCode, now.subtract(Duration(days: i)))));
      } catch (_) {
        out.add(null);
      }
    }
    return out;
  }

  /// [date] 하루 동안의 총 경매 거래량(kg). 조회에 실패하면 null.
  Future<double?> volumeKg(String cropCode, DateTime date) async {
    try {
      final rows = await _src.rows(cropCode, date);
      return rows.fold<double>(0, (a, r) => a + r.volumeKg);
    } catch (_) {
      return null;
    }
  }
}
