import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'farm_actions.dart';
import 'mission_page.dart';
import '../core/korean.dart';
import '../widgets/crop_art.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SharedPreferences prefs;
      try {
        prefs = ref.read(prefsProvider);
      } catch (_) {
        return; // 저장소가 없는 테스트 화면에서는 안내 창을 띄우지 않는다
      }
      showGuideOnce(context, prefs, 'growth',
          icon: Icons.agriculture_rounded,
          title: '농부님, 함께 작물을 키워 볼까요?',
          lines: const [
            '빈 밭(+)을 눌러 원하시는 작물을 심어 주세요.',
            '물주기·영양제·성장촉진제는 횟수 제한 없이 마음껏 쓰실 수 있어요.',
            '다 자라면 밭을 눌러 수확하시고, 창고에서 판매하실 수 있어요.',
          ]);
    });
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
    // 물주기·영양제·성장촉진제는 모든 사용자가 무제한으로 쓴다 (가진 개수와 상관없이, 서버도 개수를 줄이지 않는다)
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

  /// 바로 심기 (작물이 없을 때 위 카드를 누르면): 선택한 빈 밭(없으면 첫 빈 밭)에 심는다.
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

    // 뒤로 가기(휴대폰 버튼·화면의 <)를 누르면 "뒤로 가겠습니까?" 창을 먼저 띄운다
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmBack() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            // 시안: '<'  🥬 작물 성장  (왼쪽 정렬, 오른쪽은 비움)
            PageHeader(
              title: '작물 성장',
              center: false,
              leading: spec == null ? const CropArt(code: 'TOMATO', size: 30) : CropArt(code: spec.code, size: 30),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                SoftCard(
                  // 작물이 없을 때는 카드를 눌러 바로 심을 수 있다
                  onTap: spec == null ? () => _plantNow(list, now) : null,
                  child: spec == null
                      // 빈 밭 안내: 작은 트랙터 아이콘이 자전거처럼 보여서 "작물 대기 중" 카드로 바꿨다
                      ? const _WaitingCard()
                      : _GrowthHeader(spec: spec, plot: sel!, now: now, onReplant: () => _replant(sel)),
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
                // 시안: 물주기(파랑) · 영양제(초록) · 성장촉진제(연베이지) · 미션(노랑). 보유 수는 오른쪽 위 작은 숫자
                Row(children: [
                  _ActionButton(icon: Icons.water_drop_rounded, iconColor: const Color(0xFF4DB3F0), label: '물주기', tint: const Color(0xFFE3F1FB), count: user.item(itemWater), onTap: () => _use(sel, itemWater)),
                  const SizedBox(width: 8),
                  _ActionButton(icon: Icons.spa_rounded, iconColor: const Color(0xFF5BAA3C), label: '영양제', tint: const Color(0xFFE7F4E0), count: user.item(itemFertilizer), onTap: () => _use(sel, itemFertilizer)),
                  const SizedBox(width: 8),
                  _ActionButton(icon: Icons.bolt_rounded, iconColor: const Color(0xFFF2A81D), label: '성장촉진제', tint: const Color(0xFFF4EEE8), count: user.item(itemBooster), onTap: () => _use(sel, itemBooster)),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.assignment_rounded,
                    iconColor: const Color(0xFFC9852E),
                    label: '미션',
                    tint: const Color(0xFFFFF1CC),
                    badge: '$dailyDone/${dailyMissions.length}',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  ),
                ]),
                const SizedBox(height: 12),
                SoftCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MissionPage())),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.flag_rounded, size: 20, color: Color(0xFFF39A1E)),
                      const SizedBox(width: 6),
                      Text('오늘의 미션 $dailyDone/${dailyMissions.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    if (nextMission == null)
                      const Text('오늘의 미션을 모두 완료했어요! 🎉', style: TextStyle(fontSize: 13, color: AppColors.greenDark))
                    else
                      Row(children: [
                        Expanded(child: Text('${nextMission.title} (${periodCount(user.daily, tag, nextMission.key)}/${nextMission.target})', style: const TextStyle(fontSize: 13))),
                        Text('+${cash(nextMission.points)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF39A1E))),
                      ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ),
    );
  }

  Future<bool> _confirmBack() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('뒤로 가겠습니까?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('작물은 그대로 자라고 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('뒤로 가기', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    return ok == true;
  }
}

/// 고른 밭에 작물이 없을 때 위 카드: 흙 위 모래시계 그림 + "작물 대기 중" + 초록 "심기" 버튼 (카드를 누르면 바로 심기)
class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  static const _brown = Color(0xFF9A6B3F);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          // 예쁜 토마토 그림 (씨앗·모래시계 없이)
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF6E6), Color(0xFFFBE3C2)]),
              border: Border.all(color: const Color(0xFFF1D3A6)),
            ),
            child: const CropArt(code: 'TOMATO', size: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('작물 대기 중', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF5A3B1F))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(8)),
                  child: const Text('빈 밭', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _brown)),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('맛있는 작물을 기다리고 있어요.\n눌러서 작물을 심어 보세요!', style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.sub)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 2),
              Text('심기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
        ]),
      );
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
      // 시안처럼 동그라미 없이 큰 작물 그림
      CropArt(code: spec.code, size: 66),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(spec.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink))),
            // 다시 심기: 작게 이름 오른쪽에 (다 자라면 숨김)
            if (!ready && onReplant != null)
              InkWell(
                onTap: onReplant,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.greenDark),
                    SizedBox(width: 2),
                    Text('다시 심기', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: ThinBar(value: p, height: 14, color: const Color(0xFF34A34A), track: const Color(0xFFE4EAE6))),
            const SizedBox(width: 10),
            Text('${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink)),
          ]),
          const SizedBox(height: 5),
          Text('수확 예상일 : ${plot.readyAt == null ? '-' : leftText(plot.readyAt!, now)}${plot.bonus > 0 ? ' · 수확량 +${(plot.bonus * 100).round()}%' : ''}',
              style: TextStyle(fontSize: 12, color: ready ? AppColors.greenDark : const Color(0xFF55655A), fontWeight: ready ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

/// 시안의 아이템 버튼: 연한 색 카드에 큰 아이콘과 이름. 보유 수는 오른쪽 위 작은 동그라미.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.iconColor, required this.label, required this.onTap, this.count, this.badge, this.tint = Colors.white});
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color tint;
  final int? count;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 물주기·영양제·성장촉진제는 상점에서 사지 않아도 모든 사용자가 무제한으로 쓴다.
    // 그래서 가진 개수(count)와 상관없이 흐리게 하지 않고, 파란 '무제한' 표시를 단다.
    final unlimited = count != null;
    final mark = unlimited ? '∞ 무제한' : badge;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: .9,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 38, color: iconColor),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ]),
              ),
            ),
            if (mark != null)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: unlimited ? const Color(0xFF2F86D6) : AppColors.greenDark, borderRadius: BorderRadius.circular(10)),
                  child: Text(mark, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 시안의 작물 성장 밭: 꽃이 핀 잔디 테두리 → 밝은 흙길 → 진한 흙 칸 3열, 칸마다 큰 작물.
/// 빈 칸은 흐린 +(누르면 심기), 자라는 칸은 성장 단계 그림, 다 자란 칸은 ✨(누르면 수확 후 바로 심기).
/// 그림 파일 없이 모두 코드(벡터)로 그려서 어떤 화면에서도 깨지지 않는다.
class _GrowthBoard extends StatefulWidget {
  const _GrowthBoard({required this.plots, required this.now, required this.onTap, this.selected});
  final List<Plot> plots;
  final DateTime now;
  final ValueChanged<Plot> onTap;
  final int? selected;

  static const _cols = 3;
  static const _gap = 12.0;

  @override
  State<_GrowthBoard> createState() => _GrowthBoardState();
}

class _GrowthBoardState extends State<_GrowthBoard> with SingleTickerProviderStateMixin {
  /// 작물이 한 번 살랑이는 시간. 컨트롤러 하나로 모든 밭의 작물을 흔들고, 화면이 보이지 않으면 저절로 멈춘다.
  late final AnimationController _sway = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plots = widget.plots, now = widget.now, onTap = widget.onTap, selected = widget.selected;
    const cols = _GrowthBoard._cols, gap = _GrowthBoard._gap;
    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: const _MeadowPainter(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              // 밝은 흙길(밭 사이 길)
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE2A866), Color(0xFFD69552)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC07E3E), width: 1.5),
                ),
                child: CustomPaint(
                  painter: const _PathDotsPainter(),
                  child: LayoutBuilder(builder: (context, box) {
                    final tile = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
                    final tileH = (tile * .9).floorToDouble();
                    final rows = <Widget>[];
                    for (var r = 0; r * cols < plots.length; r++) {
                      final cells = <Widget>[];
                      for (var c = 0; c < cols; c++) {
                        final i = r * cols + c;
                        if (c > 0) cells.add(const SizedBox(width: gap));
                        cells.add(SizedBox(
                          width: tile,
                          height: tileH,
                          child: i < plots.length ? _SoilTile(plot: plots[i], now: now, selected: selected == plots[i].index, sway: _sway, onTap: () => onTap(plots[i])) : null,
                        ));
                      }
                      if (r > 0) rows.add(const SizedBox(height: gap));
                      rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
                    }
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: rows));
                  }),
                ),
              ),
            ),
          ),
        ),
      );
  }
}

