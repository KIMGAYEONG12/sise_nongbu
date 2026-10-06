import 'package:flutter/material.dart';
import 'about_page.dart';
import 'farm_page.dart';
import 'inventory_page.dart';
import 'market_page.dart';
import 'trade_history_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 1;
  static const _titles = ['시세판', '농장', '창고', '기록'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('🌾 ${_titles[_i]}'), actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
        ]),
        body: IndexedStack(index: _i, children: const [MarketPage(), FarmPage(), InventoryPage(), TradeHistoryPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.show_chart), label: '시세판'),
            NavigationDestination(icon: Icon(Icons.grass), label: '농장'),
            NavigationDestination(icon: Icon(Icons.inventory_2), label: '창고'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: '기록'),
          ],
        ),
      );
}
