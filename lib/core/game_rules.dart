// 순수 Dart 게임 규칙. Flutter/Firebase에 의존하지 않는다.
import 'dart:math';

const startMoney = 100000;
const plotCount = 6;
const minFreshness = 0.7;
const dailyFreshnessLoss = 0.05;

class CropSpec {
  const CropSpec(this.code, this.name, this.emoji, this.seedCost, this.yieldKg, this.growHours);
  final String code, name, emoji;
  final int seedCost;
  final double yieldKg;
  final int growHours;
}

// TODO: code는 표준코드 API로 확인해 교체, 숫자는 시세를 본 뒤 조정 (10/12 이후 고정)
const crops = [
  CropSpec('CABBAGE', '배추', '🥬', 12000, 20, 4),
  CropSpec('RADISH', '무', '⚪', 9600, 20, 4),
  CropSpec('ONION', '양파', '🧅', 10800, 15, 5),
  CropSpec('APPLE', '사과', '🍎', 12600, 6, 6),
  CropSpec('TOMATO', '토마토', '🍅', 14400, 8, 5),
  CropSpec('POTATO', '감자', '🥔', 12000, 10, 3),
];

CropSpec cropOf(String code) => crops.firstWhere((c) => c.code == code);

Duration growDuration(CropSpec c, int speed) =>
    Duration(milliseconds: (c.growHours * 3600 * 1000 / max(1, speed)).round());

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
