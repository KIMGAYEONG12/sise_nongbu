import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 품목 상세: 시세 / 판매량 / 공급량 / 전망
class PriceDetailPage extends ConsumerStatefulWidget {
  const PriceDetailPage({super.key, required this.cropCode});
  final String cropCode;
  @override
  ConsumerState<PriceDetailPage> createState() => _PriceDetailPageState();
}

class _PriceDetailPageState extends ConsumerState<PriceDetailPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = cropOf(widget.cropCode);
    final price = ref.watch(marketViewModelProvider).valueOrNull?[c.code];
    final pct = price == null ? null : changePercent(price.pricePerKg, price.prevPerKg);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '${c.name} 시세', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                SoftCard(
                  child: Row(children: [
                    EmojiBadge(c.emoji, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.name} · ${c.kind}', style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(price == null ? '시세 없음' : '${krw(price.pricePerKg)}/kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        if (price != null) Text('${price.asOf.month}월 ${price.asOf.day}일 기준', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                      ]),
                    ),
                    if (price != null) ChangeChip(percent: pct, amount: pct == null ? price.change : null),
                  ]),
                ),
                const SizedBox(height: 12),
                PillTabs(labels: const ['시세', '판매량', '공급량', '전망'], index: _tab, onChanged: (v) => setState(() => _tab = v)),
                const SizedBox(height: 12),
                if (_tab == 0) _PriceTab(code: c.code),
                if (_tab == 1) _VolumeTab(code: c.code),
                if (_tab == 2) _SupplyTab(code: c.code),
                if (_tab == 3) _OutlookTab(code: c.code),
                const SizedBox(height: 12),
                const Center(child: Text('가상 게임이며 실제 투자·거래 조언이 아닙니다.', style: TextStyle(fontSize: 11, color: AppColors.sub))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

List<String> _dayLabels(int n) {
  final now = DateTime.now();
  return [for (var i = n - 1; i >= 0; i--) '${now.subtract(Duration(days: i)).month}/${now.subtract(Duration(days: i)).day}'];
}

class _PriceTab extends ConsumerWidget {
  const _PriceTab({required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(priceHistoryProvider(code));
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('최근 7일 시세 (원/kg)', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        hist.when(
          loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox(height: 120, child: Center(child: Text('시세 기록을 불러오지 못했어요'))),
          data: (values) {
            final have = values.whereType<double>().length;
            return Column(children: [
              SizedBox(height: 180, width: double.infinity, child: CustomPaint(painter: LineChartPainter(values, _dayLabels(values.length)))),
              if (have < values.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('시세 기록이 있는 날 ${have}일만 표시돼요 (경매가 없었거나 조회되지 않은 날은 비어 있어요)',
                      style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _VolumeTab extends ConsumerWidget {
  const _VolumeTab({required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vol = ref.watch(priceVolumeProvider(code));
    final trades = ref.watch(tradesProvider).valueOrNull ?? const <Trade>[];
    final mine = trades.where((t) => t.cropCode == code).fold<double>(0, (a, t) => a + t.kg);
    return Column(children: [
      SoftCard(
        child: Row(children: [
          const EmojiBadge('📦'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('시장 경매 거래량', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w700)),
              vol.when(
                loading: () => const Text('불러오는 중…'),
                error: (_, __) => const Text('확인할 수 없어요'),
                data: (v) => Text(v == null ? '확인할 수 없어요' : '${commaNum(v)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      SoftCard(
        child: Row(children: [
          const EmojiBadge('🚚'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('내가 출하한 양', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w700)),
              Text('${commaNum(mine)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _SupplyTab extends ConsumerWidget {
  const _SupplyTab({required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cropOf(code);
    final plots = ref.watch(plotsProvider).valueOrNull ?? const <Plot>[];
    final lots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
    final growing = plots.where((p) => p.cropCode == code).toList();
    final expect = growing.fold<double>(0, (a, p) => a + c.yieldKg * (1 + p.bonus));
    final stock = lots.where((l) => l.cropCode == code).fold<double>(0, (a, l) => a + l.kg);
    Widget row(String emoji, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            EmojiBadge(emoji, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        );
    return SoftCard(
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('내 농장의 공급량', style: TextStyle(fontWeight: FontWeight.w800))),
        row('🌱', '재배 중인 밭', '${growing.length}칸'),
        row('🧺', '수확 예정량', '${commaNum(expect)} kg'),
        row('📦', '창고 보관량', '${commaNum(stock)} kg'),
      ]),
    );
  }
}

class _OutlookTab extends ConsumerWidget {
  const _OutlookTab({required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(priceHistoryProvider(code));
    return SoftCard(
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

/// 값이 없는(null) 날은 선을 끊어서 그리는 간단한 꺾은선 그래프
class LineChartPainter extends CustomPainter {
  LineChartPainter(this.values, this.labels);
  final List<double?> values;
  final List<String> labels;

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
    for (var i = 0; i < n; i++) {
      _text(canvas, labels[i], Offset(x(i), size.height - bottom + 5), 10, AppColors.sub, center: true);
    }
    if (nums.isEmpty) {
      _text(canvas, '표시할 시세가 없어요', Offset(size.width / 2, size.height / 2 - 8), 12, AppColors.sub, center: true);
      return;
    }
    var lo = nums.reduce((a, b) => a < b ? a : b), hi = nums.reduce((a, b) => a > b ? a : b);
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
    final line = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = AppColors.green;
    final ring = Paint()..color = Colors.white;
    Path? path;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      final p = Offset(x(i), y(v));
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) canvas.drawPath(path, line);
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(x(i), y(v));
      canvas.drawCircle(p, 5, ring);
      canvas.drawCircle(p, 3.5, dot);
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
  bool shouldRepaint(LineChartPainter old) => old.values != values || old.labels != labels;
}
