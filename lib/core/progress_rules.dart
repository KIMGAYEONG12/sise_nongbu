// 순수 Dart 진행 규칙 (레벨·경험치, 미션, 업적, 상점, 창고·밭 확장). Flutter/Firebase에 의존하지 않는다.
import 'game_rules.dart';

// ───────────────────────── 레벨 ─────────────────────────

/// 현재 레벨에서 다음 레벨까지 필요한 경험치. Lv1 → 200, Lv2 → 300, Lv3 → 400 …
int expToNext(int level) => 100 * (level + 1);

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
int warehouseCost(int level) => 20000 * (level + 1);

const maxPlots = 12;
const plotExpandStep = 3;

/// 밭 확장 비용. 6칸 → 50,000원, 9칸 → 100,000원. 최대치면 null.
int? plotExpandCost(int currentPlots) {
  if (currentPlots >= maxPlots) return null;
  final steps = (currentPlots - plotCount) ~/ plotExpandStep;
  return 50000 * (steps < 0 ? 1 : steps + 1);
}

const greenhouseCost = 100000;
const greenhouseSpeed = 0.8; // 하우스가 있으면 성장 시간 × 0.8

Duration applyGreenhouse(Duration d, bool greenhouse) =>
    greenhouse ? Duration(milliseconds: (d.inMilliseconds * greenhouseSpeed).round()) : d;

// ───────────────────────── 아이템 ─────────────────────────

const itemWater = 'water';
const itemFertilizer = 'fertilizer';
const itemBooster = 'booster';

const waterCut = 0.10; // 물주기: 전체 성장 시간의 10% 단축
const waterMaxPerPlot = 3;
const boosterCut = 0.30; // 성장촉진제: 전체 성장 시간의 30% 단축
const fertilizerBonus = 0.20; // 영양제: 수확량 +20%
const fertilizerMaxBonus = 0.40;

String seedKey(String cropCode) => 'seed_$cropCode';

class ShopItem {
  const ShopItem(this.key, this.name, this.emoji, this.price, this.desc);
  final String key, name, emoji, desc;
  final int price;
}

const consumables = [
  ShopItem(itemWater, '물통', '💧', 500, '물주기 1회 · 성장 시간 10% 단축 (밭당 최대 3회)'),
  ShopItem(itemFertilizer, '영양제', '🧪', 1500, '수확량 +20% (밭당 최대 2회)'),
  ShopItem(itemBooster, '성장촉진제', '⚡', 3000, '성장 시간 30% 단축 (밭당 1회)'),
];

/// 씨앗은 파종비의 85% 가격. 가지고 있으면 파종할 때 파종비 대신 씨앗을 쓴다.
int seedPrice(CropSpec c) => (c.seedCost * 0.85).round();

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
const maxDecor = 5;

class PointItem {
  const PointItem(this.key, this.name, this.emoji, this.cost, this.desc);
  final String key, name, emoji, desc;
  final int cost;
}

const pointItems = [
  PointItem(pointRareSeed, '희귀 씨앗', '🌰', 100, '무작위 작물의 씨앗 3개를 받아요'),
  PointItem(pointDecor, '농장 장식', '🌻', 80, '농장 화면에 꽃 장식이 늘어나요 (최대 5개)'),
  PointItem(pointVault, '특별 보관함', '🧰', 200, '창고 용량 +50kg (최대 3회)'),
  PointItem(pointLucky, '행운의 비료', '🍀', 150, '영양제 3개를 받아요'),
];

// ───────────────────────── 기간별 카운터 (일일/주간) ─────────────────────────

String dayTag(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 그 주 월요일 날짜를 주간 태그로 쓴다.
String weekTag(DateTime d) => dayTag(DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1)));

/// 태그가 같으면 이어서, 다르면 새로 시작한 카운터 맵을 돌려준다.
Map<String, dynamic> bumpPeriod(Map<String, dynamic>? old, String tag, String key, [int n = 1]) {
  final m = (old != null && old['tag'] == tag) ? Map<String, dynamic>.from(old) : <String, dynamic>{'tag': tag};
  m[key] = ((m[key] as num?)?.toInt() ?? 0) + n;
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
];

const weeklyMissions = [
  MissionDef('w_harvest', '작물 10번 수확하기', '🧺', 'harvest', 10, 100, true),
  MissionDef('w_sell', '작물 5번 판매하기', '💰', 'sell', 5, 100, true),
  MissionDef('w_plant', '작물 15번 파종하기', '🌱', 'plant', 15, 80, true),
  MissionDef('w_game', '작물 매칭 3번 하기', '🧩', 'game', 3, 50, true),
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
  AchievementDef('rich', '부자 농부', '보유 자금 200,000원을 달성해요', '💰', '도전', 50, 'money', 200000),
  AchievementDef('big_farm', '대규모 농장', '밭을 9칸 이상으로 넓혀요', '🌾', '도전', 50, 'plots', 9),
  AchievementDef('puzzle', '퍼즐 마스터', '작물 매칭을 1번 완료해요', '🧩', '특별', 20, 'stats.game', 1),
  AchievementDef('helper', '마을의 은인', '마을 공동기금에 합계 10,000원을 기부해요', '🏡', '특별', 40, 'stats.donate', 10000),
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

const gameDailyRewardLimit = 3;
int gameRewardMoney(int score) => (score * 20).clamp(0, 5000).toInt();
int gameRewardPoints(int score) => (score ~/ 20).clamp(0, 30).toInt();

// ───────────────────────── 시세 변화율 ─────────────────────────

/// 전일(직전) 대비 변화율(%). 비교값이 없으면 null.
double? changePercent(double current, double? prev) {
  if (prev == null || prev <= 0) return null;
  return (current - prev) / prev * 100;
}
