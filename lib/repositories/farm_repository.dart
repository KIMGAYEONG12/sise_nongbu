import '../core/game_rules.dart';
import '../core/progress_rules.dart';
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
  Stream<FundData> fund() => _db.fund();

  Future<void> ensureUser({String? nickname}) => _db.ensureUser(nickname: nickname);
  Future<void> setNickname(String name) => _db.setNickname(name);

  Future<void> plant(int idx, CropSpec c, DateTime readyAt) async {
    await _db.plant(idx, c, readyAt);
    await _noti.scheduleHarvest(idx, c.name, readyAt);
  }

  /// 수확하고 수확량(kg)을 돌려준다.
  Future<double> harvest(int idx, CropSpec c) async {
    final kg = await _db.harvest(idx, c);
    await _noti.cancel(idx);
    return kg;
  }

  Future<void> sell(Lot lot, AuctionPrice p, DateTime now) {
    final f = freshnessOf(lot.harvestedAt, now);
    return _db.sell(lot, p, f, saleAmount(lot.kg, p.pricePerKg, f), now: now);
  }

  /// 아이템을 쓰고, 수확 시각이 바뀌었으면 알림을 다시 예약한다.
  Future<void> useItem(int idx, CropSpec c, String key) async {
    final ready = await _db.useItem(idx, key);
    if (ready != null) await _noti.scheduleHarvest(idx, c.name, ready);
  }

  Future<void> buyItem(String key, int price, {int qty = 1}) => _db.buyItem(key, price, qty: qty);
  Future<void> expandPlots(int currentCount) => _db.expandPlots(currentCount);
  Future<void> expandWarehouse() => _db.expandWarehouse();
  Future<void> buyGreenhouse() => _db.buyGreenhouse();
  Future<void> buyPointItem(String key, {String? cropCode}) => _db.buyPointItem(key, cropCode: cropCode);
  Future<void> claimMission(MissionDef def) => _db.claimMission(def);
  Future<void> claimAchievement(AchievementDef def, int plots) => _db.claimAchievement(def, plots);
  Future<void> donateToFund(int amount) => _db.donateToFund(amount);
  Future<void> claimFundMilestone(FundMilestone m) => _db.claimFundMilestone(m);
  Future<bool> gameReward(int score) => _db.gameReward(score);
  Future<void> sendFeedback(String text) => _db.sendFeedback(text);

  Future<String?> fcmToken() => _noti.fcmToken();
}
