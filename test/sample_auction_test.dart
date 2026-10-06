import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/core/game_rules.dart';
import 'package:sise_nongbu/services/sample_auction_source.dart';

Map<String, dynamic> r(String type, String variety, String spec, num qty, num price, num kg) =>
    {'item': '배추', 'saleType': type, 'variety': variety, 'spec': spec, 'qty': qty, 'price': price, 'kg': kg};

void main() {
  final data = [
    r('경매', '김장(가을)배추', '10kg 상자', 100, 8000, 10),
    r('경매', '김장(가을)배추', '10kg 그물망', 300, 9000, 10),
    r('정가수의', '김장(가을)배추', '10kg 상자', 50, 14000, 10), // 정가수의 제외
    r('경매', '쌈배추', '2kg 상자', 10, 6000, 2), // 다른 품종 제외
    r('경매', '김장(가을)배추', '10kg 파렛트', 10, 14000, 10), // 파렛트 제외
  ];

  test('경매·김장배추만 kg당으로 환산, 파렛트 제외', () {
    final rows = SampleAuctionSource.parseRows(data, '배추', variety: '김장(가을)배추');
    expect(rows.length, 2);
    expect(weightedPrice(rows), closeTo((800 * 1000 + 900 * 3000) / 4000, 1e-9));
  });

  test('품종을 지정하지 않으면 모든 품종(경매)', () {
    expect(SampleAuctionSource.parseRows(data, '배추').length, 3);
  });

  test('다른 품목은 비어 있음', () => expect(SampleAuctionSource.parseRows(data, '무'), isEmpty));
}
