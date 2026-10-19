import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'signup_page.dart';

/// 로그인 성공 후에는 [AuthGate]가 알아서 홈으로 바꿔 보여준다.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true, _busy = false;

  /// 아이디(이메일) 저장 · 로그인 유지 (기기에 저장). 로그인 유지는 기본으로 켜져 있다.
  bool _rememberEmail = false, _keepLogin = true;

  @override
  void initState() {
    super.initState();
    try {
      final prefs = ref.read(prefsProvider);
      _rememberEmail = prefs.getBool(rememberEmailKey) ?? false;
      _keepLogin = prefs.getBool(keepLoginKey) ?? true;
      if (_rememberEmail) _email.text = prefs.getString(savedEmailKey) ?? '';
    } catch (_) {} // 저장소가 없는 테스트 화면
  }

  /// 로그인에 성공하면 아이디 저장·로그인 유지 설정과 로그인 방법을 기기에 적어 둔다
  Future<void> _saveLoginPrefs({String? email, required String method}) async {
    try {
      final prefs = ref.read(prefsProvider);
      await prefs.setBool(rememberEmailKey, _rememberEmail);
      await prefs.setBool(keepLoginKey, _keepLogin);
      await prefs.setString(lastLoginMethodKey, method);
      if (_rememberEmail && email != null && email.trim().isNotEmpty) {
        await prefs.setString(savedEmailKey, email.trim());
      } else if (!_rememberEmail) {
        await prefs.remove(savedEmailKey);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) showMsg(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      showMsg(context, '이메일과 비밀번호를 입력해 주세요');
      return;
    }
    final flag = ref.read(loginAfterTutorialProvider.notifier);
    final email = _email.text;
    _run(() async {
      await ref.read(authServiceProvider).signIn(email, _pw.text);
      await _saveLoginPrefs(email: email, method: 'email');
      flag.state = false;
    });
  }

  void _google() {
    final flag = ref.read(loginAfterTutorialProvider.notifier);
    _run(() async {
      await ref.read(authServiceProvider).signInWithGoogle();
      await _saveLoginPrefs(email: ref.read(authServiceProvider).currentUser?.email, method: 'google');
      flag.state = false;
    });
  }

  /// 게스트: 이미 게스트 세션이 있으면 그 농장으로 그대로 이어서 들어가고, 없으면 새 게스트로 시작한다.
  void _guest() {
    final flag = ref.read(loginAfterTutorialProvider.notifier);
    final auth = ref.read(authServiceProvider);
    _run(() async {
      final cur = auth.currentUser;
      if (cur == null || !cur.isAnonymous) await auth.signInAsGuest();
      flag.state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GameBackground(
        child: Stack(children: [
          // 시안 하단의 농장 풍경 일러스트
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h * .36,
            child: IgnorePointer(child: Image.asset(AppImages.loginLand, fit: BoxFit.cover, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.medium)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
              child: Column(children: [
                const SizedBox(height: 6),
                const Text('로그인', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.ink)),
                const SizedBox(height: 12),
                const Text('시세 농부에 오신 것을 환영합니다!', style: TextStyle(fontSize: 14, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600)),
                const SizedBox(height: 26),
                _Field(
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), hintText: '이메일을 입력하세요'),
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  child: TextField(
                    controller: _pw,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      hintText: '비밀번호를 입력하세요',
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 아이디 저장 · 로그인 유지: 눌러서 켜고 끄는 둥근 버튼 두 개
                Row(children: [
                  Expanded(
                    child: _ToggleChip(
                      icon: Icons.badge_outlined,
                      label: '아이디 저장',
                      value: _rememberEmail,
                      onChanged: (v) => setState(() => _rememberEmail = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ToggleChip(
                      icon: Icons.lock_clock_outlined,
                      label: '로그인 유지',
                      value: _keepLogin,
                      onChanged: (v) => setState(() => _keepLogin = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                GreenButton(label: '로그인', loading: _busy, height: 52, onPressed: _login),
                const OrDivider(),
                GreenButton(label: 'Google로 로그인', outlined: true, height: 52, icon: const GoogleG(), onPressed: _busy ? null : _google),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignupPage())),
                    child: const Text('회원가입', style: TextStyle(color: Color(0xFF3D4A40), fontWeight: FontWeight.w700)),
                  ),
                  Container(width: 1, height: 12, color: const Color(0xFFB9C6B5)),
                  TextButton(onPressed: () => _resetDialog(context), child: const Text('비밀번호 찾기', style: TextStyle(color: Color(0xFF3D4A40), fontWeight: FontWeight.w700))),
                ]),
                TextButton(
                  onPressed: _busy ? null : _guest,
                  child: const Text('게스트로 둘러보기', style: TextStyle(fontSize: 12, color: AppColors.sub, decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _resetDialog(BuildContext context) async {
    final email = await showTextInputDialog(
      context,
      title: '비밀번호 찾기',
      message: '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.',
      initial: _email.text.trim(),
      hint: '이메일',
      okLabel: '보내기',
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || !mounted) return;
    if (email.isEmpty) {
      showMsg(this.context, '이메일을 입력해 주세요');
      return;
    }
    final auth = ref.read(authServiceProvider);
    await _run(() async {
      await auth.sendPasswordReset(email);
      if (mounted) showMsg(this.context, '재설정 메일을 보냈어요. 메일함을 확인해 주세요');
    });
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(child: Divider(color: Color(0xFFD5DECF))),
          Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('또는', style: TextStyle(fontSize: 13, color: Color(0xFF4A5A4E), fontWeight: FontWeight.w600))),
          Expanded(child: Divider(color: Color(0xFFD5DECF))),
        ]),
      );
}

/// 눌러서 켜고 끄는 둥근 버튼: 켜지면 연두색 바탕 + 초록 테두리 + 체크 표시, 꺼지면 흰 바탕
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: value ? const Color(0xFFE7F5DF) : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: value ? AppColors.green : const Color(0xFFD5DECF), width: value ? 1.8 : 1.2),
              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: value ? .16 : .06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  value ? Icons.check_circle_rounded : icon,
                  key: ValueKey(value),
                  size: 20,
                  color: value ? AppColors.green : AppColors.sub,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: value ? AppColors.greenDark : const Color(0xFF5B6A5E)),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// 시안처럼 살짝 그림자가 있는 흰 입력칸
class _Field extends StatelessWidget {
  const _Field({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: child,
      );
}

/// 회원가입 화면에서도 쓰는 입력칸 (그림자 포함)
class ShadowField extends StatelessWidget {
  const ShadowField({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => _Field(child: child);
}
