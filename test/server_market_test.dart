import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sise_nongbu/models/server_market.dart';

void main() {
  final today = ServerMarket.ymd(ServerMarket.kstNow());
  final yesterday = ServerMarket.ymd(ServerMarket.kstNow().subtract(const Duration(days: 1)));

  Map<String, dynamic> doc({DateTime? updatedAt}) => {
        'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
        'CABBAGE': {'price': 815.4, 'prev': 857.0, 'asOf': today, 'volumeKg': 4000},
        'RADISH': {'price': 686, 'prev': null, 'asOf': yesterday},
        'BROKEN': {'price': 'x'},
        'days': {
          today: {'done': true, 'CABBAGE': {'p': 815.4, 'v': 4000}},
          yesterday: {'done': true, 'CABBAGE': {'p': 857.0, 'v': 3500}},
        },
      };

  test('서버 문서를 시세로 바꾼다', () {
    final s = ServerMarket.fromDoc(doc())!;
    expect(s.prices.keys, containsAll(['CABBAGE', 'RADISH']));
    expect(s.prices['CABBAGE']!.pricePerKg, 815.4);
    expect(s.prices['CABBAGE']!.prevPerKg, 857.0);
    expect(s.prices['RADISH']!.prevPerKg, isNull);
    expect(s.fresh, isTrue);
  });

  test('오래된 서버 시세는 fresh가 아니다 (앱이 직접 API를 부른다)', () {
    final s = ServerMarket.fromDoc(doc(updatedAt: DateTime.now().subtract(const Duration(hours: 3))))!;
    expect(s.fresh, isFalse);
  });

  test('최근 7일 그래프: 오래된 날 → 오늘, 없는 날은 null', () {
    final h = ServerMarket.fromDoc(doc())!.history('CABBAGE');
    expect(h.length, 7);
    expect(h.last, 815.4);
    expect(h[5], 857.0);
    expect(h.first, isNull);
  });

  test('문서가 없으면 null', () => expect(ServerMarket.fromDoc(null), isNull));
}
