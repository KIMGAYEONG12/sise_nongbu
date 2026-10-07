import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
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

/// 레벨 업 축하 창
Future<void> showLevelUpDialog(BuildContext context, int from, int to, LevelInfo now) => showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 56, height: 1)),
          const SizedBox(height: 10),
          const Text('레벨 업!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.greenDark)),
          const SizedBox(height: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Lv.$from', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.sub)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded, color: AppColors.green)),
            Text('Lv.$to', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
          ]),
          const SizedBox(height: 12),
          Text('Lv.$from에서 Lv.$to로 올라갔어요!\n다음 레벨까지 경험치 ${now.need - now.exp} 남았어요.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.5)),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [GreenButton(label: '확인', onPressed: () => Navigator.of(d).pop())],
      ),
    );
