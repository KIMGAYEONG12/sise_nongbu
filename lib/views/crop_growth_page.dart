import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'farm_actions.dart';
import 'mission_page.dart';
import '../core/korean.dart';

/// 작물 성장 화면 (시안 '작물 성장 화면'): 선택한 밭의 진행률, 잔디 위 밭 6칸, 물주기·영양제·성장촉진제·미션, 오늘의 미션
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
      showMsg(context, '${withJosa(itemName(key), '이', '가')} 없어요. 상점에서 구매해 주세요');
      return;
    }
    await runGuarded(context, () => ref.read(farmViewModelProvider).useItem(p, key), ok: '${withJosa(itemName(key), '을', '를')} 사용했어요');
  }

  /// 잘못 심은 작물을 뽑고 바로 다시 심기
  Future<void> _replant(Plot p) async {
    if (p.isEmpty) return;
    final c = cropOf(p.cropCode!);
    final now = DateTime.now();
    final planted = (p.readyAt != null && p.growMs > 0) ? p.readyAt!.subtract(Duration(milliseconds: p.growMs)) : null;
    final mins = uprootRefundWindow.inMinutes;
    final free = planted != null && now.difference(planted) <= uprootRefundWindow;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${withJosa(c.name, '을', '를')} 뽑고 다시 심을까요?'),
        content: Text(free
            ? '심은 지 $mins분이 안 지나서 파종비(또는 씨앗)를 돌려받아요.\n뽑은 뒤 바로 심을 작물을 고를 수 있어요.'
            : '심은 지 $mins분이 지나서 파종비는 돌려받을 수 없어요.\n자라던 ${c.name}도 사라져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('뽑고 다시 심기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final msg = await ref.read(farmViewModelProvider).uproot(p);
      if (!mounted) return;
      showMsg(context, msg);
      await showPlantSheet(context, ref, Plot(p.index, null, null));
    } catch (e) {
      if (mounted) showMsg(context, errMsg(e));
    }
  }

  /// 다 자란 작물을 수확하고, 수확 완료 화면을 닫으면 그 자리에 바로 심을 작물을 고른다
  Future<void> _harvestThenPlant(Plot p) async {
    await harvestPlot(context, ref, p);
    if (!mounted) return;
    final after = ref.read(plotsProvider).valueOrNull ?? const <Plot>[];
    for (final q in after) {
      if (q.index == p.index && q.isEmpty) {
        setState(() => _sel = q.index);
        await showPlantSheet(context, ref, q);
        return;
      }
    }
  }

  /// '작물 심기' 버튼: 선택한 빈 밭(없으면 첫 빈 밭)에 심는다.
  /// 빈 밭이 없으면 다 자란 작물을 수확하고 그 자리에 심을지 묻는다.
  Future<void> _plantNow(List<Plot> list, DateTime now) async {
    Plot? target;
    for (final p in list) {
      if (p.isEmpty && (target == null || p.index == _sel)) target = p;
    }
    final empty = target;
    if (empty != null) {
      setState(() => _sel = empty.index);
      await showPlantSheet(context, ref, empty);
      return;
    }
    Plot? ready;
    for (final p in list) {
      if (p.isReady(now) && (ready == null || p.index == _sel)) ready = p;
    }
    final done = ready;
    if (done == null) {
      showMsg(context, '빈 밭이 없어요. 작물을 고른 뒤 \'다시 심기\'를 누르거나 상점에서 밭을 넓혀 주세요');
      return;
    }
    final name = cropOf(done.cropCode!).name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('빈 밭이 없어요'),
        content: Text('다 자란 ${withJosa(name, '을', '를')} 수확하고 그 자리에 새 작물을 심을까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('수확하고 심기')),
        ],
      ),
    );
    if (ok == true && mounted) await _harvestThenPlant(done);
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
            // 시안: '<'  🥬 작물 성장  (왼쪽 정렬, 오른쪽은 비움)
            PageHeader(
              title: '작물 성장',
              center: false,
              leading: Text(spec?.emoji ?? '🌿', style: const TextStyle(fontSize: 24, height: 1)),
              onBack: () => Navigator.of(context).pop(),
            ),
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
                      : _GrowthHeader(spec: spec, plot: sel!, now: now, onReplant: () => _replant(sel!)),
                ),
                const SizedBox(height: 12),
                plots.when(
                  loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SoftCard(child: Text('밭을 불러오지 못했어요\n${errMsg(e)}')),
                  data: (all) => _GrowthBoard(
                    plots: all,
                    now: now,
                    selected: sel?.index,
                    onTap: (p) {
                      if (p.isEmpty) {
                        showPlantSheet(context, ref, p);
                      } else if (p.isReady(now)) {
                        _harvestThenPlant(p);
                      } else {
                        setState(() => _sel = p.index);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 직접 심기: 빈 밭에 바로 심거나, 빈 밭이 없으면 다 자란 작물을 수확하고 심는다
                GreenButton(
                  label: list.any((p) => p.isEmpty) ? '작물 심기' : '수확하고 심기',
                  icon: const Text('🌱', style: TextStyle(fontSize: 18)),
                  onPressed: () => _plantNow(list, now),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionButton(emoji: '💧', label: '물주기', tint: const Color(0xFFE2F1FC), count: user.item(itemWater), onTap: () => _use(sel, itemWater)),
                  const SizedBox(width: 8),
                  _ActionButton(emoji: '🌿', label: '영양제', tint: const Color(0xFFE6F4DD), count: user.item(itemFertilizer), onTap: () => _use(sel, itemFertilizer)),
                  const SizedBox(width: 8),
                  _ActionButton(emoji: '🧴', label: '성장촉진제', tint: const Color(0xFFFFEEDD), count: user.item(itemBooster), onTap: () => _use(sel, itemBooster)),
                  const SizedBox(width: 8),
                  _ActionButton(
                    emoji: '📋',
                    label: '미션',
                    tint: const Color(0xFFFFF4D2),
                    badge: '$dailyDone/${dailyMissions.length}',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  ),
                ]),
                const SizedBox(height: 12),
                SoftCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('🌰', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text('오늘의 미션 $dailyDone/${dailyMissions.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    if (nextMission == null)
                      const Text('오늘의 미션을 모두 완료했어요! 🎉', style: TextStyle(fontSize: 13, color: AppColors.greenDark))
                    else
                      Row(children: [
                        Expanded(child: Text('${nextMission.title} (${periodCount(user.daily, tag, nextMission.key)}/${nextMission.target})', style: const TextStyle(fontSize: 13))),
                        Text('+${nextMission.points}P', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF39A1E))),
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
  const _GrowthHeader({required this.spec, required this.plot, required this.now, this.onReplant});
  final CropSpec spec;
  final Plot plot;
  final DateTime now;
  final VoidCallback? onReplant;

  @override
  Widget build(BuildContext context) {
    final ready = plot.isReady(now);
    final p = plot.progress(now);
    return Row(children: [
      // 시안처럼 동그라미 없이 큰 작물 그림 (이모지는 벡터라 확대해도 선명하다)
      SizedBox(
        width: 64,
        height: 64,
        child: Stack(alignment: Alignment.center, children: [
          Positioned(bottom: 4, child: Container(width: 44, height: 9, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)))),
          Text(spec.emoji, style: const TextStyle(fontSize: 50, height: 1)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(spec.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: ThinBar(value: p, height: 14, color: const Color(0xFF3F9E3A), track: const Color(0xFFE3EBDD))),
            const SizedBox(width: 10),
            Text('${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink)),
          ]),
          const SizedBox(height: 4),
          Text('수확 예상 : ${plot.readyAt == null ? '-' : leftText(plot.readyAt!, now)}${plot.bonus > 0 ? ' · 수확량 +${(plot.bonus * 100).round()}%' : ''}',
              style: TextStyle(fontSize: 12, color: ready ? AppColors.greenDark : const Color(0xFF55655A), fontWeight: ready ? FontWeight.w800 : FontWeight.w600)),
          if (!ready && onReplant != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReplant,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.greenDark,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('다시 심기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.emoji, required this.label, required this.onTap, this.count, this.badge, this.tint = Colors.white});
  final String emoji, label;
  final Color tint;
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: empty ? .6 : 1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Opacity(opacity: empty ? .55 : 1, child: Text(emoji, style: const TextStyle(fontSize: 32, height: 1.1))),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
            Text(count != null ? '보유 $count' : (badge ?? ''), style: TextStyle(fontSize: 10, color: empty ? AppColors.sub : AppColors.greenDark, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// 시안의 작물 성장 화면 밭: 잔디 판 위에 흙 칸 3열, 칸마다 큰 작물.
/// 빈 칸은 +(누르면 심기), 자라는 칸은 성장 단계 그림과 얇은 진행 막대, 다 자란 칸은 ✨(누르면 수확).
/// 모두 코드(벡터)로 그려서 어떤 화면에서도 깨지지 않는다.
class _GrowthBoard extends StatelessWidget {
  const _GrowthBoard({required this.plots, required this.now, required this.onTap, this.selected});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTap;
  final int? selected;

  static const _cols = 3;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA9DB6E), Color(0xFF78BC4A)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: CustomPaint(
          painter: const _GrassPainter(),
          child: LayoutBuilder(builder: (context, box) {
            final tile = ((box.maxWidth - _gap * (_cols - 1)) / _cols).floorToDouble();
            final tileH = (tile * .92).floorToDouble();
            final rows = <Widget>[];
            for (var r = 0; r * _cols < plots.length; r++) {
              final cells = <Widget>[];
              for (var c = 0; c < _cols; c++) {
                final i = r * _cols + c;
                if (c > 0) cells.add(const SizedBox(width: _gap));
                cells.add(SizedBox(
                  width: tile,
                  height: tileH,
                  child: i < plots.length ? _SoilTile(plot: plots[i], now: now, selected: selected == plots[i].index, onTap: () => onTap(plots[i])) : null,
                ));
              }
              if (r > 0) rows.add(const SizedBox(height: _gap));
              rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
            }
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: rows));
          }),
        ),
      );
}

/// 잔디 판 위의 작은 풀잎 무늬
class _GrassPainter extends CustomPainter {
  const _GrassPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x334C8F2C)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var y = 4.0; y < size.height; y += 14) {
      for (var x = ((y ~/ 14).isEven ? 3.0 : 10.0); x < size.width; x += 15) {
        canvas.drawLine(Offset(x, y + 4), Offset(x - 2, y), p);
        canvas.drawLine(Offset(x + 2, y + 4), Offset(x + 4, y + 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(_GrassPainter old) => false;
}

/// 흙 칸 하나 (밭고랑 무늬가 있는 갈색 흙 + 큰 작물)
class _SoilTile extends StatelessWidget {
  const _SoilTile({required this.plot, required this.now, required this.selected, required this.onTap});
  final Plot plot;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = box.maxHeight;
        final spec = plot.isEmpty ? null : cropOf(plot.cropCode!);
        final ready = plot.isReady(now);
        final progress = plot.progress(now);
        final Widget crop;
        if (spec == null) {
          crop = Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: .85), size: size * .36),
            Text('심기', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 12, fontWeight: FontWeight.w800)),
          ]);
        } else {
          final emoji = ready || progress >= .67 ? spec.emoji : (progress < .34 ? '🌱' : '🌿');
          final scale = ready ? .66 : (progress < .34 ? .42 : (progress < .67 ? .52 : .6));
          crop = Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            // 작물 아래 그림자
            Positioned(
              bottom: size * .14,
              child: Container(width: size * scale * .8, height: size * .1, decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(size))),
            ),
            Padding(padding: EdgeInsets.only(bottom: size * .06), child: Text(emoji, style: TextStyle(fontSize: size * scale, height: 1))),
          ]);
        }
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB27744), Color(0xFF8D5A31)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.white : (ready ? const Color(0xFFFFE08A) : const Color(0xFF6E4524)),
                width: selected || ready ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (ready) const BoxShadow(color: Color(0x88FFD54F), blurRadius: 10),
                const BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(alignment: Alignment.center, children: [
                const Positioned.fill(child: CustomPaint(painter: _FurrowPainter())),
                crop,
                if (ready) Positioned(top: 4, right: 5, child: Text('✨', style: TextStyle(fontSize: size * .2, height: 1))),
                if (spec != null && !ready)
                  Positioned(left: 10, right: 10, bottom: 6, child: ThinBar(value: progress, height: 4, color: const Color(0xFFB5E36B), track: Colors.black26)),
              ]),
            ),
          ),
        );
      });
}

/// 흙 칸의 밭고랑(가로 줄) 무늬
class _FurrowPainter extends CustomPainter {
  const _FurrowPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final light = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(size.width * .12, y), Offset(size.width * .88, y), dark);
      canvas.drawLine(Offset(size.width * .14, y - 2.5), Offset(size.width * .86, y - 2.5), light);
    }
  }

  @override
  bool shouldRepaint(_FurrowPainter old) => false;
}
