import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/progress_rules.dart';

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
  const Plot(this.index, this.cropCode, this.readyAt, {this.growMs = 0, this.bonus = 0, this.watered = 0, this.boosted = false});
  final int index;
  final String? cropCode;
  final DateTime? readyAt;

  /// 파종할 때 정해진 전체 성장 시간(ms). 진행률 계산에 쓴다. (이전 데이터에는 없을 수 있음)
  final int growMs;

  /// 영양제로 늘어난 수확량 비율 (0.2 = +20%)
  final double bonus;
  final int watered;
  final bool boosted;
  bool get isEmpty => cropCode == null;
  bool isReady(DateTime now) => !isEmpty && readyAt != null && !now.isBefore(readyAt!);

  /// 0.0 ~ 1.0 성장 진행률
  double progress(DateTime now) {
    if (isEmpty || readyAt == null) return 0;
    if (!now.isBefore(readyAt!)) return 1;
    if (growMs <= 0) return 0;
    final left = readyAt!.difference(now).inMilliseconds;
    return (1 - left / growMs).clamp(0.0, 1.0).toDouble();
  }

  factory Plot.fromDoc(Doc d) {
    final m = d.data()!;
    return Plot(int.parse(d.id), m['cropCode'] as String?, _dt(m['readyAt']),
        growMs: (m['growMs'] as num?)?.toInt() ?? 0,
        bonus: (m['bonus'] as num?)?.toDouble() ?? 0,
        watered: (m['watered'] as num?)?.toInt() ?? 0,
        boosted: m['boosted'] == true);
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

/// users/{uid} 문서를 화면에서 쓰기 좋게 감싼 읽기 전용 모델. 새로 생긴 필드가 없는 이전 데이터도 기본값으로 읽는다.
class UserData {
  const UserData(this.raw);
  final Map<String, dynamic> raw;

  int _i(String k) => (raw[k] as num?)?.toInt() ?? 0;
  Map<String, dynamic> _map(String k) => raw[k] is Map ? Map<String, dynamic>.from(raw[k] as Map) : <String, dynamic>{};
  List<String> _list(String k) => raw[k] is List ? (raw[k] as List).map((e) => '$e').toList() : <String>[];

  int get money => _i('money');
  int get totalProfit => _i('totalProfit');
  int get exp => _i('exp');
  int get points => _i('points');
  int get warehouseLevel => _i('warehouseLevel');
  int get warehouseBonusKg => _i('warehouseBonusKg');
  int get decor => _i('decor');

  /// 장착한 칭호 번호 (farmerTitles의 위치). 고르지 않았으면 null이고, 레벨에 맞는 가장 높은 칭호를 쓴다.
  int? get titleIdx => raw['titleIdx'] is num ? (raw['titleIdx'] as num).toInt() : null;

  /// 프로필 캐릭터: 남자 아이를 고르면 true (기본은 여자 아이)
  bool get isBoy => raw['avatar'] == 'boy';

  /// 지금 쓰는 칭호 번호 (장착한 것이 있으면 그것, 아니면 레벨에 맞는 칭호)
  int get titleIndex => effectiveTitleIndex(level.level, titleIdx);
  int get fundGiven => _i('fundGiven');
  /// 지은 하우스 수 (예전 데이터의 greenhouse: true 는 1채로 읽는다)
  /// 집 꾸미기: 방 이름 → 놓은 가구 목록 (home_decor_rules의 decorOfRoom으로 읽는다)
  Object? get homeDecor => raw['homeDecor'];

  /// 오늘 이용한 아파트 편의 시설 기록
  Map<String, dynamic>? get facilityDaily => raw['facilityDaily'] is Map ? Map<String, dynamic>.from(raw['facilityDaily'] as Map) : null;

  int get greenhouses {
    // 최대 [maxGreenhouses]채까지만 센다 (예전에 더 지은 계정도 320채로 보인다)
    final n = _i('greenhouses');
    final c = n > 0 ? n : (raw['greenhouse'] == true ? 1 : 0);
    return c > maxGreenhouses ? maxGreenhouses : c;
  }

  bool get greenhouse => greenhouses > 0;
  String get nickname {
    final n = raw['nickname'];
    return n is String && n.trim().isNotEmpty ? n.trim() : '농부';
  }

  Map<String, dynamic> get items => _map('items');
  int item(String key) => (items[key] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get stats => _map('stats');
  int stat(String key) => (stats[key] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get daily => raw['daily'] is Map ? _map('daily') : null;
  Map<String, dynamic>? get weekly => raw['weekly'] is Map ? _map('weekly') : null;
  List<String> get achClaimed => _list('achClaimed');
  List<String> get fundClaimed => _list('fundClaimed');

  LevelInfo get level => levelInfo(exp);
  int get warehouseCapKg => baseWarehouseKg + warehouseStepKg * warehouseLevel + warehouseBonusKg;
}

/// community/fund 문서 (마을 공동기금)
class FundData {
  const FundData(this.total, this.goal);
  final int total, goal;
  double get ratio => goal <= 0 ? 0 : (total / goal).clamp(0.0, 1.0).toDouble();
  factory FundData.fromMap(Map<String, dynamic>? m) =>
      FundData((m?['total'] as num?)?.toInt() ?? 0, (m?['goal'] as num?)?.toInt() ?? fundDefaultGoal);
}
