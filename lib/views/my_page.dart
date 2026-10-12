import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../services/auth_service.dart';
import '../viewmodels/view_models.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'about_page.dart';
import '../core/progress_rules.dart';
import 'achievement_page.dart';
import 'encyclopedia_page.dart';
import 'news_page.dart';
import 'point_shop_page.dart';
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

  /// 보유 포인트 / 보유 금액 카드
  Widget _walletCard({required Widget icon, required String label, required String value, required VoidCallback onTap}) => SoftCard(
        color: Colors.white,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          SizedBox(width: 38, child: Center(child: icon)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20)))),
            ]),
          ),
        ]),
      );

  /// 나의 칭호 카드: 지금 쓰는 칭호 + 다음 새 칭호까지 진행. 누르면 얻은 칭호 중에서 골라 장착할 수 있다.
  /// 레벨이 한 번 오를 때마다 칭호 "단계"가 하나씩 오르고, 정해진 레벨마다 더 멋진 칭호가 열린다.
  Widget _titleCard(BuildContext context, UserData user) {
    final lv = user.level;
    final level = lv.level;
    final top = farmerTitleIndex(level); // 레벨로 얻은 가장 높은 칭호
    final i = user.titleIndex; // 지금 쓰는 칭호 (장착한 것 또는 가장 높은 것)
    final cur = farmerTitles[i];
    final next = top + 1 < farmerTitles.length ? farmerTitles[top + 1] : null;
    final rank = titleRankOf(level, i);
    final progress = titleProgress(lv);
    return GestureDetector(
      onTap: () => showTitleSheet(context),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE3F4D2), Color(0xFFF4FAEA)]),
        border: Border.all(color: const Color(0xFFCFE6B8)),
      ),
      child: Row(children: [
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFE9A0), Color(0xFFF0B63C)]),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: const Color(0xFFE0A800).withValues(alpha: .35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Text(cur.emoji, style: const TextStyle(fontSize: 32, height: 1)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(cur.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.greenDark))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)),
                child: Text('$rank단계', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(next == null ? '가장 높은 칭호예요. 레벨이 오를 때마다 단계가 올라가요' : '다음 칭호 "${next.name}"까지 Lv.${next.minLevel}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF3D4A40), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ThinBar(value: progress, height: 9)),
              const SizedBox(width: 8),
              Text(next == null ? 'MAX' : '${(progress * 100).floor()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF3D4A40))),
            ]),
            const SizedBox(height: 4),
            Text(user.titleIdx == null ? '눌러서 칭호 바꾸기' : '장착 중 · 눌러서 칭호 바꾸기', style: const TextStyle(fontSize: 11.5, color: AppColors.greenDark, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
      ),
    );
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
      // 시안: 보유 포인트 · 보유 금액 두 장
      // (ListView 안에서는 높이가 정해져 있지 않아서 IntrinsicHeight 로 두 카드 높이를 맞춘다)
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _walletCard(icon: const Icon(Icons.star_rounded, color: AppColors.coin, size: 34), label: '보유 포인트', value: '${commaNum(user.points)}P', onTap: () => _push(context, const PointShopPage()))),
        const SizedBox(width: 12),
        Expanded(child: _walletCard(icon: const CoinIcon(size: 32), label: '보유 금액', value: won(user.money), onTap: () => showCropStats(context))),
        ]),
      ),
      const SizedBox(height: 18),
      // 시안: 나의 칭호 (레벨에 따라 바뀐다)
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('나의 칭호', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1C2B20)))),
      _titleCard(context, user),
      const SizedBox(height: 14),
      SoftCard(
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: Column(children: [
          menu(Icons.home_work_outlined, '내 농장', () => ref.read(shellIndexProvider.notifier).state = 1),
          menu(Icons.bar_chart_rounded, '농작물 통계', () => showCropStats(context)),
          menu(Icons.emoji_events_outlined, '업적', () => _push(context, const AchievementPage())),
          menu(Icons.menu_book_outlined, '작물 도감', () => _push(context, const EncyclopediaPage())),
          menu(Icons.newspaper_rounded, '전국 농부 뉴스', () => _push(context, const NewsPage())),
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
/// 작물이 21종이라 길어서, 화면 높이의 85%까지만 차지하고 그 안에서 스크롤된다 (예전에는 아래가 넘쳐 노란 줄무늬 오류가 났다).
void showCropStats(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => Consumer(builder: (_, r, __) {
      final u = r.watch(userDataProvider);
      Widget line(Widget a, String b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [Expanded(child: a), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]),
          );
      Widget label(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700));
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: Text('농작물 통계', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              const SizedBox(height: 10),
              line(label('누적 수익'), won(u.totalProfit)),
              line(label('파종'), '${u.stat('plant')}회'),
              line(label('수확'), '${u.stat('harvest')}회'),
              line(label('판매'), '${u.stat('sell')}회'),
              const Divider(),
              for (final c in crops)
                line(Row(children: [CropArt(code: c.code, size: 26), const SizedBox(width: 8), label('${c.name} 수확')]), '${u.stat('crop_${c.code}')}회'),
            ]),
          ),
        ),
      );
    }),
  );
}

