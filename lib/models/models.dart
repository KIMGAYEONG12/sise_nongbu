import 'package:cloud_firestore/cloud_firestore.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;
DateTime? _dt(Object? v) => (v as Timestamp?)?.toDate();

class AuctionPrice {
  const AuctionPrice(this.code, this.pricePerKg, this.asOf, {this.prevPerKg});
  final String code;
  final double pricePerKg;
  final DateTime asOf;
  final double? prevPerKg;
  double? get change => prevPerKg == null ? null : pricePerKg - prevPerKg!;
}

class Plot {
  const Plot(this.index, this.cropCode, this.readyAt);
  final int index;
  final String? cropCode;
  final DateTime? readyAt;
  bool get isEmpty => cropCode == null;
  bool isReady(DateTime now) => !isEmpty && readyAt != null && !now.isBefore(readyAt!);
  factory Plot.fromDoc(Doc d) {
    final m = d.data()!;
    return Plot(int.parse(d.id), m['cropCode'] as String?, _dt(m['readyAt']));
  }
}

class Lot {
  const Lot(this.id, this.cropCode, this.kg, this.harvestedAt);
  final String id, cropCode;
  final double kg;
  final DateTime harvestedAt;
  factory Lot.fromDoc(Doc d) {
    final m = d.data()!;
    return Lot(d.id, m['cropCode'], (m['quantityKg'] as num).toDouble(), _dt(m['harvestedAt']) ?? DateTime.now());
  }
}

class Trade {
  const Trade(this.cropCode, this.kg, this.unitPrice, this.freshness, this.amount, this.priceAsOf, this.createdAt);
  final String cropCode;
  final double kg, unitPrice, freshness;
  final int amount;
  final DateTime? priceAsOf, createdAt;
  factory Trade.fromDoc(Doc d) {
    final m = d.data()!;
    return Trade(m['cropCode'], (m['quantityKg'] as num).toDouble(), (m['unitPrice'] as num).toDouble(),
        (m['freshness'] as num).toDouble(), (m['amount'] as num).toInt(), _dt(m['priceAsOf']), _dt(m['createdAt']));
  }
}
