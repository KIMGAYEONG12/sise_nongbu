import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(shellIndexProvider);
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