/// 칭호 고르기 창: 7가지 칭호 가운데 얻은 것은 눌러서 장착하고, 아직 못 얻은 것은 열리는 레벨을 보여 준다.
/// "자동"을 고르면 레벨에 맞는 가장 높은 칭호가 쓰인다.
void showTitleSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const TitleSheet(),
  );
}

class TitleSheet extends ConsumerWidget {
  const TitleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final level = user.level.level;
    final top = farmerTitleIndex(level);
    final current = user.titleIndex;
    Future<void> pick(int? index) async {
      final ok = await runGuarded(context, () => ref.read(farmViewModelProvider).setTitle(index), ok: index == null ? '칭호를 자동으로 바꿨어요' : '"${farmerTitles[index].name}" 칭호를 장착했어요');
      if (ok && context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: Text('나의 칭호', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            const SizedBox(height: 4),
            Center(child: Text('Lv.$level · 레벨이 오르면 더 멋진 칭호가 열려요', style: const TextStyle(fontSize: 12.5, color: Color(0xFF3D4A40), fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            for (var i = 0; i < farmerTitles.length; i++)
              Builder(builder: (_) {
                final t = farmerTitles[i];
                final unlocked = level >= t.minLevel;
                final on = i == current;
                // ListTile은 가장 가까운 Material 위에 배경과 물결 효과를 그린다. 배경색 상자(DecoratedBox) 안에 넣으면 가려지고
                // 디버그에서 오류가 나므로, 배경·테두리를 Material 자체에 준다.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: on ? const Color(0xFFE3F4D2) : Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: on ? AppColors.green : const Color(0xFFE3ECD9), width: on ? 2 : 1.2),
                    ),
                    child: ListTile(
                    enabled: unlocked,
                    onTap: unlocked ? () => pick(i) : null,
                    leading: Opacity(opacity: unlocked ? 1 : .35, child: Text(t.emoji, style: const TextStyle(fontSize: 30, height: 1))),
                    title: Text(t.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: unlocked ? const Color(0xFF111111) : const Color(0xFF8A958C))),
                    subtitle: Text(
                      unlocked ? (i == top ? 'Lv.${t.minLevel}부터 · 지금 얻을 수 있는 가장 높은 칭호' : 'Lv.${t.minLevel}부터') : '🔒 Lv.${t.minLevel}에 열려요 (${t.minLevel - level}레벨 남음)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: on ? const Icon(Icons.check_circle_rounded, color: AppColors.green) : (unlocked ? const Text('장착', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.greenDark)) : null),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 4),
            GreenButton(label: user.titleIdx == null ? '자동으로 쓰는 중 (가장 높은 칭호)' : '자동으로 바꾸기 (가장 높은 칭호)', outlined: true, onPressed: user.titleIdx == null ? null : () => pick(null)),
          ]),
        ),
      ),
    );
  }
}

