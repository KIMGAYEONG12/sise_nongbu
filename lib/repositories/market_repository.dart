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

  Future<Map<String, AuctionPrice>> fetch({bool force = false}) async {
    if (_cache != null && _at != null && DateTime.now().difference(_at!) < minInterval && !force) return _cache!;
    final out = <String, AuctionPrice>{};
    final now = DateTime.now();
    for (final c in crops) {
      try {
        // 경매 시간이 아니면 비어 있을 수 있어 하루 전으로 재조회
        var p = weightedPrice(await _src.rows(c.code, now));
        var asOf = now;
        if (p == null) {
          asOf = now.subtract(const Duration(days: 1));
          p = weightedPrice(await _src.rows(c.code, asOf));
        }
        if (p == null) throw StateError('no data');
        final prev = weightedPrice(await _src.rows(c.code, asOf.subtract(const Duration(days: 1))));
        out[c.code] = AuctionPrice(c.code, p, asOf, prevPerKg: prev);
        _prefs.setString('price_${c.code}', '$p|${asOf.toIso8601String()}');
      } catch (_) {
        final saved = _prefs.getString('price_${c.code}')?.split('|'); // 마지막 성공 시세로 계속 진행
        if (saved != null) out[c.code] = AuctionPrice(c.code, double.parse(saved[0]), DateTime.parse(saved[1]));
      }
    }
    _at = now;
    return _cache = out;
  }
}
