// 순수 Dart 진행 규칙 (레벨·경험치, 미션, 업적, 상점, 창고·밭 확장). Flutter/Firebase에 의존하지 않는다.
import 'game_rules.dart';

// ───────────────────────── 레벨 ─────────────────────────

/// 다음 레벨까지 필요한 경험치: 모든 레벨에서 500으로 똑같다 (예전에는 300이었다).
const expPerLevel = 500;
int expToNext(int level) => expPerLevel;

/// 경험치를 얻는 모든 행동(파종·수확·판매·구매·미션·기부·게임)에 곱하는 배율. 레벨이 빨리 오른다.
const expBoost = 3;

/// 수확 한 번에 얻는 경험치 (한 번 수확하면 레벨 경험치의 60%가 찬다)
const harvestExp = 300;

/// 판매 금액에 따라 얻는 경험치 (금액 700원당 1, 최소 3)
int sellExp(int amount) => amount ~/ 700 < 3 ? 3 : amount ~/ 700;

/// 마을 기금 기부 금액에 따라 얻는 경험치 (400원당 1, 최소 3)
int donateExp(int amount) => amount ~/ 400 < 3 ? 3 : amount ~/ 400;

/// 마을 기금에 기부할 때마다 바로 받는 포인트(특별 상점용). 많이 기부할수록 비율이 좋아진다.
/// 1,000P → 10 · 5,000P → 60 · 10,000P → 150 · 50,000P → 900
int donateRewardPoints(int amount) {
  if (amount <= 0) return 0;
  final rate = amount >= 50000
      ? 1.8
      : amount >= 10000
          ? 1.5
          : amount >= 5000
              ? 1.2
              : 1.0;
  final p = (amount * rate / 100).round();
  return p < 1 ? 1 : p;
}

/// 농장 큰 집의 이름표: 레벨이 오르면 집 이름도 바뀐다 (최소 레벨, 이름)
const farmHouseNames = <(int, String)>[
  (1, '작은 오두막'),
  (5, '아늑한 농가'),
  (10, '따뜻한 시골집'),
  (20, '멋진 농장 주택'),
  (35, '근사한 농장 저택'),
  (50, '별빛 농장 대저택'),
  (70, '황금 농장 저택'),
  (90, '전설의 농장 성'),
];

/// 마지막 단계(전설의 농장 성)가 되는 레벨: 이때부터 농장 그림의 오두막 자리에 성을 그린다
bool isCastleLevel(int level) => level >= farmHouseNames.last.$1;

/// [level]에 맞는 농장 큰 집 이름
String farmHouseName(int level) {
  var name = farmHouseNames.first.$2;
  for (final h in farmHouseNames) {
    if (level >= h.$1) name = h.$2;
  }
  return name;
}

class LevelInfo {
  const LevelInfo(this.level, this.exp, this.need);
  final int level; // 현재 레벨
  final int exp; // 현재 레벨에서 쌓은 경험치
  final int need; // 다음 레벨까지 필요한 경험치
  double get ratio => need <= 0 ? 0 : (exp / need).clamp(0.0, 1.0).toDouble();
}

/// 누적 경험치로 레벨 계산
LevelInfo levelInfo(int totalExp) {
  var level = 1;
  var left = totalExp < 0 ? 0 : totalExp;
  while (left >= expToNext(level)) {
    left -= expToNext(level);
    level++;
  }
  return LevelInfo(level, left, expToNext(level));
}

// ───────────────────────── 창고·밭·하우스 ─────────────────────────

const baseWarehouseKg = 200;
const warehouseStepKg = 100;
const maxWarehouseLevel = 5;
const maxVaultBonusKg = 150; // 포인트 상점 "특별 보관함" 최대치(50kg × 3)
const vaultStepKg = 50;

int warehouseCapKg(int level, int bonusKg) => baseWarehouseKg + warehouseStepKg * level + bonusKg;

/// 창고 확장 비용. 레벨 0 → 20,000원, 1 → 40,000원 …
int warehouseCost(int level) => 2000 * (level + 1); // 농장 시설은 싸게

const maxPlots = 24; // 6칸에서 시작해 3칸씩 6번 넓힐 수 있다
const plotExpandStep = 3;

