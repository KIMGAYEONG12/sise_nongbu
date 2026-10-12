import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/price_alert.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'price_alert_ui.dart';

/// 시세판 상세 (시안): 작물 · 현재 시세 · 등락 → 7일/14일/30일 그래프 → 거래량·평균가 → 시세 알림 설정.
/// 아래로 내리면 시세 전망, 내 농장의 공급량, 내가 출하한 양도 볼 수 있다.
class PriceDetailPage extends ConsumerStatefulWidget {
  const PriceDetailPage({super.key, required this.cropCode});
  final String cropCode;
  @override
  ConsumerState<PriceDetailPage> createState() => _PriceDetailPageState();
}

/// 그래프로 볼 수 있는 기간(일). 서버가 최근 30일을 저장해 둔다.
const priceRanges = [7, 14, 30];

class _PriceDetailPageState extends ConsumerState<PriceDetailPage> {
  int _range = 0;

  int get _days => priceRanges[_range];

  @override
  Widget build(BuildContext context) {
    final c = cropOf(widget.cropCode);
    final price = ref.watch(marketViewModelProvider).valueOrNull?[c.code];
    final pct = price == null ? null : changePercent(price.pricePerKg, price.prevPerKg);
    final alert = ref.watch(priceAlertsProvider)[c.code];

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '시세판 상세', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                _HeaderCard(spec: c, price: price, percent: pct),
                const SizedBox(height: 12),
                PillTabs(labels: [for (final d in priceRanges) '$d일'], index: _range, onChanged: (v) => setState(() => _range = v)),
                const SizedBox(height: 12),
                _ChartCard(code: c.code, days: _days),
                const SizedBox(height: 12),
                _SummaryCard(code: c.code, days: _days, price: price),
                const SectionTitle('시세 전망'),
                _OutlookCard(code: c.code, days: _days),
                const SectionTitle('내 농장'),
                _FarmCard(code: c.code),
                const SizedBox(height: 12),
                const Center(child: Text('가상 게임이며 실제 투자·거래 조언이 아닙니다.', style: TextStyle(fontSize: 11, color: AppColors.sub))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: _AlertButton(alert: alert, onTap: () => showPriceAlertSheet(context, c.code)),
            ),
          ]),
        ),
      ),
    );
  }
}

BoxDecoration _panel() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE3ECD9), width: 1.2),
      boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .10), blurRadius: 10, offset: const Offset(0, 3))],
    );

/// 맨 위 카드: 큰 작물 그림 · 이름 · 현재 시세 · 등락 알약
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.spec, required this.price, required this.percent});
  final CropSpec spec;
  final AuctionPrice? price;
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final p = price;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: _panel(),
      child: Row(children: [
        CropArt(code: spec.code, size: 72),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${spec.name} · ${spec.kind}', style: const TextStyle(fontSize: 14, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(p == null ? '시세 없음' : '${krw(p.pricePerKg)}/kg', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
            if (p != null) Text('${p.asOf.month}월 ${p.asOf.day}일 기준', style: const TextStyle(fontSize: 11.5, color: Color(0xFF55655A))),
          ]),
        ),
        if (p != null) _ChangePill(percent: percent, amount: percent == null ? p.change : null),
      ]),
    );
  }
}

/// ▲ 12.4% (오르면 빨강) / ▼ 5.2% (내리면 파랑) / – 보합 알약
class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.percent, this.amount});
  final double? percent;
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final v = percent ?? amount;
    if (v == null) return const SizedBox.shrink();
    final flat = percent != null ? percent!.abs() < 0.05 : v.abs() < 0.5;
    final up = v > 0;
    final color = flat ? const Color(0xFF55655A) : (up ? AppColors.up : AppColors.down);
    final label = percent != null ? '${percent!.abs().toStringAsFixed(1)}%' : krw(amount!.abs());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(flat ? '–' : (up ? '▲' : '▼'), style: TextStyle(color: color, fontSize: 13, height: 1)),
        const SizedBox(width: 5),
        Text(flat ? '0.0%' : label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    );
  }
}

List<String> _dayLabels(int n) {
  final now = DateTime.now();
  return [
    for (var i = n - 1; i >= 0; i--) '${now.subtract(Duration(days: i)).month}/${now.subtract(Duration(days: i)).day}',
  ];
}

