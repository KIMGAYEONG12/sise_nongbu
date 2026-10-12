// 순수 Dart 시세 알림 규칙 (목표 가격에 닿으면 알려 준다). Flutter/Firebase에 의존하지 않는다.
import 'dart:convert';

/// 한 작물에 거는 시세 알림 하나.
/// [above]가 true면 "kg당 시세가 [target]원 이상이 되면", false면 "[target]원 이하가 되면" 알려 준다.
class PriceAlert {
  const PriceAlert({required this.code, required this.above, required this.target, this.fired = false});

  final String code;
  final bool above;
  final double target;

  /// 이미 알려 줬는지. 알려 준 뒤에는 사용자가 다시 설정할 때까지 또 울리지 않는다.
  final bool fired;

  /// 지금 시세 [price]가 알림 조건을 채웠는지
  bool hit(double price) => above ? price >= target : price <= target;

  PriceAlert copyWith({bool? fired}) => PriceAlert(code: code, above: above, target: target, fired: fired ?? this.fired);

  Map<String, dynamic> toJson() => {'c': code, 'a': above, 't': target, 'f': fired};

  static PriceAlert? fromJson(Object? j) {
    if (j is! Map) return null;
    final c = j['c'], a = j['a'], t = j['t'];
    if (c is! String || a is! bool || t is! num || t <= 0) return null;
    return PriceAlert(code: c, above: a, target: t.toDouble(), fired: j['f'] == true);
  }

  @override
  bool operator ==(Object other) => other is PriceAlert && other.code == code && other.above == above && other.target == target && other.fired == fired;

  @override
  int get hashCode => Object.hash(code, above, target, fired);
}

/// 저장할 문자열 (shared_preferences에 넣는다)
String encodeAlerts(Iterable<PriceAlert> alerts) => jsonEncode([for (final a in alerts) a.toJson()]);

/// 저장된 문자열을 읽는다. 비어 있거나 깨졌으면 빈 맵. 같은 작물이 여러 번 있으면 마지막 것을 쓴다.
Map<String, PriceAlert> decodeAlerts(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const {};
    final out = <String, PriceAlert>{};
    for (final e in list) {
      final a = PriceAlert.fromJson(e);
      if (a != null) out[a.code] = a;
    }
    return out;
  } catch (_) {
    return const {};
  }
}

/// 지금 시세에서 새로 울려야 하는 알림들 (조건을 채웠고 아직 알려 주지 않은 것). 시세가 없는 작물은 건너뛴다.
List<PriceAlert> dueAlerts(Map<String, PriceAlert> alerts, Map<String, double> prices) => [
      for (final a in alerts.values)
        if (!a.fired && prices[a.code] != null && a.hit(prices[a.code]!)) a,
    ];

/// 알림 설정 창에서 처음 보여 줄 목표 가격: 지금 시세에서 [above]면 5% 위, 아니면 5% 아래 (10원 단위로 반올림)
double suggestedTarget(double price, {required bool above}) {
  final raw = price * (above ? 1.05 : 0.95);
  final rounded = (raw / 10).round() * 10;
  return rounded <= 0 ? 10 : rounded.toDouble();
}