/// 밭 확장 비용. 6칸 → 50,000원, 9칸 → 100,000원. 최대치면 null.
int? plotExpandCost(int currentPlots) {
  if (currentPlots >= maxPlots) return null;
  final steps = (currentPlots - plotCount) ~/ plotExpandStep;
  return 5000 * (steps < 0 ? 1 : steps + 1); // 농장 시설은 싸게
}

/// 잘못 심은 작물을 뽑을 때, 심은 지 이 시간 안이면 파종비(또는 씨앗)를 돌려준다.
const uprootRefundWindow = Duration(minutes: 10);

/// 하우스는 몇 채든 계속 지을 수 있다.
/// 처음 [greenhouseFullEffect]채까지는 한 채마다 성장 시간이 10%씩 줄고(5채 = 50% 단축),
/// 그 뒤로는 한 채마다 4%씩 더 줄어서 10채에서 최대 70% 단축이 된다.
const greenhouseFullEffect = 5;
const greenhouseStep = 0.1;
const greenhouseLateStep = 0.04;
const greenhouseMaxCut = 0.7;

/// 하우스 한 채 값. 몇 채를 지어도(레벨이 올라도) 늘 10,000으로 같다.
int greenhouseCostFor(int owned) => 10000;

/// 하우스 [count]채가 있을 때 성장 시간 배율 (1.0 → 0.9 → … 5채 0.5 → 6채 0.46 … 10채 0.3, 그 뒤로는 0.3 그대로)
double greenhouseFactor(int count) {
  final n = count < 0 ? 0 : count;
  if (n <= greenhouseFullEffect) return 1 - greenhouseStep * n;
  final f = (1 - greenhouseStep * greenhouseFullEffect) - greenhouseLateStep * (n - greenhouseFullEffect);
  return f < 1 - greenhouseMaxCut ? 1 - greenhouseMaxCut : f;
}

Duration applyGreenhouses(Duration d, int count) => count <= 0 ? d : Duration(milliseconds: (d.inMilliseconds * greenhouseFactor(count)).round());

// ───────────────────────── 아이템 ─────────────────────────

const itemWater = 'water';
const itemFertilizer = 'fertilizer';
const itemBooster = 'booster';

/// 처음 시작할 때 주는 물통·영양제·성장촉진제 개수
const starterItemCount = 10;
const starterItemKeys = [itemWater, itemFertilizer, itemBooster];

/// 물주기: 한 번에 전체 성장 시간의 3% 단축. 한 밭에 주는 횟수 제한은 없다.
const waterCut = 0.03;
/// 튜토리얼 연습에서 물을 주는 횟수 (실제 게임에는 횟수 제한이 없다)
const tutorialWaterCount = 10;
const boosterCut = 0.30; // 성장촉진제: 전체 성장 시간의 30% 단축
const fertilizerBonus = 0.20; // 영양제: 수확량 +20% (횟수 제한 없음)

String seedKey(String cropCode) => 'seed_$cropCode';

class ShopItem {
  const ShopItem(this.key, this.name, this.emoji, this.price, this.desc);
  final String key, name, emoji, desc;
  final int price;
}

const consumables = [
  ShopItem(itemWater, '물통', '💧', 500, '물주기 1회 · 성장 시간 3% 단축 (횟수 제한 없음)'),
  ShopItem(itemFertilizer, '영양제', '🧪', 1500, '수확량 +20% (횟수 제한 없음)'),
  ShopItem(itemBooster, '성장촉진제', '⚡', 3000, '성장 시간 30% 단축 (횟수 제한 없음)'),
];

/// 묶음 상품: 같은 아이템을 여러 개 한꺼번에 사면 10% 싸다.
class BundleItem {
  const BundleItem(this.itemKey, this.name, this.emoji, this.qty, this.price);
  final String itemKey, name, emoji;
  final int qty, price;
}

const bundles = [
  BundleItem(itemWater, '물통 10개 묶음', '💧', 10, 4500),
  BundleItem(itemFertilizer, '영양제 5개 묶음', '🧪', 5, 6750),
  BundleItem(itemBooster, '성장촉진제 3개 묶음', '⚡', 3, 8100),
];

/// 씨앗 꾸러미에 들어 있는 기본 작물 수 (처음 6종). 작물이 21종으로 늘어도 꾸러미는 이 6종만 담아서 값이 터무니없이 커지지 않는다.
const seedPackCropCount = 6;

