import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/korean.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';

/// 판매 완료 문구. 예) 배추가 판매되었습니다! / 배추, 무가 판매되었습니다! / 배추 외 2종이 판매되었습니다!
String soldMessage(List<String> cropNames) {
  final names = <String>[];
  for (final n in cropNames) {
    if (!names.contains(n)) names.add(n);
  }
  if (names.isEmpty) return '판매되었습니다!';
  if (names.length <= 2) return '${withJosa(names.join(', '), '이', '가')} 판매되었습니다!';
  return '${names.first} 외 ${names.length - 1}종이 판매되었습니다!';
}

/// 판매 완료 창: 판 작물 그림(여러 종이면 나란히)과 "토마토가 판매되었습니다!" 문구, 받은 금액·포인트를 보여 준다.
Future<void> showSoldDialog(BuildContext context, List<String> cropCodes, List<String> cropNames, int total, int points) => showDialog<void>(
      context: context,
      builder: (d) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4C2), Color(0xFFFFFFFF), Color(0xFFEAF6DF)]),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final code in cropCodes.take(6)) CropArt(code: code, size: cropCodes.length == 1 ? 110 : (cropCodes.length <= 3 ? 80 : 60))],
            ),
            const SizedBox(height: 14),
            Text(soldMessage(cropNames), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.greenDark, height: 1.3)),
            const SizedBox(height: 10),
            Text('+${won(total)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text('Point +${points}P', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
            const SizedBox(height: 18),
            GreenButton(label: '확인', onPressed: () => Navigator.of(d).pop()),
          ]),
        ),
      ),
    );

/// 판매할 작물 선택 (시안): 창고의 수확물을 골라 현재 시세로 한꺼번에 출하한다.
/// 아래 "예상 수익" 카드에 총 판매금액 · 판매이익 · Point 가 나온다.
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key, this.initialCrop});

  /// 창고에서 작물을 눌러 들어왔을 때: 이 작물의 수확물만 보여 준다 (자동으로 골라 두지는 않는다)
  final String? initialCrop;
  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> {
  final _picked = <String>{};
  bool _busy = false;

  Future<void> _sell(List<Lot> chosen, int total) async {
    setState(() => _busy = true);
    final vm = ref.read(farmViewModelProvider);
    final soldNames = <String>[];
    final soldCodes = <String>[];
    String? error;
    for (final l in chosen) {
      try {
        await vm.sell(l);
        soldNames.add(cropOf(l.cropCode).name);
        if (!soldCodes.contains(l.cropCode)) soldCodes.add(l.cropCode);
        _picked.remove(l.id);
      } catch (e) {
        error = errMsg(e);
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showMsg(context, soldNames.isNotEmpty ? '${soldMessage(soldNames)} 이후 중단: $error' : error);
    } else {
      // 작물 그림과 함께 "토마토가 판매되었습니다!" 창을 보여 준 뒤 창고로 돌아간다
      await showSoldDialog(context, soldCodes, soldNames, total, chosen.length * sellPointReward);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
    final only = widget.initialCrop;
    final lots = only == null ? allLots : allLots.where((l) => l.cropCode == only).toList();
    final prices = ref.watch(marketViewModelProvider).valueOrNull ?? const <String, AuctionPrice>{};
    final now = DateTime.now();

    int amountOf(Lot l) {
      final p = prices[l.cropCode];
      return p == null ? 0 : saleAmount(l.kg, p.pricePerKg, freshnessOf(l.harvestedAt, now));
    }

    final chosen = lots.where((l) => _picked.contains(l.id) && prices[l.cropCode] != null).toList();
    final total = chosen.fold<int>(0, (a, l) => a + amountOf(l));
    final points = chosen.length * sellPointReward;
    final sellable = lots.where((l) => prices[l.cropCode] != null).toList();
    final allOn = sellable.isNotEmpty && sellable.every((l) => _picked.contains(l.id));

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
              title: '판매할 작물 선택',
              onBack: () => Navigator.of(context).pop(),
              trailing: TextButton(
                onPressed: sellable.isEmpty ? null : () => setState(() => allOn ? _picked.clear() : _picked.addAll(sellable.map((l) => l.id))),
                child: Text(allOn ? '선택 해제' : '전체 선택'),
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                if (lots.isEmpty)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('판매할 작물이 없어요', style: TextStyle(color: AppColors.sub)))),
                for (final l in lots)
                  _LotRow(
                    lot: l,
                    amount: prices[l.cropCode] == null ? null : amountOf(l),
                    selected: _picked.contains(l.id),
                    onTap: prices[l.cropCode] == null ? null : () => setState(() => _picked.contains(l.id) ? _picked.remove(l.id) : _picked.add(l.id)),
                  ),
                const SizedBox(height: 2),
                // 시안: 예상 수익 카드 (총 판매금액 / 판매이익 / Point)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: _cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('예상 수익', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF111111))),
                    const SizedBox(height: 12),
                    _Row(icon: const Text('🌿', style: TextStyle(fontSize: 18, height: 1)), label: '총 판매금액', value: won(total), bold: true),
                    const Divider(height: 22, color: AppColors.line),
                    _Row(icon: const Text('💧', style: TextStyle(fontSize: 18, height: 1)), label: '판매이익', value: '+${won(total)}', color: AppColors.green),
                    const SizedBox(height: 10),
                    _Row(icon: const Text('⭐', style: TextStyle(fontSize: 18, height: 1)), label: 'Point', value: '+${points}P', color: const Color(0xFF2057B5)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: _SellButton(loading: _busy, onTap: chosen.isEmpty ? null : () => _sell(chosen, total)),
            ),
          ]),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({bool selected = false}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: selected ? AppColors.green : const Color(0xFFE3ECD9), width: selected ? 2 : 1.2),
      boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .10), blurRadius: 10, offset: const Offset(0, 3))],
    );

/// 시안의 작물 한 줄: 큰 작물 그림 · 이름 · 무게 · 오른쪽 초록 금액. 고른 작물은 초록 테두리와 체크 표시.
class _LotRow extends StatelessWidget {
  const _LotRow({required this.lot, required this.amount, required this.selected, required this.onTap});
  final Lot lot;

  /// 현재 시세로 계산한 판매 금액 (시세가 없으면 null)
  final int? amount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = cropOf(lot.cropCode);
    final kg = lot.kg.toStringAsFixed(lot.kg == lot.kg.roundToDouble() ? 0 : 1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: _cardDecoration(selected: selected),
        child: Row(children: [
          SizedBox(width: 62, height: 62, child: CropArt(code: c.code, size: 62)),
          const SizedBox(width: 14),
          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Color(0xFF111111))),
          const SizedBox(width: 14),
          Text('${kg}kg', style: const TextStyle(fontSize: 14, color: Color(0xFF55655A), fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(amount == null ? '시세 없음' : won(amount!), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.greenDark)),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: selected
                ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 24)
                : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFC9D4CC), size: 24),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.color, this.bold = false});
  final Widget icon;
  final String label, value;
  final Color? color;
  final bool bold;
  @override
  Widget build(BuildContext context) => Row(children: [
        icon,
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF2B3A30), fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: bold ? 18 : 16, fontWeight: FontWeight.w900, color: color ?? const Color(0xFF111111))),
      ]);
}

/// 시안의 큰 "판매하기" 버튼: 진한 초록 그라데이션 알약
class _SellButton extends StatelessWidget {
  const _SellButton({required this.onTap, required this.loading});
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(29),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3AA652), Color(0xFF14702F)]),
            boxShadow: [BoxShadow(color: const Color(0xFF14702F).withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
              : const Text('판매하기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ),
    );
  }
}
