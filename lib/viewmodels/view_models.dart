import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../models/server_market.dart';
import '../repositories/farm_repository.dart';
import '../repositories/market_repository.dart';
import '../services/auction_api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_game_service.dart';
import '../services/notification_service.dart';
import '../services/sample_auction_source.dart';
import '../services/weather_service.dart';

// main()에서 override
final notificationProvider =
    Provider<NotificationService>((_) => throw UnimplementedError());
final prefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

// ───────────────────────── 로그인 ─────────────────────────

final authServiceProvider = Provider((_) => AuthService());
final authStateProvider =
    StreamProvider<User?>((_) => FirebaseAuth.instance.authStateChanges());

/// 튜토리얼을 막 끝냈으면 true. 이때는 예전에 쓰던 게스트(익명) 세션이 남아 있어도 로그인·회원가입 화면을 먼저 보여준다.
final loginAfterTutorialProvider = StateProvider<bool>((_) => false);

/// 튜토리얼을 다 봤는지 저장하는 키 (shared_preferences). 로그아웃하면 지워서 다음 실행 때 다시 보여준다.
const tutorialDoneKey = 'tutorialDone';

/// 앱을 켤 때마다(스플래시 다음) 튜토리얼을 보여줄지 저장하는 키. 기본값은 보여주기(true).
const tutorialOnStartKey = 'tutorialOnStart';

/// 앱 정보의 '앱을 켤 때 튜토리얼 보기' 스위치 상태
final tutorialOnStartProvider = StateProvider<bool>((ref) => ref.read(prefsProvider).getBool(tutorialOnStartKey) ?? true);

/// 회원가입 직후 닉네임을 Firestore 문서에 넣기 위해 잠깐 들고 있는 값
final pendingNicknameProvider = StateProvider<String?>((_) => null);

/// 로그인한 사용자의 uid로 Firestore 서비스를 만든다. 사용자가 바뀌면 이 서비스와 아래 스트림이 모두 새로 만들어진다.
final gameServiceProvider = Provider<FirestoreGameService>((ref) {
  final uid = ref.watch(authStateProvider.select((a) => a.valueOrNull?.uid)) ??
      FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('로그인이 필요해요');
  return FirestoreGameService(FirebaseFirestore.instance, uid);
});

// 키가 없으면 샘플 시세로 동작 (개발·테스트용): 배추는 실제 경매현황 JSON, 나머지 품목은 Fake
final auctionSourceProvider = Provider<AuctionSource>((_) =>
    auctionApiKey.isEmpty
        ? SampleAuctionSource(FakeAuctionSource())
        : AuctionApiService(http.Client()));
final marketRepoProvider = Provider((ref) => MarketRepository(
    ref.watch(auctionSourceProvider), ref.watch(prefsProvider)));
final farmRepoProvider = Provider((ref) => FarmRepository(
    ref.watch(gameServiceProvider), ref.watch(notificationProvider)));

final userProvider =
    StreamProvider((ref) => ref.watch(farmRepoProvider).user());
final plotsProvider =
    StreamProvider((ref) => ref.watch(farmRepoProvider).plots());
final lotsProvider =
    StreamProvider((ref) => ref.watch(farmRepoProvider).lots());
final tradesProvider =
    StreamProvider((ref) => ref.watch(farmRepoProvider).trades());
final fundProvider =
    StreamProvider((ref) => ref.watch(farmRepoProvider).fund());
final speedProvider = StateProvider<int>((_) => 1); // 데모 모드: 600배속
final tickProvider = StreamProvider(
    (_) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()));

/// 화면에서 쓰기 좋게 감싼 사용자 문서 (필드가 없는 이전 데이터도 기본값으로 읽는다)
final userDataProvider = Provider<UserData>((ref) =>
    UserData(ref.watch(userProvider).valueOrNull ?? const <String, dynamic>{}));

/// 하단 탭 번호 (0 시세판, 1 농장, 2 창고, 3 상점, 4 MY). 다른 화면에서 탭을 바꿀 때 쓴다.
final shellIndexProvider = StateProvider<int>((_) => 1);