/// 씨앗 꾸러미에 담기는 작물 (기본 6종)
List<CropSpec> get seedPackCrops => crops.take(seedPackCropCount).toList();

/// 씨앗 꾸러미: 기본 여섯 작물의 씨앗을 1개씩. 따로 사는 값의 90%.
int seedPackPrice() => (seedPackCrops.fold<int>(0, (a, c) => a + seedPrice(c)) * 0.9).round();

/// 씨앗은 파종비의 85% 가격. 가지고 있으면 파종할 때 파종비 대신 씨앗을 쓴다.
int seedPrice(CropSpec c) => (c.seedCost * 0.85).round();

/// 창고에서 아이템을 되팔 때 1개 값: 상점 가격의 절반 (팔 수 없는 아이템은 0)
int itemSellPrice(String key) {
  for (final i in consumables) {
    if (i.key == key) return i.price ~/ 2;
  }
  if (key.startsWith('seed_')) {
    final code = key.substring(5);
    for (final c in crops) {
      if (c.code == code) return seedPrice(c) ~/ 2;
    }
  }
  return 0;
}

String itemName(String key) {
  for (final i in consumables) {
    if (i.key == key) return i.name;
  }
  if (key.startsWith('seed_')) {
    final code = key.substring(5);
    for (final c in crops) {
      if (c.code == code) return '${c.name} 씨앗';
    }
  }
  return key;
}

String itemEmoji(String key) {
  for (final i in consumables) {
    if (i.key == key) return i.emoji;
  }
  return '🌱';
}

// ───────────────────────── 포인트 상점 ─────────────────────────

const pointRareSeed = 'rare_seed';
const pointDecor = 'decor';
const pointVault = 'vault';
const pointLucky = 'lucky';
const pointWaterPack = 'water_pack';
const pointBoosterPack = 'booster_pack';
const pointSeedBox = 'seed_box';
const pointCoinBag = 'coin_bag';
const pointFarmBook = 'farm_book';
const maxDecor = 5;

/// 금화 주머니로 바꿔 받는 게임 돈(P)
const coinBagMoney = 10000;

/// 농부 교본으로 얻는 경험치
const farmBookExp = 500;

class PointItem {
  const PointItem(this.key, this.name, this.emoji, this.cost, this.desc);
  final String key, name, emoji, desc;
  final int cost;
}

/// 특별 상점 상품. 포인트(Point)로만 살 수 있다.
const pointItems = [
  PointItem(pointRareSeed, '희귀 씨앗', '🌰', 40, '무작위 작물의 씨앗 3개를 받아요'),
  PointItem(pointDecor, '농장 장식', '🌻', 30, '농장 화면에 꽃 장식이 늘어나요 (최대 5개)'),
  PointItem(pointVault, '특별 보관함', '🧰', 80, '창고 용량 +50kg (최대 3회)'),
  PointItem(pointLucky, '행운의 비료', '🍀', 60, '영양제 3개를 받아요'),
  PointItem(pointWaterPack, '물방울 꾸러미', '💦', 25, '물통 10개를 한 번에 받아요'),
  PointItem(pointBoosterPack, '번개 촉진제', '⚡', 45, '성장촉진제 2개를 받아요'),
  PointItem(pointSeedBox, '씨앗 선물 상자', '🎁', 40, '기본 작물 여섯 가지의 씨앗을 1개씩 받아요'),
  PointItem(pointCoinBag, '금화 주머니', '💰', 55, '게임 돈 10,000P를 받아요'),
  PointItem(pointFarmBook, '농부 교본', '📘', 70, '경험치 500을 받아 레벨을 올려요'),
];

// ───────────────────────── 기간별 카운터 (일일/주간) ─────────────────────────

/// 한국 시간(KST, UTC+9)으로 바꾼 시각. 에뮬레이터·기기의 시간대가 달라도 하루가 바뀌는 때는 한국 자정이다.
/// (돌려주는 값의 연·월·일·시 필드가 곧 한국 시각이다)
DateTime toKst(DateTime d) => d.toUtc().add(const Duration(hours: 9));