/// 그래프 카드: 기간(일) 동안의 kg당 시세를 초록 면적 그래프로 보여 준다.
class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.code, required this.days});
  final String code;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(priceHistoryProvider((code, days)));
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('최근 $days일 시세 (원/kg)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF111111))),
        const SizedBox(height: 12),
        hist.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox(height: 120, child: Center(child: Text('시세 기록을 불러오지 못했어요'))),
          data: (values) {
            final have = values.whereType<double>().length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 200, width: double.infinity, child: CustomPaint(painter: LineChartPainter(values, _dayLabels(values.length)))),
              if (have < values.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('시세 기록이 있는 날 $have일만 표시돼요 (경매가 없었거나 아직 모이지 않은 날은 비어 있어요)', style: const TextStyle(fontSize: 11, color: Color(0xFF55655A))),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// 요약 카드 (시안의 거래량 · 평균가): 최근 거래일 거래량, 기간 평균가와 현재 시세 비교, 최고·최저가
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.code, required this.days, required this.price});
  final String code;
  final int days;
  final AuctionPrice? price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vol = ref.watch(priceVolumeProvider(code));
    final values = (ref.watch(priceHistoryProvider((code, days))).valueOrNull ?? const <double?>[]).whereType<double>().toList();
    final stats = PriceStats.of(values, price?.pricePerKg);
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          // 글씨가 커지거나 값이 길어도 넘치지 않게: 값은 남는 자리 안에서 줄어든다
          child: Row(children: [
            Text(label, style: const TextStyle(fontSize: 14.5, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: value))),
          ]),
        );
    Text bold(String t) => Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111111)));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: _panel(),
      child: Column(children: [
        row(
          '거래량',
          vol.when(loading: () => bold('불러오는 중…'), error: (_, __) => bold('확인할 수 없어요'), data: (v) => bold(v == null ? '확인할 수 없어요' : '${commaNum(v)}kg')),
        ),
        const Divider(height: 1, color: AppColors.line),
        row(
          '평균가',
          Row(mainAxisSize: MainAxisSize.min, children: [
            bold(stats == null ? '-' : '${krw(stats.avg)}/kg'),
            if (stats?.vsAvg != null) ...[const SizedBox(width: 8), ChangeChip(percent: stats!.vsAvg)],
          ]),
        ),
        const Divider(height: 1, color: AppColors.line),
        row('최고 · 최저가', bold(stats == null ? '-' : '${krw(stats.high)} · ${krw(stats.low)}')),
      ]),
    );
  }
}

/// 기간 시세 요약: 평균·최고·최저, 그리고 현재 시세가 평균보다 몇 % 높은지
class PriceStats {
  const PriceStats(this.avg, this.high, this.low, this.vsAvg);
  final double avg, high, low;

  /// 현재 시세가 평균보다 높거나 낮은 정도(%). 현재 시세를 모르면 null.
  final double? vsAvg;

  static PriceStats? of(List<double> values, double? current) {
    if (values.isEmpty) return null;
    final avg = values.fold<double>(0, (a, b) => a + b) / values.length;
    return PriceStats(avg, values.reduce(math.max), values.reduce(math.min), current == null ? null : changePercent(current, avg));
  }
}

/// 시세 전망: 기간 평균과 지금 시세를 단순 비교한다 (예측이 아님)
class _OutlookCard extends ConsumerWidget {
  const _OutlookCard({required this.code, required this.days});
  final String code;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(priceHistoryProvider((code, days)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(),
      child: hist.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => const Text('전망을 계산하지 못했어요'),
        data: (values) {
          final v = values.whereType<double>().toList();
          if (v.length < 2) {
            return const Text('비교할 시세 기록이 2일 이상 있어야 추세를 보여드릴 수 있어요.', style: TextStyle(height: 1.5));
          }
          final avg = v.fold<double>(0, (a, b) => a + b) / v.length;
          final last = v.last;
          final diff = changePercent(last, avg) ?? 0;
          final first = changePercent(last, v.first) ?? 0;
          final String label, emoji;
          if (diff > 3) {
            label = '평균보다 높은 편';
            emoji = '📈';
          } else if (diff < -3) {
            label = '평균보다 낮은 편';
            emoji = '📉';
          } else {
            label = '평균과 비슷한 수준';
            emoji = '➖';
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 12),
            Text('최근 ${v.length}일 평균 ${krw(avg)}/kg · 현재 ${krw(last)}/kg (${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 13, height: 1.5)),
            Text('기간 처음 대비 ${first >= 0 ? '+' : ''}${first.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
            const SizedBox(height: 10),
            const Text('※ 최근 시세 흐름을 단순 비교한 것으로, 앞으로의 가격을 예측하는 것이 아니에요.', style: TextStyle(fontSize: 11, color: AppColors.sub, height: 1.4)),
          ]);
        },
      ),
    );
  }
}

/// 내 농장의 공급량(재배 중·수확 예정·창고 보관)과 내가 출하한 양
class _FarmCard extends ConsumerWidget {
  const _FarmCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cropOf(code);
    final plots = ref.watch(plotsProvider).valueOrNull ?? const <Plot>[];
    final lots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
    final trades = ref.watch(tradesProvider).valueOrNull ?? const <Trade>[];
    final growing = plots.where((p) => p.cropCode == code).toList();
    final expect = growing.fold<double>(0, (a, p) => a + c.yieldKg * (1 + p.bonus));
    final stock = lots.where((l) => l.cropCode == code).fold<double>(0, (a, l) => a + l.kg);
    final sold = trades.where((t) => t.cropCode == code).fold<double>(0, (a, t) => a + t.kg);
    Widget row(String emoji, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            EmojiBadge(emoji, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: _panel(),
      child: Column(children: [
        row('🌱', '재배 중인 밭', '${growing.length}칸'),
        row('🧺', '수확 예정량', '${commaNum(expect)} kg'),
        row('📦', '창고 보관량', '${commaNum(stock)} kg'),
        row('🚚', '내가 출하한 양', '${commaNum(sold)} kg'),
      ]),
    );
  }
}

