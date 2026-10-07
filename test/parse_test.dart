import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/services/auction_api_service.dart';

String body(Object? item, {String code = '0'}) =>
    '{"response":{"header":{"resultCode":"$code","resultMsg":"정상"},"body":{"items":${item == null ? '""' : '{"item":$item}'},"totalCount":1}}}';
Map<String, Object> row(num p) => {AuctionApiService.priceKey: p, AuctionApiService.unitKgKey: 10, AuctionApiService.volumeKey: 5};

/// 실제 trades2 응답과 같은 모양(값이 모두 문자열)
String real(String price, String unitQty, String qty, {String unit = 'kg', String type = '경매'}) =>
    '{"scsbd_prc":"$price","unit_qty":"$unitQty","unit_nm":"$unit","qty":"$qty","trd_se":"$type"}';

void main() {
  test('item 0건', () => expect(AuctionApiService.parseRows(body(null)), isEmpty));
  test('item 빈 배열', () => expect(AuctionApiService.parseRows(body('[]')), isEmpty));
  test('item 1건(객체)', () => expect(AuctionApiService.parseRows(body(_j(row(10000)))).length, 1));
  test('item 여러 건(배열)', () => expect(AuctionApiService.parseRows(body('[${_j(row(10000))},${_j(row(20000))}]')).length, 2));

  test('실제 응답: 10kg 상자 3,500원 → kg당 350원, 거래량 = 수량 × 단위물량', () {
    final rows = AuctionApiService.parseRows(body('[${real('3500.000', '10.000', '164.000')}]'));
    expect(rows.single.pricePerKg, closeTo(350, 1e-9));
    expect(rows.single.volumeKg, closeTo(1640, 1e-9));
  });

  test('경매 건이 있으면 정가수의 건은 빼고 가중평균', () {
    final rows = AuctionApiService.parseRows(body('[${real('8000', '10', '100')},${real('9000', '10', '300')},${real('20000', '10', '50', type: '정가수의')}]'));
    expect(rows.length, 2);
    expect(weightedPrice(rows), closeTo((800 * 1000 + 900 * 3000) / 4000, 1e-9));
  });

  test('g 단위는 kg으로 환산, 무게를 알 수 없는 단위(개)는 제외', () {
    final rows = AuctionApiService.parseRows(body('[${real('5000', '500', '10', unit: 'g')},${real('3000', '1', '10', unit: '개')}]'));
    expect(rows.single.pricePerKg, closeTo(10000, 1e-9));
  });

  test('결과 코드가 정상이 아니면 예외', () {
    expect(() => AuctionApiService.parseRows(body(null, code: '30')), throwsException);
  });

  test('XML 오류 응답(인증키 오류 등)은 예외', () {
    expect(() => AuctionApiService.parseRows('<OpenAPI_ServiceResponse><returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg></OpenAPI_ServiceResponse>'),
        throwsException);
  });

  test('작물 6개 모두 품목 코드가 있다', () {
    for (final c in crops) {
      expect(AuctionApiService.itemCodes.containsKey(c.code), isTrue, reason: c.code);
    }
  });
}

String _j(Map<String, Object> m) => '{${m.entries.map((e) => '"${e.key}":${e.value}').join(',')}}';