/// 지금 한국 시각
DateTime kstNow() => toKst(DateTime.now());

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 한국 날짜 기준 하루 태그 (일일 미션이 초기화되는 기준). 예) 2026-10-12
String dayTag(DateTime d) => _ymd(toKst(d));

/// 그 주 월요일(한국 날짜)을 주간 태그로 쓴다.
String weekTag(DateTime d) {
  final k = toKst(d);
  return _ymd(DateTime(k.year, k.month, k.day).subtract(Duration(days: k.weekday - 1)));
}

/// 태그가 같으면 이어서, 다르면 새로 시작한 카운터 맵을 돌려준다.
Map<String, dynamic> bumpPeriod(Map<String, dynamic>? old, String tag, String key, [int n = 1]) {
  final m = (old != null && old['tag'] == tag) ? Map<String, dynamic>.from(old) : <String, dynamic>{'tag': tag};
  m[key] = ((m[key] as num?)?.toInt() ?? 0) + n;
  return m;
}

/// 이번 기간에 처음 심는 작물이면 종류 수('variety')를 1 올린다. 같은 작물을 또 심어도 늘지 않는다.
Map<String, dynamic> bumpVariety(Map<String, dynamic>? old, String tag, String cropCode) {
  final m = (old != null && old['tag'] == tag) ? Map<String, dynamic>.from(old) : <String, dynamic>{'tag': tag};
  final seen = (m['crops'] is List) ? (m['crops'] as List).map((e) => '$e').toList() : <String>[];
  if (!seen.contains(cropCode)) {
    seen.add(cropCode);
    m['crops'] = seen;
    m['variety'] = ((m['variety'] as num?)?.toInt() ?? 0) + 1;
  }
  return m;
}

int periodCount(Map<String, dynamic>? m, String tag, String key) =>
    (m != null && m['tag'] == tag) ? ((m[key] as num?)?.toInt() ?? 0) : 0;

List<String> periodClaimed(Map<String, dynamic>? m, String tag) {
  if (m == null || m['tag'] != tag) return const [];
  final c = m['claimed'];
  return c is List ? c.map((e) => '$e').toList() : const [];
}

/// 수령한 보상 id를 기록한 맵
Map<String, dynamic> markClaimed(Map<String, dynamic>? old, String tag, String id) {
  final m = (old != null && old['tag'] == tag) ? Map<String, dynamic>.from(old) : <String, dynamic>{'tag': tag};
  final list = periodClaimed(m, tag).toList();
  if (!list.contains(id)) list.add(id);
  m['claimed'] = list;
  return m;
}

// ───────────────────────── 미션 ─────────────────────────

class MissionDef {
  const MissionDef(this.id, this.title, this.emoji, this.key, this.target, this.points, this.weekly);
  final String id, title, emoji, key;
  final int target, points;
  final bool weekly;
}

const dailyMissions = [
  MissionDef('d_water', '작물에 물 3회 주기', '💧', 'water', 3, 20, false),
  MissionDef('d_plant', '작물 2번 파종하기', '🌱', 'plant', 2, 20, false),
  MissionDef('d_harvest', '작물 1개 수확하기', '🧺', 'harvest', 1, 20, false),
  MissionDef('d_shop', '농장 상점 이용하기', '🛒', 'shop', 1, 30, false),
  MissionDef('d_sell', '작물 1번 판매하기', '💰', 'sell', 1, 25, false),
  MissionDef('d_variety', '다양한 작물 2종 심기', '🥕', 'variety', 2, 20, false),
];

const weeklyMissions = [
  MissionDef('w_harvest', '작물 10번 수확하기', '🧺', 'harvest', 10, 100, true),
  MissionDef('w_sell', '작물 5번 판매하기', '💰', 'sell', 5, 100, true),
  MissionDef('w_plant', '작물 15번 파종하기', '🌱', 'plant', 15, 80, true),
  MissionDef('w_game', '작물 매칭 1번 하기', '🥬', 'game', 1, 30, true),
  MissionDef('w_water', '작물에 물 1회 주기', '💧', 'water', 1, 20, true),
  MissionDef('w_shop', '농장 상점 5번 이용하기', '🛒', 'shop', 5, 70, true),
];

MissionDef? missionById(String id) {
  for (final m in [...dailyMissions, ...weeklyMissions]) {
    if (m.id == id) return m;
  }
  return null;
}

