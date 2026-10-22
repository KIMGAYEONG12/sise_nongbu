/// 농장 하우스 → 아파트 성장 규칙 (그림과 상관없는 순수 규칙).
/// 하우스 단계(greenhouseStage: 지은 하우스 수 + 레벨로 오른 모양 단계)가 오를수록
/// 작은 농장 하우스(1~4) → 아파트(5~10)로 커진다. 10을 넘으면 "스카이 아파트 +n"으로 계속 이어진다.
library;

/// 하우스·아파트 한 단계 정보
class HomeLevel {
  const HomeLevel(this.name, this.desc, {required this.apartment});
  final String name, desc;

  /// 아파트 모양인지 (아니면 지붕 있는 농장 하우스)
  final bool apartment;
}

/// 1~10단계 (시안: 1~4레벨 하우스 → Lv.1 기본 아파트 ~ Lv.6 스카이 아파트)
const homeLevels = <HomeLevel>[
  HomeLevel('작은 농장 하우스', '아늑한 작은 농장 하우스', apartment: false),
  HomeLevel('넓은 농장 하우스', '조금 더 넓어진 하우스', apartment: false),
  HomeLevel('풍성한 농장 하우스', '더 넓고 풍성한 하우스', apartment: false),
  HomeLevel('프리미엄 농장 하우스', '유리 온실이 딸린 프리미엄 하우스', apartment: false),
  HomeLevel('기본 아파트', '아담하고 아늑한 첫 번째 아파트', apartment: true),
  HomeLevel('중형 아파트', '조금 더 넓어진 생활 공간', apartment: true),
  HomeLevel('대형 아파트', '더 많은 공간과 다양한 편의 시설', apartment: true),
  HomeLevel('프리미엄 아파트', '고급스러운 외관과 특별한 혜택', apartment: true),
  HomeLevel('럭셔리 아파트', '옥상 정원과 수영장이 있는 라이프스타일', apartment: true),
  HomeLevel('스카이 아파트', '하늘 위의 특별한 공간', apartment: true),
];

/// 그림·정보에 쓰는 단계(1~10). 하우스가 없으면(0 이하) 1로 본다.
int homeLevelOf(int stage) => stage < 1 ? 1 : (stage > homeLevels.length ? homeLevels.length : stage);

/// 아파트가 되는 첫 단계
const firstApartmentLevel = 5;

/// [stage]단계가 아파트 모양인지
bool isApartmentStage(int stage) => homeLevels[homeLevelOf(stage) - 1].apartment;

/// [stage]단계 이름. 10단계를 넘으면 "스카이 아파트 +1, +2 …"
String homeName(int stage) {
  final base = homeLevels[homeLevelOf(stage) - 1].name;
  return stage > homeLevels.length ? '$base +${stage - homeLevels.length}' : base;
}

/// 이름표에 붙이는 짧은 단계 표시: 하우스는 "1레벨", 아파트는 "Lv.1"부터 다시 센다 (시안 표기)
String homeBadge(int stage) {
  final lv = homeLevelOf(stage);
  return lv < firstApartmentLevel ? '$lv레벨 하우스' : '아파트 Lv.${lv - firstApartmentLevel + 1}';
}

/// [stage]단계의 설명
String homeDesc(int stage) => homeLevels[homeLevelOf(stage) - 1].desc;

/// 농장 그림에서의 크기 배율: 단계마다 커져서 아파트(키 큰 건물)는 최대 1.45배
double homeSizeScale(int stage) {
  final lv = homeLevelOf(stage);
  return 1 + (lv - 1) * 0.05;
}

/// 집 안의 방. 하우스·아파트 모두 거실·주방·침실이 있고, 3단계부터 발코니, 4단계 하우스는 온실이 생긴다.
enum HomeRoom { living, kitchen, bedroom, balcony, greenhouse }

String homeRoomName(HomeRoom r) => switch (r) {
      HomeRoom.living => '거실',
      HomeRoom.kitchen => '주방',
      HomeRoom.bedroom => '침실',
      HomeRoom.balcony => '발코니',
      HomeRoom.greenhouse => '유리 온실',
    };

/// [stage]단계에서 들어가 볼 수 있는 방들
List<HomeRoom> homeRoomsOf(int stage) {
  final lv = homeLevelOf(stage);
  return [
    HomeRoom.living,
    HomeRoom.kitchen,
    HomeRoom.bedroom,
    if (lv >= 3) HomeRoom.balcony,
    if (lv == 4) HomeRoom.greenhouse,
  ];
}

/// 아파트 편의 시설 (이모지, 이름). 아파트 단계가 오를 때마다 하나씩 늘어난다.
const homeFacilities = <(String, String)>[
  ('☕', '단지 카페'),
  ('🛝', '어린이 놀이터'),
  ('🏋️', '피트니스 센터'),
  ('🌳', '옥상 정원'),
  ('🏊', '루프탑 수영장'),
  ('🚁', '스카이 전망대'),
];

/// [stage]단계에서 쓸 수 있는 편의 시설 (하우스는 없음)
List<(String, String)> homeFacilitiesOf(int stage) {
  final lv = homeLevelOf(stage);
  if (lv < firstApartmentLevel) return const [];
  return homeFacilities.sublist(0, lv - firstApartmentLevel + 1);
}
