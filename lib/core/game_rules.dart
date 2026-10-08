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
];

/// 도감에 "준비 중"으로만 보여주는 작물 (아직 심을 수 없음)
const lockedCrops = [
  ('옥수수', '🌽'),
  ('딸기', '🍓'),
  ('호박', '🎃'),
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
