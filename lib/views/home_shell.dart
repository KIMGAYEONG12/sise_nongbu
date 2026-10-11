import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../core/game_rules.dart' show cropOf;
import '../widgets/greenhouse_art.dart' show greenhouseNames, greenhouseTier;
import '../widgets/common.dart';
import 'farm_page.dart';
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
      if (to > from) _celebrateLevelUp(context, ref, from, to, levelInfo((after['exp'] as num?)?.toInt() ?? 0));
    });
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          // 농장 탭은 시안처럼 하늘을 상태바 뒤까지 그리므로 위쪽 여백을 직접 처리한다
          top: i != 1,
          bottom: false,
          child: IndexedStack(index: i, children: [_MarketScaled(), const FarmPage(), const InventoryPage(), const ShopPage(), const MyPage()]),
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
/// 레벨 업 보상(500P + 희귀 씨앗)을 한 번만 받고, 받은 보상과 함께 축하 창을 띄운다.
/// 보상 받기에 실패해도(오프라인 등) 축하 창은 보여 준다.
Future<void> _celebrateLevelUp(BuildContext context, WidgetRef ref, int from, int to, LevelInfo now) async {
  LevelUpReward? reward;
  try {
    reward = await ref.read(farmViewModelProvider).claimLevelUp(from, to);
  } catch (_) {}
  if (context.mounted) await showLevelUpDialog(context, from, to, now, reward: reward);
}

