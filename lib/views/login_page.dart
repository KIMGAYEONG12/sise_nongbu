import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/farm_scene.dart';
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
      showMsg(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      showMsg(context, '이메일과 비밀번호를 입력해 주세요');
      return;
    }
    _run(() => ref.read(authServiceProvider).signIn(_email.text, _pw.text));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: Stack(children: [
            const Positioned(left: 0, right: 0, bottom: 0, height: 170, child: IgnorePointer(child: CustomPaint(painter: ScenePainter(hillsOnly: true, fence: true)))),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                child: Column(children: [
                  const Text('로그인', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('시세 농부에 오신 것을 환영합니다!', style: TextStyle(fontSize: 13, color: AppColors.sub)),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), hintText: '이메일을 입력하세요'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      hintText: '비밀번호를 입력하세요',
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GreenButton(label: '로그인', loading: _busy, onPressed: _login),
                  const _OrDivider(),
                  GreenButton(
                    label: 'Google로 로그인',
                    outlined: true,
                    icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                    onPressed: _busy ? null : () => _run(() => ref.read(authServiceProvider).signInWithGoogle()),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignupPage())), child: const Text('회원가입')),
                    const Text('|', style: TextStyle(color: AppColors.sub)),
                    TextButton(onPressed: () => _resetDialog(context), child: const Text('비밀번호 찾기')),
                  ]),
                  TextButton(
                    onPressed: _busy ? null : () => _run(() => ref.read(authServiceProvider).signInAsGuest()),
                    child: const Text('게스트로 둘러보기', style: TextStyle(color: AppColors.sub, decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      );

  Future<void> _resetDialog(BuildContext context) async {
    final c = TextEditingController(text: _email.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 찾기'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('가입한 이메일로 비밀번호 재설정 링크를 보내드려요.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: '이메일')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('보내기')),
        ],
      ),
    );
    final email = c.text.trim();
    c.dispose();
    if (ok != true || !mounted) return;
    if (email.isEmpty) {
      showMsg(this.context, '이메일을 입력해 주세요');
      return;
    }
    await _run(() async {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) showMsg(this.context, '재설정 메일을 보냈어요. 메일함을 확인해 주세요');
    });
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Expanded(child: Divider(color: AppColors.line)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('또는', style: TextStyle(fontSize: 12, color: AppColors.sub))),
          Expanded(child: Divider(color: AppColors.line)),
        ]),
      );
}