// ───────────────────────── 업적 ─────────────────────────

class AchievementDef {
  const AchievementDef(this.id, this.title, this.desc, this.emoji, this.category, this.points, this.statKey, this.target);
  final String id, title, desc, emoji, category, statKey;
  final int points, target;
}

/// statKey: 'stats.xxx'는 누적 카운터, 'money'는 보유 자금, 'plots'는 밭 칸 수
const achievements = [
  AchievementDef('first_plant', '첫 삽을 뜨다', '처음으로 작물을 파종해요', '🌱', '일반', 20, 'stats.plant', 1),
  AchievementDef('first_harvest', '수확의 기쁨', '처음으로 작물을 수확해요', '🧺', '일반', 20, 'stats.harvest', 1),
  AchievementDef('water10', '물 한 모금', '물주기를 10번 해요', '💧', '일반', 30, 'stats.water', 10),
  AchievementDef('harvest10', '행복한 농부', '작물을 10번 수확해요', '😊', '일반', 50, 'stats.harvest', 10),
  AchievementDef('good_sell', '좋은 가격에 팔았다', '시세가 오른 날 작물을 판매해요', '📈', '도전', 50, 'stats.goodSell', 1),
  AchievementDef('sell10', '단골 출하', '작물을 10번 판매해요', '🚚', '도전', 60, 'stats.sell', 10),
  AchievementDef('rich', '부자 농부', '보유 자금 200,000P를 달성해요', '💰', '도전', 50, 'money', 200000),
  AchievementDef('big_farm', '대규모 농장', '밭을 9칸 이상으로 넓혀요', '🌾', '도전', 50, 'plots', 9),
  AchievementDef('puzzle', '퍼즐 마스터', '작물 매칭을 1번 완료해요', '🥬', '특별', 20, 'stats.game', 1),
  AchievementDef('helper', '마을의 은인', '마을 공동기금에 합계 10,000P를 기부해요', '🏡', '특별', 40, 'stats.donate', 10000),
  AchievementDef('plant50', '씨앗 부자', '작물을 50번 파종해요', '🌰', '일반', 40, 'stats.plant', 50),
  AchievementDef('harvest50', '풍년이로세', '작물을 50번 수확해요', '🌽', '일반', 80, 'stats.harvest', 50),
  AchievementDef('harvest100', '수확왕', '작물을 100번 수확해요', '👑', '일반', 150, 'stats.harvest', 100),
  AchievementDef('water50', '물의 요정', '물주기를 50번 해요', '🧚', '일반', 60, 'stats.water', 50),
  AchievementDef('fertilizer10', '영양 만점', '영양제를 10번 써요', '🌿', '일반', 40, 'stats.fertilizer', 10),
  AchievementDef('booster10', '번개 농부', '성장촉진제를 10번 써요', '⚡', '일반', 50, 'stats.booster', 10),
  AchievementDef('harvest_kg500', '500kg 수확', '수확량을 합쳐서 500kg을 모아요', '⚖️', '일반', 70, 'stats.harvestKg', 500),
  AchievementDef('sell50', '출하 달인', '작물을 50번 판매해요', '📦', '도전', 100, 'stats.sell', 50),
  AchievementDef('good_sell10', '시세 도사', '시세가 오른 날 작물을 10번 판매해요', '🔮', '도전', 100, 'stats.goodSell', 10),
  AchievementDef('rich1m', '백만장자 농부', '보유 자금 1,000,000P를 달성해요', '💎', '도전', 150, 'money', 1000000),
  AchievementDef('plots15', '농장 확장 중', '밭을 15칸 이상으로 넓혀요', '🟫', '도전', 80, 'plots', 15),
  AchievementDef('plots24', '끝없는 밭', '밭을 최대 24칸까지 넓혀요', '🏞️', '도전', 150, 'plots', 24),
  AchievementDef('shop10', '단골 손님', '상점에서 10번 구매해요', '🛒', '특별', 40, 'stats.shop', 10),
  AchievementDef('puzzle5', '퍼즐 중독', '작물 매칭을 5번 완료해요', '🧠', '특별', 50, 'stats.game', 5),
  AchievementDef('puzzle20', '매칭의 신', '작물 매칭을 20번 완료해요', '🏅', '특별', 120, 'stats.game', 20),
  AchievementDef('helper100k', '마을의 영웅', '마을 공동기금에 합계 100,000P를 기부해요', '🦸', '특별', 120, 'stats.donate', 100000),
  AchievementDef('plant100', '씨앗의 달인', '작물을 100번 파종해요', '🌾', '일반', 100, 'stats.plant', 100),
  AchievementDef('water100', '물뿌리개 장인', '물주기를 100번 해요', '🚿', '일반', 100, 'stats.water', 100),
  AchievementDef('fertilizer50', '비료 박사', '영양제를 50번 써요', '🧪', '일반', 90, 'stats.fertilizer', 50),
  AchievementDef('booster50', '초고속 농부', '성장촉진제를 50번 써요', '🚀', '일반', 100, 'stats.booster', 50),
  AchievementDef('harvest_kg2000', '2톤 트럭', '수확량을 합쳐서 2,000kg을 모아요', '🚛', '일반', 150, 'stats.harvestKg', 2000),
  AchievementDef('sell100', '시장의 큰손', '작물을 100번 판매해요', '🏪', '도전', 150, 'stats.sell', 100),
  AchievementDef('good_sell50', '시세의 신', '시세가 오른 날 작물을 50번 판매해요', '📊', '도전', 200, 'stats.goodSell', 50),
  AchievementDef('rich5m', '농업 재벌', '보유 자금 5,000,000P를 달성해요', '🏦', '도전', 250, 'money', 5000000),
  AchievementDef('shop50', 'VIP 손님', '상점에서 50번 구매해요', '🎫', '특별', 100, 'stats.shop', 50),
  AchievementDef('puzzle50', '매칭 전설', '작물 매칭을 50번 완료해요', '🌟', '특별', 200, 'stats.game', 50),
];