/// 밭 둘레의 잔디: 초록 바탕에 풀잎과 작은 꽃
class _MeadowPainter extends CustomPainter {
  const _MeadowPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8FCB5A), Color(0xFF6DB143)]).createShader(rect));
    final blade = Paint()
      ..color = const Color(0x553C7F25)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final light = Paint()
      ..color = const Color(0x55D8F5A8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    var k = 0;
    for (var y = 3.0; y < size.height; y += 9) {
      for (var x = (k.isEven ? 2.0 : 7.0); x < size.width; x += 11) {
        canvas.drawLine(Offset(x, y + 4), Offset(x - 2, y - 1), blade);
        canvas.drawLine(Offset(x + 3, y + 4), Offset(x + 5, y), light);
      }
      k++;
    }
    // 작은 꽃 (테두리 쪽에만)
    final colors = [const Color(0xFFFFF3B0), Colors.white, const Color(0xFFFFC8D8)];
    var n = 0;
    for (var x = 10.0; x < size.width; x += 37) {
      for (final y in [6.0, size.height - 7]) {
        canvas.drawCircle(Offset(x + (n % 3) * 4, y), 2.2, Paint()..color = colors[n % colors.length]);
        n++;
      }
    }
    for (var y = 24.0; y < size.height - 20; y += 41) {
      for (final x in [6.0, size.width - 7]) {
        canvas.drawCircle(Offset(x, y + (n % 3) * 3), 2.2, Paint()..color = colors[n % colors.length]);
        n++;
      }
    }
  }

  @override
  bool shouldRepaint(_MeadowPainter old) => false;
}

