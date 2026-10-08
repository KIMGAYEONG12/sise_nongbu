import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../services/auth_service.dart';
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
    final name = await showTextInputDialog(context, title: '닉네임 바꾸기', initial: current, hint: '2~12자 (한글·영어·숫자)', maxLength: 12);
    if (name == null || !context.mounted) return; // 취소
    if (name.length < 2) {
      showMsg(context, '닉네임은 2자 이상 입력해 주세요');
      return;
    }
    if (name == current) return;
    await runGuarded(context, () => ref.read(farmRepoProvider).setNickname(name), ok: '닉네임을 바꿨어요');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: Text(ref.read(authServiceProvider).isGuest ? '게스트 계정은 로그아웃하면 데이터를 다시 불러올 수 없어요.\n먼저 "계정에 연결"을 하면 데이터를 지킬 수 있어요.' : '같은 계정으로 다시 로그인하면 농장이 그대로 돌아와요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(shellIndexProvider.notifier).state = 1;
    // 다음에 앱을 켜면 스플래시 → 튜토리얼 → 로그인 순서로 다시 보여준다
    await ref.read(prefsProvider).remove(tutorialDoneKey);
    if (!context.mounted) return;
    await runGuarded(context, ref.read(authServiceProvider).signOut);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final lv = user.level;

    Widget menu(IconData icon, String label, VoidCallback onTap, {bool last = false}) => Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                Icon(icon, color: const Color(0xFF2B3A30), size: 24),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1C2B20)))),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF2B3A30)),
              ]),
            ),
          ),
          if (!last) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEDF1E8)),
        ]);

    final guest = ref.watch(isGuestProvider).valueOrNull ?? ref.read(authServiceProvider).isGuest;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      // 게스트는 앱을 지우면 농장 데이터를 잃으므로, 이메일·Google 계정에 연결하도록 안내한다
      if (guest) ...[
        SoftCard(
          color: const Color(0xFFFFF1CC),
          onTap: () => showLinkAccountSheet(context, ref),
          padding: const EdgeInsets.all(14),
          child: const Row(children: [
            Text('☁️', style: TextStyle(fontSize: 30)),
            SizedBox(width: 12),
            Expanded(
              child: Text('게스트 농장은 앱을 지우면 사라져요!\n계정에 연결하면 언제든 데이터를 되찾을 수 있어요.', style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF2B3A30)),
          ]),
        ),
        const SizedBox(height: 14),
      ],
      // 시안: 큰 아바타 + 닉네임 + Lv + 경험치 막대
      Row(children: [
        const FarmerAvatar(size: 84),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20)))),
              IconButton(visualDensity: VisualDensity.compact, onPressed: () => _rename(context, ref, user.nickname), icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.sub)),
            ]),
            Text('Lv.${lv.level}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3D4A40))),
            const SizedBox(height: 8),
            Stack(alignment: Alignment.center, children: [
              ThinBar(value: lv.ratio, height: 16, track: const Color(0xFFE3EBDD)),
              Text('${lv.exp} / ${lv.need}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2B3A30))),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      SoftCard(
        color: Colors.white,
        onTap: () => showCropStats(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          const SizedBox(
            width: 52,
            height: 40,
            child: Stack(children: [
              Positioned(left: 0, bottom: 0, child: CoinIcon(size: 30)),
              Positioned(left: 18, bottom: 6, child: CoinIcon(size: 30)),
              Positioned(left: 8, top: 0, child: CoinIcon(size: 24)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('보유 금액', style: TextStyle(fontSize: 12, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(won(user.money), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20))),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF2B3A30)),
        ]),
      ),
      const SizedBox(height: 12),
      SoftCard(
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: Column(children: [
          menu(Icons.home_work_outlined, '내 농장', () => ref.read(shellIndexProvider.notifier).state = 1),
          menu(Icons.bar_chart_rounded, '농작물 통계', () => showCropStats(context)),
          menu(Icons.emoji_events_outlined, '업적', () => _push(context, const AchievementPage())),
          menu(Icons.receipt_long_outlined, '거래 기록', () => _push(context, const TradeHistoryPage())),
          menu(Icons.support_agent_rounded, '고객센터', () => _push(context, const SupportPage())),
          menu(Icons.info_outline_rounded, '앱 정보', () => _push(context, const AboutPage())),
          menu(Icons.logout_rounded, '로그아웃', () => _logout(context, ref), last: true),
        ]),
      ),
    ]);
  }
}

/// 게스트 농장을 이메일 또는 Google 계정에 연결하는 창. uid가 그대로라 데이터가 이어진다.
void showLinkAccountSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _LinkAccountSheet(ref: ref),
    ),
  );
}

class _LinkAccountSheet extends StatefulWidget {
  const _LinkAccountSheet({required this.ref});
  final WidgetRef ref;
  @override
  State<_LinkAccountSheet> createState() => _LinkAccountSheetState();
}

class _LinkAccountSheetState extends State<_LinkAccountSheet> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
      if (!mounted) return;
      Navigator.of(context).pop();
      showMsg(context, '계정에 연결했어요! 이제 앱을 지워도 데이터가 남아 있어요 ☁️');
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.ref.read(authServiceProvider);
    final nick = widget.ref.read(userDataProvider).nickname;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('계정에 연결하고 데이터 지키기', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('지금 농장 그대로 계정에 연결돼요.\n앱을 지웠다 다시 깔아도 같은 계정으로 로그인하면 돌아와요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)', border: OutlineInputBorder())),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.up, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          GreenButton(label: _busy ? '연결 중…' : '이메일로 연결하기', onPressed: _busy ? null : () => _run(() => auth.linkWithEmail(_email.text, _pw.text, nick))),
          const SizedBox(height: 8),
          GreenButton(label: 'Google로 연결하기', outlined: true, onPressed: _busy ? null : () => _run(auth.linkWithGoogle)),
        ]),
      ),
    );
  }
}

/// 농작물 통계 (누적 수익, 파종·수확·판매 횟수, 작물별 수확 횟수). MY 화면과 고객센터에서 연다.
void showCropStats(BuildContext context) {
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