AchievementDef? achievementById(String id) {
  for (final a in achievements) {
    if (a.id == id) return a;
  }
  return null;
}

int achievementProgress(AchievementDef a, Map<String, dynamic> user, int plots) {
  switch (a.statKey) {
    case 'money':
      return (user['money'] as num?)?.toInt() ?? 0;
    case 'plots':
      return plots;
    default:
      final stats = user['stats'];
      final key = a.statKey.startsWith('stats.') ? a.statKey.substring(6) : a.statKey;
      return stats is Map ? ((stats[key] as num?)?.toInt() ?? 0) : 0;
  }
}

// ───────────────────────── 마을 공동기금 ─────────────────────────

const fundDefaultGoal = 500000;

class FundMilestone {
  const FundMilestone(this.percent, this.points);
  final int percent, points;
}

const fundMilestones = [
  FundMilestone(25, 50),
  FundMilestone(50, 100),
  FundMilestone(75, 150),
  FundMilestone(100, 300),
];

// ───────────────────────── 작물 매칭 게임 보상 ─────────────────────────

const gameDailyRewardLimit = 10; // 하루 보상 횟수 (테스트하기 쉽게 넉넉히)
int gameRewardMoney(int score) => (score * 20).clamp(0, 5000).toInt();
int gameRewardPoints(int score) => (score ~/ 20).clamp(0, 30).toInt();

// ───────────────────────── 시세 변화율 ─────────────────────────

/// 전일(직전) 대비 변화율(%). 비교값이 없으면 null.
double? changePercent(double current, double? prev) {
  if (prev == null || prev <= 0) return null;
  return (current - prev) / prev * 100;
}

// ───────────────────────── 판매 보상 ─────────────────────────

/// 작물 1건을 판매할 때마다 받는 포인트 (판매 화면의 "Point +nP"에 쓴다)
const sellPointReward = 10;

// ───────────────────────── 레벨 업 보상 ─────────────────────────

/// 레벨 업 보상: 레벨이 높아질수록 더 많이 받는다.
/// 포인트: Lv.2는 500P에서 시작해 레벨이 한 번 오를 때마다 100P씩 늘어난다 (Lv.10 = 1,300P).
/// 희귀 씨앗: Lv.2~5는 1개, Lv.6~10은 2개, Lv.11~15는 3개 … 5레벨마다 1개씩 늘어난다.
const levelUpPointsBase = 500;
const levelUpPointsStep = 100;

