// 순수 Dart 게임 규칙. Flutter/Firebase에 의존하지 않는다.
import 'dart:math';

const startMoney = 100000;
const plotCount = 6;
const minFreshness = 0.7;
const dailyFreshnessLoss = 0.05;

class CropSpec {
  const CropSpec(this.code, this.name, this.emoji, this.seedCost, this.yieldKg, this.growMinutes,
      {this.kind = '채소', this.desc = ''});
  final String code, name, emoji;
  final int seedCost;
  final double yieldKg;
  /// 성장 시간(분). 배추는 1시간 안에 수확할 수 있게 50분.
  final int growMinutes;
  double get growHours => growMinutes / 60;

  /// 도감 분류: 채소 / 과일 / 특수
  final String kind;
  final String desc;
}

// TODO: code는 표준코드 API로 확인해 교체, 숫자는 시세를 본 뒤 조정 (10/12 이후 고정)
const crops = [
  CropSpec('CABBAGE', '배추', '🥬', 12000, 20, 50, kind: '채소', desc: '김장철에 수요가 몰리는 대표 엽채류. 가을배추 시세가 크게 움직여요.'),
  CropSpec('RADISH', '무', '⚪', 9600, 20, 240, kind: '채소', desc: '배추와 함께 오르내리는 경우가 많은 근채류예요.'),
  CropSpec('ONION', '양파', '🧅', 10800, 15, 300, kind: '채소', desc: '저장성이 좋아 시세 변동이 비교적 완만한 조미채소예요.'),
  CropSpec('APPLE', '사과', '🍎', 12600, 6, 360, kind: '과일', desc: '가을 출하기에 물량이 늘고 등급에 따라 가격 차이가 커요.'),
  CropSpec('TOMATO', '토마토', '🍅', 14400, 8, 300, kind: '과일', desc: '과채류로 날씨와 출하량에 따라 가격이 크게 변해요.'),
  CropSpec('POTATO', '감자', '🥔', 12000, 10, 180, kind: '특수', desc: '서류에 속하는 작물로 성장 시간이 짧은 편이에요.'),
  // ── 새로 열린 작물 (시세는 서울가락 도매시장 실제 경매 품목코드로 가져온다) ──
  CropSpec('CORN', '옥수수', '🌽', 9000, 12, 150, kind: '특수', desc: '잡곡류로 거래되는 여름 작물이에요. 여름철 출하량에 따라 가격이 움직여요.'),
  CropSpec('SWEETPOTATO', '고구마', '🍠', 10000, 12, 200, kind: '특수', desc: '서류에 속하고 가을에 거래가 가장 활발해요. 저장성이 좋아요.'),
  CropSpec('STRAWBERRY', '딸기', '🍓', 15000, 4, 200, kind: '과일', desc: '겨울~봄에 많이 나오는 인기 과일이에요. 가격이 높은 편이에요.'),
  CropSpec('PUMPKIN', '호박', '🎃', 9000, 15, 220, kind: '채소', desc: '애호박·늙은호박 등 종류가 다양한 과채류예요. 거래량이 많아요.'),
  CropSpec('FIG', '무화과', '🟣', 16000, 4, 280, kind: '과일', desc: '여름~가을에 나오는 부드러운 과일이에요. 쉽게 물러서 신선도가 중요해요.'),
  CropSpec('CARROT', '당근', '🥕', 9000, 15, 170, kind: '채소', desc: '근채류로 사계절 꾸준히 거래돼요. 시세 변동이 비교적 완만해요.'),
  CropSpec('CUCUMBER', '오이', '🥒', 8500, 12, 120, kind: '채소', desc: '빨리 자라는 과채류예요. 날씨에 따라 가격이 자주 바뀌어요.'),
  CropSpec('EGGPLANT', '가지', '🍆', 9500, 10, 160, kind: '채소', desc: '여름 대표 과채류예요. 출하량이 늘면 가격이 내려가요.'),
  CropSpec('GRAPE', '포도', '🍇', 15000, 5, 330, kind: '과일', desc: '가을 출하기에 품종별 가격 차이가 큰 과일이에요.'),
  CropSpec('PEAR', '배', '🍐', 13000, 7, 340, kind: '과일', desc: '추석 무렵 수요가 몰리는 과일이에요. 등급별 가격 차이가 커요.'),
  CropSpec('WATERMELON', '수박', '🍉', 16000, 12, 400, kind: '과일', desc: '여름 대표 과일이에요. 한 통의 무게가 커서 한 번에 많이 수확돼요.'),
  CropSpec('MANDARIN', '감귤', '🍊', 12000, 8, 260, kind: '과일', desc: '겨울철 대표 과일이에요. 당도에 따라 가격이 달라져요.'),
  CropSpec('PAPRIKA', '파프리카', '🫑', 11000, 9, 190, kind: '채소', desc: '색이 다양한 양채류예요. 사계절 거래되고 수출도 많아요.'),
  CropSpec('GARLIC', '마늘', '🧄', 9500, 6, 240, kind: '채소', desc: '조미채소류예요. 저장성이 좋아 시세 변동이 완만한 편이에요.'),
  CropSpec('BROCCOLI', '브로콜리', '🥦', 10000, 8, 140, kind: '채소', desc: '영양이 풍부한 양채류예요. 선선한 철에 거래가 늘어요.'),
];

/// 도감에 "준비 중"으로만 보여주는 작물 (아직 심을 수 없음)
const lockedCrops = [
  ('바나나', '🍌'),
  ('복숭아', '🍑'),
  ('양상추', '🥗'),
];

CropSpec cropOf(String code) => crops.firstWhere((c) => c.code == code);

/// 데모 모드(발표·시연용) 배속 값. 이 값이면 작물 종류와 상관없이 파종 1초 뒤에 수확할 수 있다.
const demoSpeed = 1000000;

/// 데모 모드에서 작물이 다 자라는 시간
const demoGrowTime = Duration(seconds: 1);

Duration growDuration(CropSpec c, int speed) =>
    speed >= demoSpeed ? demoGrowTime : Duration(milliseconds: (c.growMinutes * 60 * 1000 / max(1, speed)).round());

double freshnessOf(DateTime harvestedAt, DateTime now) =>
    max(minFreshness, 1 - dailyFreshnessLoss * now.difference(harvestedAt).inDays);

int saleAmount(double kg, double pricePerKg, double freshness) =>
    (kg * pricePerKg * freshness).round();

/// 경매 건의 포장 단위(kg)로 kg당 가격 환산. 환산 불가면 null.
double? toPricePerKg(double price, double unitKg) => unitKg > 0 ? price / unitKg : null;

class AuctionRow {
  const AuctionRow(this.pricePerKg, this.volumeKg);
  final double pricePerKg, volumeKg;
}

/// 거래량 가중평균. 유효한 건이 없으면 null.
double? weightedPrice(List<AuctionRow> rows) {
  var vol = 0.0, sum = 0.0;
  for (final r in rows) {
    if (r.volumeKg <= 0) continue;
    vol += r.volumeKg;
    sum += r.pricePerKg * r.volumeKg;
  }
  return vol == 0 ? null : sum / vol;
}