/// 밭 사이 흙길의 하얀 점 무늬
class _PathDotsPainter extends CustomPainter {
  const _PathDotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x66FFF6E6);
    var k = 0;
    for (var y = 4.0; y < size.height; y += 13) {
      for (var x = (k.isEven ? 4.0 : 10.0); x < size.width; x += 13) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
      k++;
    }
  }

  @override
  bool shouldRepaint(_PathDotsPainter old) => false;
}

/// 진한 흙 칸 하나 + 큰 작물
class _SoilTile extends StatelessWidget {
  const _SoilTile({required this.plot, required this.now, required this.selected, required this.onTap, required this.sway});
  final Plot plot;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  /// 0~1을 되풀이하는 흔들림 시간 (밭마다 시작 위치를 달리해서 제각각 살랑인다)
  final Animation<double> sway;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = box.maxHeight;
        final spec = plot.isEmpty ? null : cropOf(plot.cropCode!);
        final ready = plot.isReady(now);
        final progress = plot.progress(now);
        final Widget crop;
        if (spec == null) {
          crop = Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: .55), size: size * .4);
        } else {
          // 성장 단계: 새싹 → 어린 작물 → 다 자란 작물
          final art = CropArt(code: spec.code, size: size * .86, stage: ready ? 1.0 : progress);
          crop = SwayingCrop(animation: sway, phase: plot.index, stage: ready ? 1.0 : progress, child: art);
        }
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8E5631), Color(0xFF6F3F1F)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? Colors.white : const Color(0xFF5E3519), width: selected ? 2.5 : 1.2),
              boxShadow: [
                if (ready) const BoxShadow(color: Color(0x99FFE07A), blurRadius: 10),
                const BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1.5)),
              ],
            ),
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              const Positioned.fill(child: CustomPaint(painter: _SoilPainter())),
              crop,
              if (ready) Positioned(top: -4, right: -2, child: Icon(Icons.auto_awesome_rounded, size: size * .24, color: const Color(0xFFFFD34E))),
            ]),
          ),
        );
      });
}