final weatherProvider = FutureProvider<Weather?>((ref) {
  // 30분마다 다시 불러와서 날씨가 바뀌면 카드도 바뀐다
  final t = Timer(const Duration(minutes: 30), ref.invalidateSelf);
  ref.onDispose(t.cancel);
  return WeatherService(http.Client()).current();
});

/// 품목 상세 화면용: 최근 7일 시세와 거래량
/// 서버가 저장해 둔 값이 있으면 그것을, 없으면 앱이 API로 직접 받는다.
final priceHistoryProvider = FutureProvider.autoDispose
    .family<List<double?>, String>((ref, code) async {
  final server = ref.read(serverMarketProvider).valueOrNull;
  if (server != null && server.usable(appHasKey: auctionApiKey.isNotEmpty)) {
    final h = server.history(code);
    if (h.any((v) => v != null)) return h;
  }
  return ref.read(marketRepoProvider).history(code);
});
final priceVolumeProvider =
    FutureProvider.autoDispose.family<double?, String>((ref, code) async {
  final asOf = ref.read(marketViewModelProvider).valueOrNull?[code]?.asOf ??
      DateTime.now();
  final server = ref.read(serverMarketProvider).valueOrNull;
  if (server != null && server.usable(appHasKey: auctionApiKey.isNotEmpty)) {
    final v = server.volumeKg(code, asOf);
    if (v != null) return v;
  }
  return ref.read(marketRepoProvider).volumeKg(code, asOf);
});

/// 서버(GitHub Actions)가 Firestore `market/prices`에 저장한 시세를 실시간으로 듣는다.
/// 문서가 없거나 보안 규칙 때문에 읽을 수 없으면 null을 내보내고, 앱은 API로 직접 받는 방식을 쓴다.
final serverMarketProvider = StreamProvider<ServerMarket?>((ref) {
  return FirebaseFirestore.instance
      .doc(ServerMarket.path)
      .snapshots()
      .map((s) => ServerMarket.fromDoc(s.data()))
      .transform(StreamTransformer<ServerMarket?, ServerMarket?>.fromHandlers(
        handleError: (e, st, sink) => sink.add(null),
      ));
});

class MarketViewModel extends AsyncNotifier<Map<String, AuctionPrice>> {
  /// 앱이 켜져 있는 동안 시세를 저절로 다시 불러오는 간격 (공공데이터 API 하루 10,000건 한도 안에서 넉넉한 값)
  static const autoRefreshEvery = Duration(minutes: 5);

  bool _busy = false;

  /// 서버 시세가 최근 것이면 true. 이때는 앱이 API를 따로 부르지 않는다.
  bool get _serverFresh => ref.read(serverMarketProvider).valueOrNull?.usable(appHasKey: auctionApiKey.isNotEmpty) ?? false;

