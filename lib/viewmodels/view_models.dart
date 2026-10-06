import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_rules.dart';
import '../models/models.dart';
import '../repositories/farm_repository.dart';
import '../repositories/market_repository.dart';
import '../services/auction_api_service.dart';
import '../services/sample_auction_source.dart';
import '../services/firestore_game_service.dart';
import '../services/notification_service.dart';

// main()에서 override
final gameServiceProvider = Provider<FirestoreGameService>((_) => throw UnimplementedError());
final notificationProvider = Provider<NotificationService>((_) => throw UnimplementedError());
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

// 키가 없으면 샘플 시세로 동작 (개발·테스트용): 배추는 실제 경매현황 JSON, 나머지 품목은 Fake
final auctionSourceProvider = Provider<AuctionSource>(
    (_) => auctionApiKey.isEmpty ? SampleAuctionSource(FakeAuctionSource()) : AuctionApiService(http.Client()));
final marketRepoProvider = Provider((ref) => MarketRepository(ref.watch(auctionSourceProvider), ref.watch(prefsProvider)));
final farmRepoProvider = Provider((ref) => FarmRepository(ref.watch(gameServiceProvider), ref.watch(notificationProvider)));

final userProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).user());
final plotsProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).plots());
final lotsProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).lots());
final tradesProvider = StreamProvider((ref) => ref.watch(farmRepoProvider).trades());
final speedProvider = StateProvider<int>((_) => 1); // 데모 모드: 600배속
final tickProvider = StreamProvider((_) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()));

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

  Future<void> plant(int idx, CropSpec c) =>
      _repo.plant(idx, c, DateTime.now().add(growDuration(c, _ref.read(speedProvider))));
  Future<void> harvest(Plot p) => _repo.harvest(p.index, cropOf(p.cropCode!));

  /// 시세가 없으면 출하하지 않는다.
  Future<void> sell(Lot lot) async {
    final price = _ref.read(marketViewModelProvider).valueOrNull?[lot.cropCode];
    if (price == null) throw StateError('시세를 불러온 뒤 출하할 수 있어요');
    await _repo.sell(lot, price, DateTime.now());
  }
}

final farmViewModelProvider = Provider((ref) => FarmViewModel(ref));
