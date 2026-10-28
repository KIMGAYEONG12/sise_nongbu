/// 집 꾸미기(저택·하우스·아파트 방에 가구 놓기)와 아파트 편의 시설 효과 규칙 (그림과 상관없는 순수 규칙).
library;

import 'home_rules.dart';
import 'progress_rules.dart';

// ───────────────────────── 집 꾸미기 ─────────────────────────

/// 방에 놓을 수 있는 가구 (코드로 그려서 그림 파일이 늘지 않는다)
class DecorItem {
  const DecorItem(this.key, this.name, this.emoji);
  final String key, name, emoji;
}

const decorItems = <DecorItem>[
  DecorItem('plant', '작은 화분', '🪴'),
  DecorItem('bigplant', '큰 화분', '🌿'),
  DecorItem('vase', '꽃병', '💐'),
  DecorItem('rug', '동그란 러그', '🟣'),
  DecorItem('chair', '의자', '🪑'),
  DecorItem('stool', '쿠션 스툴', '🟡'),
  DecorItem('lamp', '스탠드 조명', '💡'),
  DecorItem('shelf', '책장', '📚'),
  DecorItem('bear', '곰인형', '🧸'),
  DecorItem('gift', '선물 상자', '🎁'),
  DecorItem('tree', '반짝이 트리', '🎄'),
  DecorItem('fishbowl', '어항', '🐠'),
  DecorItem('piano', '피아노', '🎹'),
  DecorItem('cat', '고양이 방석', '🐱'),
];

DecorItem? decorItemOf(String key) {
  for (final d in decorItems) {
    if (d.key == key) return d;
  }
  return null;
}

/// 한 방에 놓을 수 있는 가구 수
const maxDecorPerRoom = 12;

/// 방 바닥 위 가구 하나: 바닥 좌표 x(오른쪽 벽 방향), y(왼쪽 벽 방향)는 0~1
class DecorPlacement {
  const DecorPlacement(this.key, this.x, this.y);
  final String key;
  final double x, y;

  DecorPlacement moved(double nx, double ny) => DecorPlacement(key, clampFloor(nx), clampFloor(ny));

  Map<String, dynamic> toMap() => {'k': key, 'x': double.parse(x.toStringAsFixed(3)), 'y': double.parse(y.toStringAsFixed(3))};

  static DecorPlacement? fromMap(Object? m) {
    if (m is! Map) return null;
    final k = m['k'];
    final x = (m['x'] as num?)?.toDouble(), y = (m['y'] as num?)?.toDouble();
    if (k is! String || decorItemOf(k) == null || x == null || y == null) return null;
    return DecorPlacement(k, clampFloor(x), clampFloor(y));
  }
}

/// 가구가 벽 밖으로 나가지 않게 바닥 안쪽으로 맞춘다
double clampFloor(double v) => v < .08 ? .08 : (v > .94 ? .94 : v);

/// 저장할 때 쓰는 방 이름: 저택과 하우스·아파트는 따로 꾸민다 (예: mansion_living, home_kitchen)
String decorRoomKey({required bool mansion, required HomeRoom room}) => '${mansion ? 'mansion' : 'home'}_${room.name}';

/// 사용자 문서의 homeDecor 값에서 한 방의 가구 목록을 읽는다 (잘못된 값은 건너뛴다)
List<DecorPlacement> decorOfRoom(Object? homeDecor, String roomKey) {
  if (homeDecor is! Map) return const [];
  final list = homeDecor[roomKey];
  if (list is! List) return const [];
  return [
    for (final e in list.take(maxDecorPerRoom))
      if (DecorPlacement.fromMap(e) case final p?) p,
  ];
}

/// 앞쪽(화면 아래)에 있는 가구가 나중에 그려지도록 깊이 순서로 정렬한 번호들
List<int> decorDrawOrder(List<DecorPlacement> list) => [for (var i = 0; i < list.length; i++) i]..sort((a, b) => (list[a].x + list[a].y).compareTo(list[b].x + list[b].y));

// ───────────────────────── 아파트 편의 시설 ─────────────────────────

/// 편의 시설 하나를 하루 한 번 이용하면 받는 것 (homeFacilities와 같은 순서)
class FacilityPerk {
  const FacilityPerk(this.desc, {this.water = 0, this.fertilizer = 0, this.booster = 0, this.exp = 0, this.points = 0});
  final String desc;
  final int water, fertilizer, booster, exp, points;

  /// 받은 것을 알려 주는 짧은 문구
  String get rewardText => [
        if (water > 0) '물통 $water개',
        if (fertilizer > 0) '영양제 $fertilizer개',
        if (booster > 0) '성장촉진제 $booster개',
        if (exp > 0) '경험치 $exp',
        if (points > 0) '캐시 $points',
      ].join(' · ');
}

const facilityPerks = <FacilityPerk>[
  FacilityPerk('커피 한 잔과 함께 물통을 챙겨요', water: 3),
  FacilityPerk('아이들과 뛰어놀며 경험치를 얻어요', exp: 150),
  FacilityPerk('운동하고 힘이 나서 경험치를 많이 얻어요', exp: 300),
  FacilityPerk('옥상 텃밭에서 영양제를 만들어요', fertilizer: 2),
  FacilityPerk('수영하고 기운이 나서 성장촉진제를 받아요', booster: 1),
  FacilityPerk('전망대에서 시세를 내려다보고 캐시를 받아요', points: 30),
];

/// 저장에 쓰는 시설 번호 (하루에 시설마다 한 번)
String facilityId(int index) => 'f$index';

/// [stage] 집에서 [index]번 시설을 쓸 수 있는지
bool canUseFacility(int stage, int index) => index >= 0 && index < homeFacilitiesOf(stage).length && index < facilityPerks.length;

/// 오늘 이미 이용한 시설인지 (사용자 문서의 facilityDaily 값으로)
bool facilityUsedToday(Map<String, dynamic>? daily, int index, DateTime now) => periodClaimed(daily, dayTag(now)).contains(facilityId(index));
