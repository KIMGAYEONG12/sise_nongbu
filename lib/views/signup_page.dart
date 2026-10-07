import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'login_page.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});
  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _email = TextEditingController();
  final _nick = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _nick.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) return '이메일 형식을 확인해 주세요';
    if (_nick.text.trim().length < 2) return '닉네임은 2자 이상 입력해 주세요';
    if (_pw.text.length < 6) return '비밀번호는 6자 이상이어야 해요';
    if (_pw.text != _pw2.text) return '비밀번호가 서로 달라요';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      showMsg(context, err);
      return;
    }
    setState(() => _busy = true);
    final flag = ref.read(loginAfterTutorialProvider.notifier);
    final pending = ref.read(pendingNicknameProvider.notifier);
    try {
      pending.state = _nick.text.trim();
      await ref.read(authServiceProvider).signUp(_email.text, _pw.text, _nick.text);
      flag.state = false;
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      pending.state = null;
      if (mounted) showMsg(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    final flag = ref.read(loginAfterTutorialProvider.notifier);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      flag.state = false;
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showMsg(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: GameBackground(
        child: Stack(children: [
          // 시안 하단의 농장 풍경 일러스트
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h * .2,
            child: IgnorePointer(child: Image.asset(AppImages.signupLand, fit: BoxFit.cover, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.medium)),
          ),
          SafeArea(
            child: Column(children: [
              SizedBox(
                height: 64,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(
                    left: 6,
                    child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.chevron_left_rounded, size: 32, color: AppColors.ink)),
                  ),
                  const Text('회원가입', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 40),
                  child: Column(children: [
                    ShadowField(
                      child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), hintText: '이메일 입력')),
                    ),
                    const SizedBox(height: 12),
                    ShadowField(
                      child: TextField(controller: _nick, maxLength: 12, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), hintText: '닉네임 입력 (2자 이상)', counterText: '')),
                    ),
                    const SizedBox(height: 12),
                    ShadowField(
                      child: TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), hintText: '비밀번호 입력 (6자 이상)')),
                    ),
                    const SizedBox(height: 12),
                    ShadowField(
                      child: TextField(controller: _pw2, obscureText: true, onSubmitted: (_) => _submit(), decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), hintText: '비밀번호 확인')),
                    ),
                    const SizedBox(height: 20),
                    GreenButton(label: '회원가입', loading: _busy, height: 52, onPressed: _submit),
                    const OrDivider(),
                    GreenButton(label: 'Google로 로그인', outlined: true, height: 52, icon: const GoogleG(), onPressed: _busy ? null : _google),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('이미 계정이 있나요?  로그인', style: TextStyle(color: Color(0xFF3D4A40), fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
