import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'farm_page.dart';
import 'harvest_result_page.dart' show SunburstPainter;
import 'inventory_page.dart';
import 'market_page.dart';
import 'my_page.dart';
import 'shop_page.dart';

/// 하단 탭: 시세판 | 농장 | 창고 | 상점 | MY  (정보 화면은 농장·MY의 설정 아이콘에서 연다)
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    (Icons.show_chart_rounded, '시세판'),
    (Icons.grass_rounded, '농장'),
    (Icons.inventory_2_rounded, '창고'),
    (Icons.storefront_rounded, '상점'),
    (Icons.person_rounded, 'MY'),
  ];

  static int _levelOf(Map<String, dynamic>? u) => levelInfo((u?['exp'] as num?)?.toInt() ?? 0).level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(shellIndexProvider);
    // 레벨이 오르면 "Lv.1 → Lv.2" 축하 창을 띄운다 (처음 불러올 때는 띄우지 않는다)
    ref.listen<AsyncValue<Map<String, dynamic>>>(userProvider, (prev, next) {
      final before = prev?.valueOrNull, after = next.valueOrNull;
      if (before == null || after == null || before.isEmpty) return;
      final from = _levelOf(before), to = _levelOf(after);
      if (to > from) showLevelUpDialog(context, from, to, levelInfo((after['exp'] as num?)?.toInt() ?? 0));
    });
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          // 농장 탭은 시안처럼 하늘을 상태바 뒤까지 그리므로 위쪽 여백을 직접 처리한다
          top: i != 1,
          bottom: false,
          child: IndexedStack(index: i, children: const [MarketPage(), FarmPage(), InventoryPage(), ShopPage(), MyPage()]),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .12), blurRadius: 14, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              for (var t = 0; t < _tabs.length; t++)
                Expanded(
                  child: InkWell(
                    onTap: () => ref.read(shellIndexProvider.notifier).state = t,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        decoration: BoxDecoration(color: t == i ? AppColors.greenLight : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                        child: Icon(_tabs[t].$1, size: 24, color: t == i ? AppColors.greenDark : AppColors.sub),
                      ),
                      const SizedBox(height: 2),
                      Text(_tabs[t].$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t == i ? AppColors.greenDark : AppColors.sub)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 레벨 업 축하 창: 햇살이 퍼지는 큰 레벨 배지가 통통 튀며 나타나고, 색종이가 떨어지고, 경험치 막대가 차오른다.
Future<void> showLevelUpDialog(BuildContext context, int from, int to, LevelInfo now) => showDialog<void>(
      context: context,
      builder: (d) => _LevelUpDialog(from: from, to: to, now: now),
    );

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.from, required this.to, required this.now});
  final int from, to;
  final LevelInfo now;
  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) => t <= a ? 0 : (t >= b ? 1 : curve.transform((t - a) / (b - a)));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final pop = _seg(t, 0, .35, Curves.elasticOut);
          final bar = _seg(t, .35, .85);
          return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Container(
              margin: const EdgeInsets.only(top: 70),
              padding: const EdgeInsets.fromLTRB(22, 78, 22, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4C2), Color(0xFFFFFFFF), Color(0xFFEAF6DF)]),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: _seg(t, .15, .45), child: const Text('레벨 업!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.greenDark))),
                const SizedBox(height: 10),
                Opacity(
                  opacity: _seg(t, .25, .55),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _lvChip('Lv.${widget.from}', false),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded, color: AppColors.green, size: 28)),
                    _lvChip('Lv.${widget.to}', true),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  const Text('경험치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                  const Spacer(),
                  Text('${(widget.now.exp * bar).round()} / ${widget.now.need}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
                ]),
                const SizedBox(height: 6),
                ThinBar(value: widget.now.ratio * bar, height: 14, color: const Color(0xFF34A34A), track: const Color(0xFFE4EAE6)),
                const SizedBox(height: 14),
                Text('다음 레벨까지 경험치 ${widget.now.need - widget.now.exp} 남았어요!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                const SizedBox(height: 18),
                GreenButton(label: '계속하기', onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
            // 햇살 + 레벨 배지 (카드 위로 솟아오른다)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 170,
                height: 170,
                child: Stack(alignment: Alignment.center, children: [
                  Opacity(opacity: _seg(t, 0, .3), child: Transform.rotate(angle: t * 1.2, child: const CustomPaint(size: Size(170, 170), painter: SunburstPainter()))),
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFF7ED957), Color(0xFF2F8F3E)]),
                        border: Border.all(color: Colors.white, width: 5),
                        boxShadow: [BoxShadow(color: const Color(0xFF1F6B2E).withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('LV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                        Text('${widget.to}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            // 떨어지는 색종이
            for (var i = 0; i < 14; i++)
              Builder(builder: (_) {
                final v = ((t * 1.3 + i * .07) % 1.0);
                final x = (i * 53 % 100) / 100;
                return Positioned(
                  left: 10 + x * 280,
                  top: -10 + v * 420,
                  child: IgnorePointer(child: Opacity(opacity: (1 - v).clamp(0.0, 1.0).toDouble() * _seg(t, 0, .1), child: Transform.rotate(angle: v * 9 + i, child: Text(const ['🎊', '✨', '🎉', '⭐'][i % 4], style: const TextStyle(fontSize: 18, height: 1))))),
                );
              }),
          ]);
        },
      ),
    );
  }

  Widget _lvChip(String text, bool big) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 18 : 14, vertical: big ? 8 : 6),
        decoration: BoxDecoration(color: big ? AppColors.green : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: big ? AppColors.greenDark : AppColors.line, width: 2)),
        child: Text(text, style: TextStyle(fontSize: big ? 24 : 18, fontWeight: FontWeight.w900, color: big ? Colors.white : const Color(0xFF000000))),
      );
}
