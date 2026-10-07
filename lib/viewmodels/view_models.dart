import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../repositories/farm_repository.dart';
import '../repositories/market_repository.dart';
import '../services/auction_api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_game_service.dart';
import '../services/notification_service.dart';
import '../services/sample_auction_source.dart';
import '../services/weather_service.dart';

// main()에서 override
final notificationProvider = Provider<NotificationService>((_) => throw UnimplementedError());
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

// ───────────────────────── 로그인 ─────────────────────────

final authServiceProvider = Provider((_) => AuthService());
final authStateProvider = StreamProvider<User?>((_) => FirebaseAuth.instance.authStateChanges());

/// 튜토리얼을 막 끝냈으면 true. 이때는 예전에 쓰던 게스트(익명) 세션이 남아 있어도 로그인·회원가입 화면을 먼저 보여준다.
final loginAfterTutorialProvider = StateProvider<bool>((_) => false);

/// 회원가입 직후 닉네임을 Firestore 문서에 넣기 위해 잠깐 들고 있는 값
final pendingNicknameProvider = StateProvider<String?>((_) => null);

/// 로그인한 사용자의 uid로 Firestore 서비스를 만든다. 사용자가 바뀌면 이 서비스와 아래 스트림이 모두 새로 만들어진다.
final gameServiceProvider = Provider<FirestoreGameService>((ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.valueOrNull?.uid)) ?? FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('로그인이 필요해요');
  return FirestoreGameService(FirebaseFirestore.instance, uid);
});

// 키가 없으면 샘플 시세로 동작 (개발·테스트용): 배추는 실제 경매현황 JSON, 나머지 품목은 Fake
final auctionSourceProvider = Provider<AuctionSource>(
    (_) => auctionApiKey.isEmpty ? SampleAuctionSource(FakeAuctionSource()) : AuctionApiService(http.Client()));
final marketRepoProvider = Provider((ref) => MarketRepository(ref.watch(auctionSourceProvider), ref.watch(prefsProvider)));
final farmRepoProvider = Provider((ref) => FarmRepository(ref.watch(gameServiceProvider), ref.watch(notificationProvider)));

final userProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).user());
final plotsProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).plots());
final lotsProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).lots());
final tradesProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).trades());
final fundProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).fund());
final speedProvider = StateProvider<int>((_) => 1); // 데모 모드: 600배속
final tickProvider = StreamProvider((_) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()));

/// 화면에서 쓰기 좋게 감싼 사용자 문서 (필드가 없는 이전 데이터도 기본값으로 읽는다)
final userDataProvider = Provider<UserData>((ref) => UserData(ref.watch(userProvider).valueOrNull ?? const <String, dynamic>{}));

/// 하단 탭 번호 (0 시세판, 1 농장, 2 창고, 3 상점, 4 MY). 다른 화면에서 탭을 바꿀 때 쓴다.
final shellIndexProvider = StateProvider<int>((_) => 1);

final weatherProvider = FutureProvider<Weather?>((_) => WeatherService(http.Client()).current());

/// 품목 상세 화면용: 최근 7일 시세와 거래량
final priceHistoryProvider =
    FutureProvider.autoDispose.family<List<double?>, String>((ref, code) => ref.read(marketRepoProvider).history(code));
final priceVolumeProvider = FutureProvider.autoDispose.family<double?, String>((ref, code) {
  final asOf = ref.read(marketViewModelProvider).valueOrNull?[code]?.asOf ?? DateTime.now();
  return ref.read(marketRepoProvider).volumeKg(code, asOf);
});

class MarketViewModel extends AsyncNotifier<Map<String, AuctionPrice>> {
  @override
  Future<Map<String, AuctionPrice>> build() => ref.read(marketRepoProvider).fetch();
  Future<void> refresh() async => state = await AsyncValue.guard(() => ref.read(marketRepoProvider).fetch(force: true));
}

final marketViewModelProvider = AsyncNotifierProvider<MarketViewModel, Map<String, AuctionPrice>>(MarketViewModel.new);

class FarmViewModel {
  FarmViewModel(this._ref);
  final Ref _ref;
  FarmRepository get _repo => _ref.read(farmRepoProvider);

  /// 하우스가 있으면 성장 시간이 20% 줄어든다.
  Future<void> plant(int idx, CropSpec c) {
    final gh = _ref.read(userDataProvider).greenhouse;
    final d = applyGreenhouse(growDuration(c, _ref.read(speedProvider)), gh);
    return _repo.plant(idx, c, DateTime.now().add(d));
  }

  /// 수확해서 창고에 넣고 수확량(kg)을 돌려준다. 창고가 가득 차면 수확하지 못한다.
  Future<double> harvest(Plot p) {
    final c = cropOf(p.cropCode!);
    final cap = _ref.read(userDataProvider).warehouseCapKg;
    final used = (_ref.read(lotsProvider).valueOrNull ?? const <Lot>[]).fold<double>(0, (a, l) => a + l.kg);
    if (used + c.yieldKg * (1 + p.bonus) > cap + 1e-9) {
      throw StateError('창고가 가득 찼어요. 먼저 판매하거나 창고를 넓혀주세요');
    }
    return _repo.harvest(p.index, c);
  }

  Future<void> useItem(Plot p, String key) => _repo.useItem(p.index, cropOf(p.cropCode!), key);

  /// 시세가 없으면 출하하지 않는다.
  Future<void> sell(Lot lot) async {
    final price = _ref.read(marketViewModelProvider).valueOrNull?[lot.cropCode];
    if (price == null) throw StateError('시세를 불러온 뒤 출하할 수 있어요');
    await _repo.sell(lot, price, DateTime.now());
  }

  // 상점
  Future<void> buySeed(CropSpec c) => _repo.buyItem(seedKey(c.code), seedPrice(c));
  Future<void> buyConsumable(ShopItem i) => _repo.buyItem(i.key, i.price);
  Future<void> expandPlots() => _repo.expandPlots((_ref.read(plotsProvider).valueOrNull ?? const <Plot>[]).length);
  Future<void> expandWarehouse() => _repo.expandWarehouse();
  Future<void> buyGreenhouse() => _repo.buyGreenhouse();
  Future<void> buyPointItem(PointItem i, {String? cropCode}) => _repo.buyPointItem(i.key, cropCode: cropCode);

  // 미션·업적·기금·기타
  Future<void> claimMission(MissionDef d) => _repo.claimMission(d);
  Future<void> claimAchievement(AchievementDef d) =>
      _repo.claimAchievement(d, (_ref.read(plotsProvider).valueOrNull ?? const <Plot>[]).length);
  Future<void> donate(int amount) => _repo.donateToFund(amount);
  Future<void> claimFund(FundMilestone m) => _repo.claimFundMilestone(m);
  Future<bool> gameReward(int score) => _repo.gameReward(score);
  Future<void> sendFeedback(String text) => _repo.sendFeedback(text);
}

final farmViewModelProvider = Provider((ref) => FarmViewModel(ref));
