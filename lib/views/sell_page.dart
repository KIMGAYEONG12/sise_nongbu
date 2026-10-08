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

/// 판매할 작물 선택 (시안): 창고의 수확물을 골라 현재 시세로 한꺼번에 출하한다.
/// 아래 "예상 수익" 카드에 총 판매금액 · 게임머니 · Point 가 나온다.
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});
  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> {
  final _picked = <String>{};
  bool _busy = false;

  Future<void> _sell(List<Lot> chosen) async {
    setState(() => _busy = true);
    final vm = ref.read(farmViewModelProvider);
    final soldNames = <String>[];
    String? error;
    for (final l in chosen) {
      try {
        await vm.sell(l);
        soldNames.add(cropOf(l.cropCode).name);
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
      showMsg(context, soldMessage(soldNames));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = ref.watch(lotsProvider).valueOrNull ?? const <Lot>[];
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
                  Builder(builder: (_) {
                    final c = cropOf(l.cropCode);
                    final p = prices[l.cropCode];
                    final on = _picked.contains(l.id);
                    return SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      onTap: p == null ? null : () => setState(() => on ? _picked.remove(l.id) : _picked.add(l.id)),
                      child: Row(children: [
                        SizedBox(width: 52, height: 52, child: CropArt(code: c.code, size: 52)),
                        const SizedBox(width: 12),
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
                        const SizedBox(width: 12),
                        Text('${l.kg.toStringAsFixed(l.kg == l.kg.roundToDouble() ? 0 : 1)}kg', style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                        const Spacer(),
                        Text(p == null ? '시세 없음' : won(amountOf(l)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: AppColors.greenDark)),
                        SizedBox(
                          width: 26,
                          child: on ? const Icon(Icons.check_rounded, color: AppColors.green, size: 22) : null,
                        ),
                      ]),
                    );
                  }),
                const SizedBox(height: 4),
                // 시안: 예상 수익 카드 (총 판매금액 / 게임머니 / Point)
                SoftCard(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('예상 수익', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: AppColors.ink)),
                    const SizedBox(height: 10),
                    _Row(icon: const Text('🌿', style: TextStyle(fontSize: 15, height: 1)), label: '총 판매금액', value: won(total), bold: true),
                    const Divider(height: 18, color: AppColors.line),
                    _Row(icon: const Text('💧', style: TextStyle(fontSize: 15, height: 1)), label: '게임머니', value: '+${won(total)}', color: AppColors.green),
                    const SizedBox(height: 8),
                    _Row(icon: const Text('⭐', style: TextStyle(fontSize: 15, height: 1)), label: 'Point', value: '+${points}P', color: AppColors.greenDark),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GreenButton(label: '판매하기', loading: _busy, onPressed: chosen.isEmpty ? null : () => _sell(chosen)),
            ),
          ]),
        ),
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
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF3D4A40), fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: bold ? 17 : 14.5, fontWeight: FontWeight.w900, color: color ?? AppColors.ink)),
      ]);
}
