import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/game_rules.dart';
import '../models/models.dart';

class FirestoreGameService {
  FirestoreGameService(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> get _user => db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _col(String n) => _user.collection(n);

  Future<void> ensureUser() async {
    if ((await _user.get()).exists) return;
    final b = db.batch();
    b.set(_user, {'money': startMoney, 'totalProfit': 0, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    for (var i = 0; i < plotCount; i++) {
      b.set(_col('plots').doc('$i'), {'cropCode': null, 'status': 'empty', 'plantedAt': null, 'readyAt': null});
    }
    await b.commit();
  }

  Stream<Map<String, dynamic>> user() => _user.snapshots().map((s) => s.data() ?? {});
  Stream<List<Plot>> plots() => _col('plots').snapshots().map((s) => s.docs.map(Plot.fromDoc).toList()..sort((a, b) => a.index - b.index));
  Stream<List<Lot>> lots() => _col('inventory').snapshots().map((s) => s.docs.map(Lot.fromDoc).toList());
  Stream<List<Trade>> trades() =>
      _col('trades').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(Trade.fromDoc).toList());

  Future<void> plant(int idx, CropSpec c, DateTime readyAt) => db.runTransaction((tx) async {
        final u = (await tx.get(_user)).data()!;
        final money = (u['money'] as num).toInt();
        if (money < c.seedCost) throw StateError('자금이 부족해요');
        tx.update(_user, {'money': money - c.seedCost, 'totalProfit': (u['totalProfit'] as num).toInt() - c.seedCost, 'updatedAt': FieldValue.serverTimestamp()});
        tx.set(_col('plots').doc('$idx'), {'cropCode': c.code, 'status': 'growing', 'plantedAt': FieldValue.serverTimestamp(), 'readyAt': Timestamp.fromDate(readyAt)});
      });

  Future<void> harvest(int idx, CropSpec c) {
    final b = db.batch();
    b.set(_col('plots').doc('$idx'), {'cropCode': null, 'status': 'empty', 'plantedAt': null, 'readyAt': null});
    b.set(_col('inventory').doc(), {'cropCode': c.code, 'quantityKg': c.yieldKg, 'harvestedAt': FieldValue.serverTimestamp()});
    return b.commit();
  }

  /// 자금 증가 + 입고분 삭제 + 거래 기록을 한 트랜잭션으로 처리
  Future<void> sell(Lot lot, AuctionPrice p, double freshness, int amount) => db.runTransaction((tx) async {
        final u = (await tx.get(_user)).data()!;
        tx.update(_user, {
          'money': (u['money'] as num).toInt() + amount,
          'totalProfit': (u['totalProfit'] as num).toInt() + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.delete(_col('inventory').doc(lot.id));
        tx.set(_col('trades').doc(), {
          'cropCode': lot.cropCode, 'quantityKg': lot.kg, 'unitPrice': p.pricePerKg, 'freshness': freshness,
          'amount': amount, 'priceAsOf': Timestamp.fromDate(p.asOf), 'createdAt': FieldValue.serverTimestamp(),
        });
      });
}