  @override
  Future<Map<String, AuctionPrice>> build() async {
    // 0) 서버가 Firestore에 새 시세를 저장하는 순간 화면을 바로 바꾼다
    ref.listen<AsyncValue<ServerMarket?>>(serverMarketProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null && s.usable(appHasKey: auctionApiKey.isNotEmpty)) state = AsyncData(s.prices);
    });
    // 1) 서버 시세가 끊겼을 때만: 5분마다 자동 새로고침  2) 앱을 다시 화면에 띄울 때(백그라운드 → 복귀) 새로고침
    final timer =
        Timer.periodic(autoRefreshEvery, (_) => _autoRefresh(force: true));
    final life =
        AppLifecycleListener(onResume: () => _autoRefresh(force: false));
    ref.onDispose(() {
      timer.cancel();
      life.dispose();
    });
    // 처음 열 때: 서버 시세가 최근 것이면 그걸로 시작, 아니면 앱이 API로 직접 받는다
    try {
      final s = await ref.read(serverMarketProvider.future).timeout(const Duration(seconds: 6));
      if (s != null && s.usable(appHasKey: auctionApiKey.isNotEmpty)) return s.prices;
    } catch (_) {
      // 서버 시세를 못 읽으면 아래 직접 조회로 넘어간다
    }
    return ref.read(marketRepoProvider).fetch();
  }

  /// 새로고침 버튼·당겨서 새로고침
  Future<void> refresh() async {
    if (_serverFresh) {
      // 서버 시세를 쓰는 중이면 Firestore에서 한 번 더 읽어 온다 (API 호출 없음)
      try {
        final snap = await FirebaseFirestore.instance.doc(ServerMarket.path).get(const GetOptions(source: Source.server));
        final s = ServerMarket.fromDoc(snap.data());
        if (s != null && s.usable(appHasKey: auctionApiKey.isNotEmpty)) {
          state = AsyncData(s.prices);
          return;
        }
      } catch (_) {
        // 실패하면 아래 직접 조회
      }
    }
    state = await AsyncValue.guard(() => ref.read(marketRepoProvider).fetch(force: true));
  }

  /// 화면을 로딩 상태로 바꾸지 않고 뒤에서 조용히 갱신한다. 실패하면 지금 보이는 시세를 그대로 둔다.
  /// force가 false면 마지막 조회 후 10분이 안 지났을 때 저장해 둔 값을 쓴다(API 호출 안 함).
  Future<void> _autoRefresh({required bool force}) async {
    if (_busy || state.isLoading) return;
    // 서버가 Firestore로 시세를 계속 보내주고 있으면 앱은 API를 부르지 않는다 (하루 호출 한도 절약)
    if (_serverFresh) return;
    _busy = true;
    try {
      final next = await AsyncValue.guard(
          () => ref.read(marketRepoProvider).fetch(force: force));
      if (next.hasValue && next.value!.isNotEmpty) state = next;
    } catch (_) {
      // 이미 dispose된 뒤라면 무시
    } finally {
      _busy = false;
    }
  }
}

final marketViewModelProvider =
    AsyncNotifierProvider<MarketViewModel, Map<String, AuctionPrice>>(
        MarketViewModel.new);

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
    final used = (_ref.read(lotsProvider).valueOrNull ?? const <Lot>[])
        .fold<double>(0, (a, l) => a + l.kg);
    if (used + c.yieldKg * (1 + p.bonus) > cap + 1e-9) {
      throw StateError('창고가 가득 찼어요. 먼저 판매하거나 창고를 넓혀주세요');
    }
    return _repo.harvest(p.index, c);
  }

  /// 잘못 심은 작물 뽑기 (다시 심기)
  Future<String> uproot(Plot p) => _repo.uproot(p.index);

  Future<void> useItem(Plot p, String key) =>
      _repo.useItem(p.index, cropOf(p.cropCode!), key);

  /// 시세가 없으면 출하하지 않는다.
  Future<void> sell(Lot lot) async {
    final price = _ref.read(marketViewModelProvider).valueOrNull?[lot.cropCode];
    if (price == null) throw StateError('시세를 불러온 뒤 출하할 수 있어요');
    await _repo.sell(lot, price, DateTime.now());
  }

  // 상점
  Future<void> buySeed(CropSpec c) =>
      _repo.buyItem(seedKey(c.code), seedPrice(c));
  Future<void> buyConsumable(ShopItem i) => _repo.buyItem(i.key, i.price);
  Future<void> expandPlots() => _repo.expandPlots(
      (_ref.read(plotsProvider).valueOrNull ?? const <Plot>[]).length);
  Future<void> expandWarehouse() => _repo.expandWarehouse();
  Future<void> buyGreenhouse() => _repo.buyGreenhouse();
  Future<void> buyPointItem(PointItem i, {String? cropCode}) =>
      _repo.buyPointItem(i.key, cropCode: cropCode);

  // 미션·업적·기금·기타
  Future<void> claimMission(MissionDef d) => _repo.claimMission(d);
  Future<void> claimAchievement(AchievementDef d) => _repo.claimAchievement(
      d, (_ref.read(plotsProvider).valueOrNull ?? const <Plot>[]).length);
  Future<void> donate(int amount) => _repo.donateToFund(amount);
  Future<void> claimFund(FundMilestone m) => _repo.claimFundMilestone(m);
  Future<bool> gameReward(int score) => _repo.gameReward(score);
  Future<void> sendFeedback(String text) => _repo.sendFeedback(text);
}

final farmViewModelProvider = Provider((ref) => FarmViewModel(ref));
