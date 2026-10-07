import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/farm_scene.dart';
import 'farm_actions.dart';
import 'mission_page.dart';

/// 작물 성장 화면: 선택한 밭의 진행률, 전체 밭, 물주기·영양제·성장촉진제, 오늘의 미션
class CropGrowthPage extends ConsumerStatefulWidget {
  const CropGrowthPage({super.key, this.initialPlot});
  final int? initialPlot;
  @override
  ConsumerState<CropGrowthPage> createState() => _CropGrowthPageState();
}

class _CropGrowthPageState extends ConsumerState<CropGrowthPage> {
  int? _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.initialPlot;
  }

  Plot? _selected(List<Plot> list) {
    if (list.isEmpty) return null;
    if (_sel != null) {
      for (final p in list) {
        if (p.index == _sel) return p;
      }
    }
    for (final p in list) {
      if (!p.isEmpty) return p; // 선택이 없으면 처음으로 작물이 있는 밭
    }
    return null;
  }

  Future<void> _use(Plot? p, String key) async {
    if (p == null || p.isEmpty) {
      showMsg(context, '먼저 작물이 심어진 밭을 선택해 주세요');
      return;
    }
    final have = ref.read(userDataProvider).item(key);
    if (have <= 0) {
      showMsg(context, '${itemName(key)}이(가) 없어요. 상점에서 구매해 주세요');
      return;
    }
    await runGuarded(context, () => ref.read(farmViewModelProvider).useItem(p, key), ok: '${itemName(key)}을(를) 사용했어요');
  }

  @override
  Widget build(BuildContext context) {
    final plots = ref.watch(plotsProvider);
    final user = ref.watch(userDataProvider);
    final now = ref.watch(tickProvider).valueOrNull ?? DateTime.now();
    final list = plots.valueOrNull ?? const <Plot>[];
    final sel = _selected(list);
    final spec = (sel == null || sel.isEmpty) ? null : cropOf(sel.cropCode!);
    final tag = dayTag(now);
    final dailyDone = dailyMissions.where((m) => periodCount(user.daily, tag, m.key) >= m.target).length;
    MissionDef? nextMission;
    for (final m in dailyMissions) {
      if (periodCount(user.daily, tag, m.key) < m.target) {
        nextMission = m;
        break;
      }
    }

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '작물 관리', leading: const Text('🌿', style: TextStyle(fontSize: 22)), onBack: () => Navigator.of(context).pop(), trailing: Padding(padding: const EdgeInsets.only(left: 8), child: MoneyPill(money: user.money))),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                SoftCard(
                  child: spec == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Text('🌱', style: TextStyle(fontSize: 30)),
                            SizedBox(width: 10),
                            Expanded(child: Text('심어진 작물이 없어요.\n아래 빈 밭을 눌러 작물을 심어보세요!', style: TextStyle(height: 1.4))),
                          ]),
                        )
                      : _GrowthHeader(spec: spec, plot: sel!, now: now),
                ),
                const SizedBox(height: 12),
                plots.when(
                  loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SoftCard(child: Text('밭을 불러오지 못했어요\n${errMsg(e)}')),
                  data: (all) => _Board(
                    plots: all,
                    now: now,
                    selected: sel?.index,
                    onTap: (p) {
                      if (p.isEmpty) {
                        showPlantSheet(context, ref, p);
                      } else if (p.isReady(now)) {
                        harvestPlot(context, ref, p);
                      } else {
                        setState(() => _sel = p.index);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionButton(emoji: '💧', label: '물주기', count: user.item(itemWater), onTap: () => _use(sel, itemWater)),
                  const SizedBox(width: 8),
                  _ActionButton(emoji: '🧪', label: '영양제', count: user.item(itemFertilizer), onTap: () => _use(sel, itemFertilizer)),
                  const SizedBox(width: 8),
                  _ActionButton(emoji: '⚡', label: '성장촉진제', count: user.item(itemBooster), onTap: () => _use(sel, itemBooster)),
                  const SizedBox(width: 8),
                  _ActionButton(
                    emoji: '📋',
                    label: '미션',
                    badge: '$dailyDone/${dailyMissions.length}',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  ),
                ]),
                const SizedBox(height: 12),
                SoftCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('🎯', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text('오늘의 미션 $dailyDone/${dailyMissions.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    if (nextMission == null)
                      const Text('오늘의 미션을 모두 완료했어요! 🎉', style: TextStyle(fontSize: 13, color: AppColors.greenDark))
                    else
                      Row(children: [
                        Expanded(child: Text('${nextMission.title} (${periodCount(user.daily, tag, nextMission.key)}/${nextMission.target})', style: const TextStyle(fontSize: 13))),
                        Text('+${nextMission.points}P', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.coin)),
                      ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GrowthHeader extends StatelessWidget {
  const _GrowthHeader({required this.spec, required this.plot, required this.now});
  final CropSpec spec;
  final Plot plot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ready = plot.isReady(now);
    final p = plot.progress(now);
    return Row(children: [
      EmojiBadge(spec.emoji, size: 54),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(spec.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: ThinBar(value: p, height: 9)),
            const SizedBox(width: 8),
            Text('${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text('수확 예상: ${plot.readyAt == null ? '-' : leftText(plot.readyAt!, now)}${plot.bonus > 0 ? ' · 수확량 +${(plot.bonus * 100).round()}%' : ''}',
              style: TextStyle(fontSize: 11, color: ready ? AppColors.greenDark : AppColors.sub, fontWeight: ready ? FontWeight.w800 : FontWeight.w500)),
        ]),
      ),
    ]);
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.plots, required this.now, required this.selected, required this.onTap});
  final List<Plot> plots;
  final DateTime now;
  final int? selected;
  final ValueChanged<Plot> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 8.0, inner = 10.0, cols = 3;
        final tile = ((box.maxWidth - inner * 2 - gap * (cols - 1)) / cols).clamp(48.0, 110.0).toDouble();
        return Container(
          padding: const EdgeInsets.all(inner),
          decoration: BoxDecoration(
            color: AppColors.soil,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.soilDark, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Wrap(spacing: gap, runSpacing: gap, children: [
            for (final p in plots) PlotTile(plot: p, now: now, size: tile, selected: selected == p.index, onTap: () => onTap(p)),
          ]),
        );
      });
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.emoji, required this.label, required this.onTap, this.count, this.badge});
  final String emoji, label;
  final int? count;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = count != null && count == 0;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: empty ? .55 : .95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Opacity(opacity: empty ? .5 : 1, child: Text(emoji, style: const TextStyle(fontSize: 26, height: 1.1))),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            Text(count != null ? '보유 $count' : (badge ?? ''), style: TextStyle(fontSize: 10, color: empty ? AppColors.sub : AppColors.greenDark, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