int levelUpPointsFor(int level) => levelUpPointsBase + levelUpPointsStep * (level < 2 ? 0 : level - 2);

int levelUpSeedsFor(int level) => 1 + (level < 2 ? 0 : (level - 1) ~/ 5);

/// [from]에서 [to]로 올랐을 때 받는 보상의 합 (여러 레벨을 한 번에 올랐으면 레벨마다 계산해서 더한다)
(int points, int seeds) levelUpTotals(int from, int to) {
  var pts = 0, seeds = 0;
  for (var l = from + 1; l <= to; l++) {
    pts += levelUpPointsFor(l);
    seeds += levelUpSeedsFor(l);
  }
  return (pts, seeds);
}

String levelUpSeedCrop(int level) => crops[level % crops.length].code;

/// 레벨 업으로 실제 받은 보상 (여러 레벨을 한 번에 올랐으면 그만큼 합쳐서)
class LevelUpReward {
  const LevelUpReward({required this.points, required this.seedCode, required this.seedCount});
  final int points, seedCount;
  final String seedCode;
}

// ───────────────────────── 나의 칭호 ─────────────────────────

/// 농부 칭호: 레벨이 오르면 더 멋진 칭호로 바뀐다.
class FarmerTitle {
  const FarmerTitle(this.minLevel, this.name, this.emoji);
  final int minLevel;
  final String name, emoji;
}

const farmerTitles = [
  FarmerTitle(1, '새싹 농부', '🌱'),
  FarmerTitle(3, '초보 농부', '🌿'),
  FarmerTitle(5, '성실한 농부', '🌾'),
  FarmerTitle(7, '베테랑 농부', '🥬'),
  FarmerTitle(10, '농장 이장님', '🏡'),
  FarmerTitle(13, '농업 명인', '🏆'),
  FarmerTitle(17, '전설의 농부', '👑'),
  FarmerTitle(20, '농산물 박사', '🎓'),
  FarmerTitle(25, '시세 박사', '📊'),
  FarmerTitle(30, '대농장주', '🚜'),
  FarmerTitle(40, '스마트팜 대표', '🤖'),
  FarmerTitle(50, '농업의 달인', '🌟'),
  FarmerTitle(60, '풍요의 수호자', '🛡️'),
  FarmerTitle(75, '우주 농부', '🚀'),
  FarmerTitle(100, '농부의 신', '🔱'),
];

/// [level]에 맞는 칭호의 번호 (farmerTitles의 위치)
int farmerTitleIndex(int level) {
  var idx = 0;
  for (var i = 0; i < farmerTitles.length; i++) {
    if (level >= farmerTitles[i].minLevel) idx = i;
  }
  return idx;
}

/// 지금 쓸 칭호 번호. 사용자가 장착한 칭호([equipped])가 있고 이미 얻은 것이면 그것을, 아니면 레벨에 맞는 가장 높은 칭호를 쓴다.
int effectiveTitleIndex(int level, int? equipped) {
  if (equipped != null && equipped >= 0 && equipped < farmerTitles.length && level >= farmerTitles[equipped].minLevel) return equipped;
  return farmerTitleIndex(level);
}

/// [titleIndex] 칭호를 얻은 뒤 지금까지 올라간 단계 (그 칭호를 얻은 레벨이 1단계)
int titleRankOf(int level, int titleIndex) => (level - farmerTitles[titleIndex].minLevel + 1).clamp(1, 9999).toInt();

/// 다음 새 칭호까지 얼마나 왔는지 0.0~1.0 (경험치 막대까지 반영). 마지막 칭호면 1.
double titleProgress(LevelInfo lv) {
  final i = farmerTitleIndex(lv.level);
  if (i + 1 >= farmerTitles.length) return 1;
  final from = farmerTitles[i].minLevel, to = farmerTitles[i + 1].minLevel;
  return (((lv.level - from) + lv.ratio) / (to - from)).clamp(0.0, 1.0).toDouble();
}

/// 칭호 안에서의 단계 (1부터). 레벨이 한 번 오를 때마다 1씩 올라가고, 칭호 이름이 바뀌면 다시 1단계부터 시작한다.
int farmerTitleRank(int level) => (level < 1 ? 1 : level) - farmerTitles[farmerTitleIndex(level)].minLevel + 1;