/// 바람에 살랑이는 작물. 밑동(아래 가운데)을 기준으로 좌우로 아주 조금 기울고 숨 쉬듯 살짝 커졌다 작아진다.
/// 새싹은 더 작게, 다 자란 작물은 조금 더 크게 흔들려서 자란 정도가 느껴진다.
class SwayingCrop extends StatelessWidget {
  const SwayingCrop({super.key, required this.animation, required this.phase, required this.stage, required this.child});
  final Animation<double> animation;

  /// 밭 번호. 밭마다 흔들리는 박자가 다르다.
  final int phase;

  /// 성장 진행률 0.0~1.0
  final double stage;
  final Widget child;

  /// 흔들림 기울기(라디안). 가장 크게 기울어도 약 3도라서 "살짝" 움직이는 정도다.
  static double angleAt(double t, int phase, double stage) {
    final amp = stage < .34 ? .022 : (stage < .67 ? .034 : .048);
    return math.sin((t + phase * .137) * math.pi * 2) * amp;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        // 작물 그림은 한 번만 그려 두고(RepaintBoundary) 위치·기울기만 바꾼다. 프레임마다 다시 그리면 글자(이모지)로 그린 작물이 깜빡이고 다른 그림이 사라진다.
        child: RepaintBoundary(child: child),
        builder: (_, kid) {
          final t = animation.value;
          final breathe = 1 + .012 * math.sin((t * 2 + phase * .21) * math.pi * 2);
          return Transform.scale(
            scale: breathe,
            alignment: Alignment.bottomCenter,
            child: Transform.rotate(angle: angleAt(t, phase, stage), alignment: Alignment.bottomCenter, child: kid),
          );
        },
      );
}

/// 흙 칸 안쪽의 부드러운 흙 알갱이 무늬
class _SoilPainter extends CustomPainter {
  const _SoilPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0x22000000);
    final light = Paint()..color = const Color(0x18FFE2C0);
    var k = 0;
    for (var y = 6.0; y < size.height - 3; y += 9) {
      for (var x = (k.isEven ? 6.0 : 11.0); x < size.width - 3; x += 10) {
        canvas.drawCircle(Offset(x, y), 1.3, dark);
        canvas.drawCircle(Offset(x + 2, y - 2), 1.0, light);
      }
      k++;
    }
  }

  @override
  bool shouldRepaint(_SoilPainter old) => false;
}
