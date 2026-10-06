import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/game_rules.dart';

const auctionApiKey = String.fromEnvironment('AUCTION_API_KEY');

abstract class AuctionSource {
  Future<List<AuctionRow>> rows(String cropCode, DateTime date);
}

/// 공공데이터포털 전국 공영도매시장 실시간 경매정보 API.
/// TODO: 아래 상수는 첨부된 API 명세서를 보고 확정한다 (형식 예시일 뿐).
class AuctionApiService implements AuctionSource {
  AuctionApiService(this.client);
  final http.Client client;
  static const baseUrl = 'https://apis.data.go.kr/TODO_기관코드/TODO_서비스/TODO_오퍼레이션';
  static const dateParam = 'TODO_조회일자', itemParam = 'TODO_품목코드', marketParam = 'TODO_도매시장코드';
  static const marketCode = 'TODO';
  static const priceKey = 'TODO_가격', unitKgKey = 'TODO_단위중량', volumeKey = 'TODO_거래량';

  @override
  Future<List<AuctionRow>> rows(String cropCode, DateTime date) async {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'serviceKey': auctionApiKey, dateParam: d, itemParam: cropCode, marketParam: marketCode, '_type': 'json',
    });
    final res = await client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('API ${res.statusCode}');
    return parseRows(utf8.decode(res.bodyBytes));
  }

  /// item이 0건(없음)/1건(객체)/여러 건(배열)인 경우를 모두 처리. 환산 불가 건은 제외.
  static List<AuctionRow> parseRows(String body) {
    final box = jsonDecode(body)['response']?['body']?['items'];
    final items = box is Map ? box['item'] : null; // 0건이면 items가 빈 문자열일 수 있음
    final list = items == null ? [] : (items is List ? items : [items]);
    final out = <AuctionRow>[];
    for (final it in list) {
      final price = double.tryParse('${it[priceKey]}'), unit = double.tryParse('${it[unitKgKey]}');
      final vol = double.tryParse('${it[volumeKey]}');
      if (price == null || unit == null || vol == null) continue;
      final perKg = toPricePerKg(price, unit);
      if (perKg != null) out.add(AuctionRow(perKg, vol * unit));
    }
    return out;
  }
}

/// 키가 없거나 API 확정 전 개발용. 날짜별로 변하는 가짜 시세.
class FakeAuctionSource implements AuctionSource {
  static const _base = {'CABBAGE': 1000, 'RADISH': 800, 'ONION': 1200, 'APPLE': 3500, 'TOMATO': 3000, 'POTATO': 2000};
  @override
  Future<List<AuctionRow>> rows(String cropCode, DateTime date) async {
    final day = date.difference(DateTime(2026)).inDays;
    final wave = 1 + 0.4 * sin(day * 1.3 + cropCode.hashCode % 7);
    return [AuctionRow((_base[cropCode] ?? 1000) * wave, 500)];
  }
}
