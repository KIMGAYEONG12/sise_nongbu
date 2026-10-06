import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/services/auction_api_service.dart';

String body(Object? item) => '{"response":{"body":{"items":${item == null ? '""' : '{"item":$item}'}}}}';
Map<String, Object> row(num p) => {AuctionApiService.priceKey: p, AuctionApiService.unitKgKey: 10, AuctionApiService.volumeKey: 5};

void main() {
  // 명세서 확정 후 키 상수를 채우면 통과한다 (현재는 TODO 키 이름으로 동작)
  test('item 0건', () => expect(AuctionApiService.parseRows(body(null)), isEmpty));
  test('item 1건(객체)', () => expect(AuctionApiService.parseRows(body(_j(row(10000)))).length, 1));
  test('item 여러 건(배열)', () => expect(AuctionApiService.parseRows(body('[${_j(row(10000))},${_j(row(20000))}]')).length, 2));
}

String _j(Map<String, Object> m) => '{${m.entries.map((e) => '"${e.key}":${e.value}').join(',')}}';
