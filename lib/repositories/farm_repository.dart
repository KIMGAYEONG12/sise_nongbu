import '../core/game_rules.dart';
import '../models/models.dart';
import '../services/firestore_game_service.dart';
import '../services/notification_service.dart';

class FarmRepository {
  FarmRepository(this._db, this._noti);
  final FirestoreGameService _db;
  final NotificationService _noti;

  Stream<Map<String, dynamic>> user() => _db.user();
  Stream<List<Plot>> plots() => _db.plots();
  Stream<List<Lot>> lots() => _db.lots();
  Stream<List<Trade>> trades() => _db.trades();

  Future<void> plant(int idx, CropSpec c, DateTime readyAt) async {
    await _db.plant(idx, c, readyAt);
    await _noti.scheduleHarvest(idx, c.name, readyAt);
  }

  Future<void> harvest(int idx, CropSpec c) async {
    await _db.harvest(idx, c);
    await _noti.cancel(idx);
  }

  Future<void> sell(Lot lot, AuctionPrice p, DateTime now) {
    final f = freshnessOf(lot.harvestedAt, now);
    return _db.sell(lot, p, f, saleAmount(lot.kg, p.pricePerKg, f));
  }

  Future<String?> fcmToken() => _noti.fcmToken();
}