/// 맨 아래 "시세 알림 설정" 버튼 (시안의 큰 초록 알약). 알림을 걸어 두었으면 조건을 같이 보여 준다.
class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.alert, required this.onTap});
  final PriceAlert? alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(29),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3AA652), Color(0xFF14702F)]),
            boxShadow: [BoxShadow(color: const Color(0xFF14702F).withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                alert == null ? '시세 알림 설정' : '시세 알림 설정 · ${krw(alert!.target)} ${alert!.above ? '이상' : '이하'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ]),
        ),
      );
}

/// 값이 없는(null) 날은 선을 끊어서 그리는 면적 꺾은선 그래프 (시안: 초록 선 + 점 + 옅은 초록 면적).
/// 점이 많은 긴 기간(15일 넘게)은 점을 작게 하거나 마지막 점만 그리고, 날짜 글자는 겹치지 않게 띄엄띄엄 보여 준다.
class LineChartPainter extends CustomPainter {
  LineChartPainter(this.values, this.labels, {this.fill = true});
  final List<double?> values;
  final List<String> labels;

  /// 선 아래를 옅은 초록으로 채울지
  final bool fill;

  /// 날짜 글자를 몇 칸마다 하나씩 보여 줄지 (최대 6개 안팎)
  static int labelStep(int n) => math.max(1, (n / 6).ceil());

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, bottom = 22.0, top = 8.0, right = 8.0;
    final w = size.width - left - right, h = size.height - bottom - top;
    final nums = values.whereType<double>().toList();
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = top + h * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
    }
    final n = values.length;
    double x(int i) => n <= 1 ? left + w / 2 : left + w * i / (n - 1);
    final step = labelStep(n);
    for (var i = 0; i < n; i++) {
      // 첫 칸부터 step 간격으로, 마지막 칸은 앞 글자와 너무 붙지 않을 때만
      final show = i % step == 0 || (i == n - 1 && (n - 1) % step >= (step + 1) ~/ 2);
      if (!show) continue;
      _text(canvas, labels[i], Offset(x(i), size.height - bottom + 5), 10, AppColors.sub, center: true);
    }
    if (nums.isEmpty) {
      _text(canvas, '표시할 시세가 없어요', Offset(size.width / 2, size.height / 2 - 8), 12, AppColors.sub, center: true);
      return;
    }
    var lo = nums.reduce(math.min), hi = nums.reduce(math.max);
    if ((hi - lo).abs() < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * .1;
    lo -= pad;
    hi += pad;
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));
    for (var i = 0; i < 4; i++) {
      final v = hi - (hi - lo) * i / 3;
      _text(canvas, commaNum(v), Offset(left - 6, top + h * i / 3 - 6), 10, AppColors.sub, right: true);
    }

    // 값이 이어진 구간마다 선과 면적을 그린다
    final line = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final areaPaint = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x552F8F3E), Color(0x082F8F3E)]).createShader(Rect.fromLTWH(left, top, w, h));
    final segments = <List<Offset>>[];
    var cur = <Offset>[];
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) {
        if (cur.isNotEmpty) segments.add(cur);
        cur = <Offset>[];
        continue;
      }
      cur.add(Offset(x(i), y(v)));
    }
    if (cur.isNotEmpty) segments.add(cur);
    final baseY = top + h;
    for (final seg in segments) {
      if (seg.length >= 2) {
        final path = Path()..moveTo(seg.first.dx, seg.first.dy);
        for (final p in seg.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        if (fill) {
          final area = Path.from(path)
            ..lineTo(seg.last.dx, baseY)
            ..lineTo(seg.first.dx, baseY)
            ..close();
          canvas.drawPath(area, areaPaint);
        }
        canvas.drawPath(path, line);
      }
    }

    // 점: 기간이 짧으면 크게, 길면 작게, 아주 길면 마지막 점만
    final dot = Paint()..color = AppColors.green;
    final ring = Paint()..color = Colors.white;
    final r = n <= 8 ? 5.0 : (n <= 16 ? 3.6 : 2.6);
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      if (n > 16 && i != n - 1) continue;
      final p = Offset(x(i), y(v));
      canvas.drawCircle(p, r + 1.5, ring);
      canvas.drawCircle(p, r, dot);
    }
  }

  void _text(Canvas canvas, String s, Offset o, double size, Color color, {bool center = false, bool right = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout();
    var dx = o.dx;
    if (center) dx -= tp.width / 2;
    if (right) dx -= tp.width;
    tp.paint(canvas, Offset(dx, o.dy));
  }

  @override
  bool shouldRepaint(LineChartPainter old) => old.values != values || old.labels != labels || old.fill != fill;
}
