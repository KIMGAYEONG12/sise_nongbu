import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'about_page.dart';
import 'achievement_page.dart';
import 'support_page.dart';
import 'trade_history_page.dart';

/// MY 탭: 프로필, 보유 금액, 내 농장·통계·업적·고객센터, 로그아웃
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final ctl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('닉네임 바꾸기'),
        content: TextField(controller: ctl, maxLength: 12, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    await runGuarded(context, () => ref.read(farmRepoProvider).setNickname(name), ok: '닉네임을 바꿨어요');
  }

  void _stats(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Consumer(builder: (_, r, __) {
        final u = r.watch(userDataProvider);
        Widget line(String a, String b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [Text(a, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('농작물 통계', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              line('누적 수익', won(u.totalProfit)),
              line('파종', '${u.stat('plant')}회'),
              line('수확', '${u.stat('harvest')}회'),
              line('판매', '${u.stat('sell')}회'),
              const Divider(),
              for (final c in crops) line('${c.emoji} ${c.name} 수확', '${u.stat('crop_${c.code}')}회'),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('게스트 계정은 로그아웃하면 데이터를 다시 불러올 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(shellIndexProvider.notifier).state = 1;
    await runGuarded(context, ref.read(authServiceProvider).signOut);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final lv = user.level;

    Widget menu(IconData icon, String label, VoidCallback onTap) => SoftCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          onTap: onTap,
          child: Row(children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.sub),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      const PageHeader(title: 'MY'),
      SoftCard(
        child: Column(children: [
          Row(children: [
            const EmojiBadge('🧑‍🌾', size: 62),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(user.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => _rename(context, ref, user.nickname), icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.sub)),
                ]),
                Text('Lv.${lv.level}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDark)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          ThinBar(value: lv.ratio, height: 10),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: Text('EXP ${lv.exp} / ${lv.need}', style: const TextStyle(fontSize: 11, color: AppColors.sub))),
        ]),
      ),
      const SizedBox(height: 10),
      SoftCard(
        child: Row(children: [
          const Icon(Icons.monetization_on_rounded, color: AppColors.coin, size: 30),
          const SizedBox(width: 10),
          const Text('보유 금액', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(won(user.money), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      ),
      const SizedBox(height: 14),
      menu(Icons.grass_rounded, '내 농장', () => ref.read(shellIndexProvider.notifier).state = 1),
      menu(Icons.bar_chart_rounded, '농작물 통계', () => _stats(context, ref)),
      menu(Icons.emoji_events_rounded, '업적', () => _push(context, const AchievementPage())),
      menu(Icons.receipt_long_rounded, '거래 기록', () => _push(context, const TradeHistoryPage())),
      menu(Icons.support_agent_rounded, '고객센터', () => _push(context, const SupportPage())),
      menu(Icons.info_outline_rounded, '앱 정보', () => _push(context, const AboutPage())),
      const SizedBox(height: 8),
      GreenButton(label: '로그아웃', outlined: true, onPressed: () => _logout(context, ref)),
    ]);
  }
}