Future<void> showLevelUpDialog(BuildContext context, int from, int to, LevelInfo now, {LevelUpReward? reward}) => showDialog<void>(
      context: context,
      builder: (d) => _LevelUpDialog(from: from, to: to, now: now, reward: reward),
    );

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.from, required this.to, required this.now, this.reward});
  final int from, to;
  final LevelInfo now;

  /// 이번 레벨 업으로 받은 보상 (받지 못했으면 null)
  final LevelUpReward? reward;
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

  /// 시안 그림(levelup_card.png)의 크기 (354×486, 흰 테두리를 잘라 낸 크기). 아래 위치들은 이 그림 위의 비율이다.
  static const _artW = 354.0, _artH = 486.0;

  @override
  Widget build(BuildContext context) {
    final tierNow = greenhouseTier(widget.to), tierBefore = greenhouseTier(widget.from);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            final pop = _seg(t, 0, .45, Curves.elasticOut);
            final fade = _seg(t, .2, .55);
            return Transform.scale(
              scale: .85 + .15 * pop.clamp(0.0, 1.15).toDouble(),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 10))]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AspectRatio(
                    aspectRatio: _artW / _artH,
                    child: LayoutBuilder(builder: (context, box) {
                      final w = box.maxWidth, h = box.maxHeight;
                      Rect at(double l, double tp, double r, double b) => Rect.fromLTRB(l / _artW * w, tp / _artH * h, r / _artW * w, b / _artH * h);
                      return Stack(clipBehavior: Clip.hardEdge, children: [
                        // 시안의 일러스트 카드 (농부 · 나무 간판 "LEVEL UP!" · 풀숲과 꽃)
                        Positioned.fill(child: Image.asset(AppImages.levelupCard, fit: BoxFit.fill, filterQuality: FilterQuality.high)),
                        // 시안 그림 속 "Lv.4" 리본 자리에 실제 레벨을 덮어 그린다
                        Positioned.fromRect(
                          rect: at(106, 226, 252, 264),
                          child: Opacity(
                            opacity: _seg(t, .1, .4),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(h * .014),
                                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFDA82D), Color(0xFFF08A1E)]),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Lv.${widget.to}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFFFF3C4), height: 1.1, shadows: [Shadow(color: Color(0x88B8661C), offset: Offset(0, 2))])),
                              ),
                            ),
                          ),
                        ),
                        // 글이 들어가는 흰 안내 판 (그림 속 예전 글자를 덮고 실제 내용을 보여 준다)
                        Positioned.fromRect(
                          rect: at(36, 268, 318, 486),
                          child: Opacity(
                            opacity: fade,
                            child: Container(
                              padding: EdgeInsets.fromLTRB(w * .03, h * .012, w * .03, h * .012),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(h * .035)),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width: 270,
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Text('레벨이 올랐어요!', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF1E5BB8))),
                                    const SizedBox(height: 4),
                                    Text(widget.to - widget.from > 1 ? 'Lv.${widget.from}에서 Lv.${widget.to}까지 한 번에 올랐어요!' : '더 큰 밭과 새로운 기능을 만나보세요!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w600, color: Color(0xFF3D4A40))),
                                    const SizedBox(height: 10),
                                    _rewardRow(t, tierNow > tierBefore),
                                    const SizedBox(height: 12),
                                    _okButton(),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 떨어지는 색종이
                        for (var i = 0; i < 10; i++)
                          Builder(builder: (_) {
                            final v = ((t * 1.3 + i * .09) % 1.0);
                            final x = (i * 53 % 100) / 100;
                            return Positioned(
                              left: 10 + x * (w - 40),
                              top: -10 + v * h * .9,
                              child: IgnorePointer(child: Opacity(opacity: (1 - v).clamp(0.0, 1.0).toDouble() * _seg(t, 0, .1), child: Transform.rotate(angle: v * 9 + i, child: Text(const ['🎊', '✨', '🎉', '⭐'][i % 4], style: const TextStyle(fontSize: 18, height: 1))))),
                            );
                          }),
                      ]);
                    }),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 시안의 진초록 "확인" 버튼
  Widget _okButton() => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2E9B4A), Color(0xFF14702F)]),
            boxShadow: [BoxShadow(color: const Color(0xFF14702F).withValues(alpha: .4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Text('확인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );

  /// 받은 보상 카드 두 개: 시안처럼 금화 "500P"와 새싹 "희귀 씨앗 ×1". 보상을 받지 못한 경우에는 경험치 안내를 보여 준다.
  Widget _rewardRow(double t, bool newTier) {
    final r = widget.reward;
    if (r != null) {
      final seed = cropOf(r.seedCode);
      return Row(children: [
        Expanded(child: _rewardCard(null, '${commaNum(r.points)}P', sub: '포인트', leading: _coin())),
        const SizedBox(width: 10),
        Expanded(child: _rewardCard('🌱', '희귀 씨앗 ×${r.seedCount}', sub: seed.name)),
      ]);
    }
    return Row(children: [
      Expanded(child: _rewardCard('⭐', '${(widget.now.exp * _seg(t, .35, .85)).round()} / ${widget.now.need}', sub: '경험치')),
      const SizedBox(width: 10),
      Expanded(
        child: newTier
            ? _rewardCard('🏠', greenhouseNames[greenhouseTier(widget.to)], sub: '새 하우스 모양')
            : _rewardCard('🌱', '경험치 ${widget.now.need - widget.now.exp}', sub: '다음 레벨까지'),
      ),
    ]);
  }

  /// 금화 모양 (시안의 500P 카드 그림)
  Widget _coin() => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFE27A), Color(0xFFF2A81D)]),
          border: Border.all(color: const Color(0xFFD98A0B), width: 3),
          boxShadow: [BoxShadow(color: const Color(0xFFD98A0B).withValues(alpha: .4), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD98A0B).withValues(alpha: .6), width: 2))),
      );

  Widget _rewardCard(String? emoji, String label, {String? sub, Widget? leading}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF7FAFD), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE3EAF2)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 5, offset: const Offset(0, 2))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          leading ?? Text(emoji ?? '', style: const TextStyle(fontSize: 34, height: 1.15)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF2057B5)))),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7A70))),
        ]),
      );
}

/// 시세판은 정보가 빽빽해서 앱 전체 배율(1.1)보다 살짝 작게 (최종 약 1.05배)
class _MarketScaled extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * 0.95)),
      child: const MarketPage(),
    );
  }
}
