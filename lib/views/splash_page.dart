import 'package:flutter/material.dart';
import '../widgets/common.dart';

/// 챗GPT 시안 그대로의 시작 화면 (간판·농부 일러스트 + 하단 진행 막대). 막대가 다 차면 [onDone]을 부른다.
///
/// 에뮬레이터·디버그 빌드는 첫 프레임이 늦게 그려져서, 예전처럼 initState에서 바로 애니메이션을 시작하면
/// 화면이 보이기도 전에 시간이 다 흘러 스플래시가 건너뛰어진 것처럼 보였다.
/// 그래서 첫 프레임이 그려지고 그림을 다 읽은 "뒤에" 진행 막대를 시작하고, 최소 노출 시간도 보장한다.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    try {
      await precacheImage(const AssetImage(AppImages.splash), context);
    } catch (_) {}
    if (!mounted) return;
    // 다음 화면(튜토리얼·로그인·농장) 그림은 막대가 차는 동안 뒤에서 미리 읽는다.
    AppImages.precacheAll(context);
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted && !_done) {
      _done = true;
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF42AAF0),
      body: Stack(children: [
        Positioned.fill(
          child: Image.asset(AppImages.splash, fit: BoxFit.cover, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.medium),
        ),
        // 시안 하단의 흰색 둥근 패널 + "농부의 꿈이 자라고 있어요..." + 진행 막대
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(34, 22, 34, 22 + bottomInset),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: .93), const Color(0xFFFDFBF1)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.elliptical(260, 46)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, -2))],
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final v = Curves.easeOutCubic.transform(_c.value);
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('농부의 꿈이 자라고 있어요...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3D4A40))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ThinBar(value: v, height: 12, color: const Color(0xFF2E9E46), track: const Color(0xFFE2EBDD))),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      child: Text('${(v * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
                    ),
                  ]),
                ]);
              },
            ),
          ),
        ),
      ]),
    );
  }
}
