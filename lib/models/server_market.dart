import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/game_rules.dart';
import 'models.dart';

/// 서버(GitHub Actions → tools/update_prices.mjs)가 Firestore `market/prices` 문서에 저장한 시세.
///
/// 문서 모양
///   updatedAt : 서버가 저장한 시각
///   CABBAGE   : { price, prev, asOf: '2026-10-07', prevDate, volumeKg }
///   days      : { '2026-10-07': { CABBAGE: { p, v }, ... }, ... }   (최근 30일, 한국 날짜)
class ServerMarket {
  const ServerMarket(this.prices, this.updatedAt, this.days);

  /// 시세판에 쓰는 품목별 시세 (작물 코드 → 시세)
  final Map<String, AuctionPrice> prices;
  final DateTime? updatedAt;
  final Map<String, dynamic> days;

  static const path = 'market/prices';

  /// 서버가 이 시간 안에 저장했으면 "살아 있다"고 본다.
  /// (GitHub 예약 실행은 늦어지기도 해서 10분 주기보다 넉넉하게 잡는다)
  static const staleAfter = Duration(minutes: 60);

  bool get fresh => updatedAt != null && DateTime.now().difference(updatedAt!) < staleAfter && prices.isNotEmpty;

  /// 앱이 이 서버 시세를 써도 되는지.
  /// 최근 것이면 당연히 쓰고, 앱에 API 키가 없으면(직접 조회 불가) 조금 오래됐어도 가짜 샘플 대신 실제 시세인 이쪽을 쓴다.
  bool usable({required bool appHasKey}) => prices.isNotEmpty && (fresh || !appHasKey);

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// 한국 날짜 기준의 "지금" (에뮬레이터·기기 시간대와 상관없이)
  static DateTime kstNow() => DateTime.now().toUtc().add(const Duration(hours: 9));

  double? _value(String day, String code, String key) {
    final e = days[day];
    if (e is! Map) return null;
    final c = e[code];
    if (c is! Map) return null;
    final v = c[key];
    return v is num ? v.toDouble() : null;
  }

  /// 최근 [count]일의 kg당 시세 (오래된 날 → 오늘). 그날 거래가 없으면 null.
  List<double?> history(String code, {int count = 7}) {
    final t = kstNow();
    return [for (var i = count - 1; i >= 0; i--) _value(ymd(t.subtract(Duration(days: i))), code, 'p')];
  }

  /// [date] 하루 거래량(kg)
  double? volumeKg(String code, DateTime date) => _value(ymd(date), code, 'v');

  static ServerMarket? fromDoc(Map<String, dynamic>? d) {
    if (d == null) return null;
    final prices = <String, AuctionPrice>{};
    for (final c in crops) {
      final m = d[c.code];
      if (m is! Map) continue;
      final p = m['price'];
      if (p is! num || p <= 0) continue;
      final asOf = DateTime.tryParse('${m['asOf']}') ?? DateTime.now();
      final prev = m['prev'];
      prices[c.code] = AuctionPrice(c.code, p.toDouble(), asOf, prevPerKg: prev is num ? prev.toDouble() : null);
    }
    final ts = d['updatedAt'];
    final days = d['days'];
    return ServerMarket(prices, ts is Timestamp ? ts.toDate() : null, days is Map ? Map<String, dynamic>.from(days) : const {});
  }
}
