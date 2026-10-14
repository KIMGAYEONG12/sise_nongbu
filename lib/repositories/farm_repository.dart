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
  Future<void> setTitle(int? index) => _db.setTitle(index);
  Future<void> setAvatar(bool boy) => _db.setAvatar(boy);
  Future<int> sellItem(String key, int qty) => _db.sellItem(key, qty);
  Future<void> resetMoney() => _db.resetMoney();

  /// 예전 성장 시간으로 심겨 있는 작물을 새 시간에 맞추고, 수확 알림도 다시 예약한다. 바뀐 밭 수를 돌려준다.
  Future<int> fitGrowTimes() async {
    final changed = await _db.fitGrowTimes();
    for (final (idx, c, at) in changed) {
      try {
        await _noti.cancel(idx);
        await _noti.scheduleHarvest(idx, c.name, at);
      } catch (_) {
        // 알림 예약 실패는 게임 진행과 무관하므로 무시한다.
      }
    }
    return changed.length;
  }

  Future<void> plant(int idx, CropSpec c, DateTime readyAt) async {
    await _db.plant(idx, c, readyAt);
    await _noti.scheduleHarvest(idx, c.name, readyAt);
  }

  /// 잘못 심은 작물을 뽑는다. 수확 알림도 지운다. 사용자에게 보여줄 문구를 돌려준다.
  Future<String> uproot(int idx) async {
    final msg = await _db.uproot(idx);
    try {
      await _noti.cancel(idx);
    } catch (_) {}
    return msg;
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
  /// 하우스를 짓고, 빨라진 밭의 수확 알림을 새 시각으로 다시 예약한다.
  Future<void> buyGreenhouse() async {
    final changed = await _db.buyGreenhouse();
    for (final (idx, c, at) in changed) {
      await _noti.scheduleHarvest(idx, c.name, at);
    }
  }
  Future<void> buySeedPack(int price) => _db.buySeedPack(price);
  Future<void> buyPointItem(String key, {String? cropCode}) => _db.buyPointItem(key, cropCode: cropCode);
  Future<LevelUpReward?> claimLevelUpReward(int from, int to) => _db.claimLevelUpReward(from, to);
  Future<void> claimMission(MissionDef def) => _db.claimMission(def);
  Future<void> claimAchievement(AchievementDef def, int plots) => _db.claimAchievement(def, plots);
  Future<void> donateToFund(int amount) => _db.donateToFund(amount);
  Future<void> claimFundMilestone(FundMilestone m) => _db.claimFundMilestone(m);
  Future<bool> gameReward(int score) => _db.gameReward(score);

  Future<String?> fcmToken() => _noti.fcmToken();
}
