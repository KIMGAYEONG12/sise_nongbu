import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'farm_actions.dart';
import 'price_detail_page.dart';

/// 작물 도감: 수확 횟수로 숙련도(5회가 최대)를 보여준다. 아직 심을 수 없는 작물은 "준비 중"으로 표시한다.
class EncyclopediaPage extends ConsumerStatefulWidget {
  const EncyclopediaPage({super.key});
  @override
  ConsumerState<EncyclopediaPage> createState() => _EncyclopediaPageState();
}

class _EncyclopediaPageState extends ConsumerState<EncyclopediaPage> {
  static const _tabs = ['전체', '채소', '과일', '특수'];
  static const _maxMastery = 5;
  int _tab = 0;

  void _detail(CropSpec c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Consumer(builder: (_, ref2, __) {
        final user = ref2.watch(userDataProvider);
        final price = ref2.watch(marketViewModelProvider).valueOrNull?[c.code];
        final dur = applyGreenhouses(growDuration(c, ref2.watch(speedProvider)), user.greenhouses);
        final n = user.stat('crop_${c.code}');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                EmojiBadge(c.emoji, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('${c.kind} · 수확 $n회', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              KoText(c.desc, style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(children: [
                  _row('파종비', won(c.seedCost)),
                  _row('1회 수확량', '${c.yieldKg.toStringAsFixed(0)}kg'),
                  _row('성장 시간', durText(dur)),
                  _row('현재 시세', price == null ? '확인 중' : '${commaNum(price.pricePerKg)}원/kg'),
                ]),
              ),
              const SizedBox(height: 12),
              GreenButton(
                label: '시세 자세히 보기',
                onPressed: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PriceDetailPage(cropCode: c.code)));
                },
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Text(k, style: const TextStyle(color: AppColors.sub, fontSize: 13)), const Spacer(), Text(v, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final shown = crops.where((c) => _tab == 0 || c.kind == _tabs[_tab]).toList();
    final showLocked = _tab == 0 || _tab == 3;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '작물 도감', onBack: () => Navigator.of(context).pop()),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PillTabs(labels: _tabs, index: _tab, onChanged: (v) => setState(() => _tab = v))),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  for (final c in shown)
                    Builder(builder: (_) {
                      final n = user.stat('crop_${c.code}');
                      final m = n > _maxMastery ? _maxMastery : n;
                      return SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        onTap: () => _detail(c),
                        child: Row(children: [
                          EmojiBadge(c.emoji, size: 44),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                              Text(n >= _maxMastery ? '마스터 ⭐' : '$m/$_maxMastery', style: const TextStyle(fontSize: 11, color: AppColors.sub, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              ThinBar(value: m / _maxMastery, height: 5),
                            ]),
                          ),
                        ]),
                      );
                    }),
                  if (showLocked)
                    for (final l in lockedCrops)
                      Opacity(
                        opacity: .6,
                        child: SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          onTap: () => showMsg(context, '${l.$1}은(는) 아직 준비 중이에요'),
                          child: Row(children: [
                            const EmojiBadge('🔒', size: 44, color: Color(0xFFE3E7E0)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const Text('준비 중', style: TextStyle(fontSize: 11, color: AppColors.sub)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
