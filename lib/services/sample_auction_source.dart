import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../core/game_rules.dart';
import 'auction_api_service.dart';

/// 실제 경매 현황 엑셀(at.agromarket.kr 실시간 경매현황)을 JSON으로 바꿔 assets에 넣은 개발용 시세.
/// 스냅샷이라 값이 바뀌지 않는다. 데이터가 없는 품목은 [fallback]으로 채운다.
class SampleAuctionSource implements AuctionSource {
  SampleAuctionSource(this.fallback);
  final AuctionSource fallback;

  static const asset = 'assets/auction_sample.json';

  /// 게임 작물 코드 → 경매현황의 품목명
  static const itemNames = {'CABBAGE': '배추'};

  /// 시세판에 쓸 건의 조건 (JSON에는 전체 건이 들어 있고 여기서만 거른다)
  static const saleType = '경매';
  static const varieties = {'CABBAGE': '김장(가을)배추'};
  static const excludeSpec = '파렛트'; // 파렛트 표기의 실제 중량을 알 수 없어 제외

  /// 스냅샷의 거래일자. 이 날짜 이후 조회에는 스냅샷을, 이전 날짜에는 빈 목록을 돌려준다.
  static final tradeDate = DateTime(2026, 10, 6);

  List<Map<String, dynamic>>? _data;

  Future<List<Map<String, dynamic>>> _load() async =>
      _data ??= (jsonDecode(await rootBundle.loadString(asset)) as List).cast<Map<String, dynamic>>();

  @override
  Future<List<AuctionRow>> rows(String cropCode, DateTime date) async {
    final item = itemNames[cropCode];
    if (item == null) return fallback.rows(cropCode, date);
    if (DateTime(date.year, date.month, date.day).isBefore(tradeDate)) return [];
    return parseRows(await _load(), item, variety: varieties[cropCode]);
  }

  /// JSON 건 목록 → AuctionRow. 환산 불가 건은 제외.
  static List<AuctionRow> parseRows(List<Map<String, dynamic>> data, String item, {String? variety}) {
    final out = <AuctionRow>[];
    for (final r in data) {
      if (r['item'] != item || r['saleType'] != saleType) continue;
      if (variety != null && r['variety'] != variety) continue;
      if ('${r['spec']}'.contains(excludeSpec)) continue;
      final price = (r['price'] as num?)?.toDouble();
      final kg = (r['kg'] as num?)?.toDouble();
      final qty = (r['qty'] as num?)?.toDouble();
      if (price == null || kg == null || qty == null) continue;
      final perKg = toPricePerKg(price, kg);
      if (perKg != null) out.add(AuctionRow(perKg, qty * kg));
    }
    return out;
  }
}
