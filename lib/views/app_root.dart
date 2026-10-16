import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'login_page.dart';
import 'splash_page.dart';
import 'tutorial_page.dart';

/// 스플래시 → (처음 한 번) 튜토리얼 → 로그인 여부에 따라 로그인/홈
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});
  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  int _stage = 0; // 0 스플래시, 1 튜토리얼, 2 앱

  /// 이번 실행이 튜토리얼을 처음 보는 것인지 (처음이면 튜토리얼 다음에 로그인 화면을 꼭 보여준다)
  bool _firstTime = false;

  void _afterSplash() {
    final prefs = ref.read(prefsProvider);
    _firstTime = !(prefs.getBool(tutorialDoneKey) ?? false);
    // 시안 순서: 스플래시 → 튜토리얼 → (로그인) → 농장.
    // 처음 실행일 때만 튜토리얼을 보여준다. 앱 정보에서 '앱을 켤 때 튜토리얼 보기'를 켜면 매번 보여준다.
    final show = _firstTime; // 튜토리얼은 처음 한 번만 (예전 '켤 때마다 보기' 설정이 남아 있어도 무시)
    // 보여 주는 순간 '봤음'으로 저장한다: 튜토리얼 중간에 앱을 꺼도 다음에 켤 때 다시 나오지 않는다
    if (show) prefs.setBool(tutorialDoneKey, true);
    setState(() => _stage = show ? 1 : 2);
  }

  void _afterTutorial() {
    ref.read(prefsProvider).setBool(tutorialDoneKey, true);
    // 처음 본 튜토리얼이 끝나면 로그인·회원가입 화면으로 간다 (게스트 세션이 남아 있어도 한 번은 보여준다)
    if (_firstTime) ref.read(loginAfterTutorialProvider.notifier).state = true;
    setState(() => _stage = 2);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case 0:
        return SplashPage(onDone: _afterSplash);
      case 1:
        return TutorialPage(onDone: _afterTutorial);
      default:
        return const AuthGate();
    }
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final askLogin = ref.watch(loginAfterTutorialProvider);
    return auth.when(
      loading: () => const _Loading(),
      error: (e, _) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('로그인 상태를 확인하지 못했어요\n$e', textAlign: TextAlign.center)))),
      data: (user) {
        // 로그인 안 함 → 로그인 화면. 튜토리얼 직후인데 게스트 세션만 남아 있음 → 그래도 로그인 화면 먼저.
        if (user == null || (askLogin && user.isAnonymous)) return const LoginPage();
        return _UserReady(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: GameBackground(child: Center(child: CircularProgressIndicator())));
}

/// 사용자 문서가 준비된 뒤에 홈을 보여준다.
class _UserReady extends ConsumerStatefulWidget {
  const _UserReady({super.key, required this.user});
  final User user;
  @override
  ConsumerState<_UserReady> createState() => _UserReadyState();
}

class _UserReadyState extends ConsumerState<_UserReady> {
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _prepare();
  }

  Future<void> _prepare() async {
    final nick = ref.read(pendingNicknameProvider) ?? widget.user.displayName;
    final repo = ref.read(farmRepoProvider);
    await repo.ensureUser(nickname: nick);
    ref.read(pendingNicknameProvider.notifier).state = null;
    // 성장 시간이 줄어든 작물(배추 50분)이 예전 시간으로 심겨 있으면 새 시간에 맞춘다. 실패해도 게임은 계속한다.
    try {
      await repo.fitGrowTimes();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _ready,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _Loading();
          if (snap.hasError) {
            return Scaffold(
              body: GameBackground(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('농장을 불러오지 못했어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(errMsg(snap.error!), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub)),
                      const SizedBox(height: 16),
                      GreenButton(label: '다시 시도', onPressed: () => setState(() => _ready = _prepare())),
                      const SizedBox(height: 8),
                      GreenButton(label: '로그아웃', outlined: true, onPressed: () => ref.read(authServiceProvider).signOut()),
                    ]),
                  ),
                ),
              ),
            );
          }
          return const HomeShell();
        },
      );
}
