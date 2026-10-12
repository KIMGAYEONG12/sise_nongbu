import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/price_alert.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';

/// 시세가 새로 들어왔을 때 목표 가격에 닿은 알림이 있으면 알림(기기 알림 + 화면 안내)을 한 번씩 띄운다.
/// 앱이 켜져 있는 동안 시세가 갱신될 때 확인한다 (앱을 완전히 끄면 확인하지 않는다).
void fireDueAlerts(BuildContext context, WidgetRef ref, Map<String, AuctionPrice>? prices) {
  if (prices == null || prices.isEmpty) return;
  final due = ref.read(priceAlertsProvider.notifier).check(prices);
  for (final a in due) {
    final c = cropOf(a.code);
    final now = prices[a.code]!.pricePerKg;
    final body = '${c.name} 시세가 ${krw(now)}/kg이 되어 목표(${krw(a.target)}) ${a.above ? '이상' : '이하'}에 닿았어요';
    try {
      ref.read(notificationProvider).showPriceAlert(crops.indexWhere((e) => e.code == a.code), '${c.name} 시세 알림', body);
    } catch (_) {
      // 알림 서비스가 없는 환경(테스트 등)에서는 화면 안내만 보여 준다
    }
    showCropMsg(context, a.code, body);
  }
}

/// "시세 알림 설정" 창: 목표 가격(원/kg)과 방향(이상 / 이하)을 정한다.
Future<void> showPriceAlertSheet(BuildContext context, String cropCode) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PriceAlertSheet(cropCode: cropCode),
    );

class PriceAlertSheet extends ConsumerStatefulWidget {
  const PriceAlertSheet({super.key, required this.cropCode});
  final String cropCode;

  @override
  ConsumerState<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends ConsumerState<PriceAlertSheet> {
  late bool _above;
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final old = ref.read(priceAlertsProvider)[widget.cropCode];
    final price = ref.read(marketViewModelProvider).valueOrNull?[widget.cropCode]?.pricePerKg;
    _above = old?.above ?? true;
    final start = old?.target ?? (price == null ? 1000.0 : suggestedTarget(price, above: _above));
    _c = TextEditingController(text: start.round().toString());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double? get _target {
    final v = double.tryParse(_c.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  /// 지금 시세에 [pct]% 더하거나 뺀 값을 목표로 채운다
  void _quick(double pct) {
    final price = ref.read(marketViewModelProvider).valueOrNull?[widget.cropCode]?.pricePerKg;
    if (price == null) return;
    final v = ((price * (1 + pct / 100)) / 10).round() * 10;
    setState(() {
      _above = pct >= 0;
      _c.text = (v <= 0 ? 10 : v).toString();
    });
  }

  void _save() {
    final t = _target;
    if (t == null) {
      showMsg(context, '목표 가격을 숫자로 입력해 주세요');
      return;
    }
    ref.read(priceAlertsProvider.notifier).set(widget.cropCode, above: _above, target: t);
    final prices = ref.read(marketViewModelProvider).valueOrNull;
    Navigator.of(context).pop();
    showMsg(context, '${cropOf(widget.cropCode).name} 시세가 ${krw(t)}/kg ${_above ? '이상' : '이하'}이 되면 알려 드릴게요');
    // 이미 조건을 채우고 있으면 바로 알려 준다
    fireDueAlerts(context, ref, prices);
  }

  void _off() {
    ref.read(priceAlertsProvider.notifier).clear(widget.cropCode);
    Navigator.of(context).pop();
    showMsg(context, '시세 알림을 껐어요');
  }

  @override
  Widget build(BuildContext context) {
    final c = cropOf(widget.cropCode);
    final price = ref.watch(marketViewModelProvider).valueOrNull?[c.code];
    final existing = ref.watch(priceAlertsProvider)[c.code];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            Row(children: [
              CropBadge(c.code, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c.name} 시세 알림', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF111111))),
                  const SizedBox(height: 2),
                  Text(price == null ? '지금 시세를 불러오는 중이에요' : '지금 ${krw(price.pricePerKg)}/kg', style: const TextStyle(fontSize: 13.5, color: Color(0xFF2B3A30), fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _dirButton('▲ 이상이 되면', true)),
              const SizedBox(width: 10),
              Expanded(child: _dirButton('▼ 이하가 되면', false)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '목표 가격', suffixText: '원/kg'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in const [-10.0, -5.0, 5.0, 10.0])
                ActionChip(
                  label: Text('${p > 0 ? '+' : ''}${p.round()}%', style: TextStyle(fontWeight: FontWeight.w800, color: p > 0 ? AppColors.up : AppColors.down)),
                  backgroundColor: Colors.white,
                  onPressed: price == null ? null : () => _quick(p),
                ),
            ]),
            const SizedBox(height: 10),
            const Text('앱이 켜져 있는 동안 시세가 새로 들어올 때 확인해서 알려 드려요. 가상 게임이며 실제 투자·거래 조언이 아닙니다.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF55655A), height: 1.4)),
            if (existing != null) ...[
              const SizedBox(height: 6),
              Text('지금 설정: ${krw(existing.target)}/kg ${existing.above ? '이상' : '이하'}${existing.fired ? ' (이미 알려 드렸어요)' : ''}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
            ],
            const SizedBox(height: 14),
            GreenButton(label: '알림 저장', icon: const Icon(Icons.notifications_active_rounded, size: 20), onPressed: _target == null ? null : _save),
            if (existing != null) ...[
              const SizedBox(height: 8),
              GreenButton(label: '알림 끄기', outlined: true, onPressed: _off),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _dirButton(String label, bool above) {
    final on = _above == above;
    final tone = above ? AppColors.up : AppColors.down;
    return GestureDetector(
      onTap: () => setState(() => _above = above),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tone.withValues(alpha: .12) : Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: on ? tone : AppColors.line, width: on ? 2 : 1.2),
        ),
        child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: on ? tone : const Color(0xFF55655A))),
      ),
    );
  }
}
