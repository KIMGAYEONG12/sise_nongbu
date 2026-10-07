import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../widgets/farm_scene.dart';

/// 로고와 진행 막대가 있는 시작 화면. 막대가 다 차면 [onDone]을 부른다.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: SceneBackground(fence: true)),
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 70),
              const LogoSign(scale: 1.1),
              const SizedBox(height: 16),
              const Text('시세를 알고, 수확의 기쁨을!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF5A3418), shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
              const Spacer(),
              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 18), child: const Text('👩‍🌾', style: TextStyle(fontSize: 92, height: 1)))),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final v = Curves.easeOut.transform(_c.value);
                    return Column(children: [
                      const Text('농부의 꿈이 자라고 있어요...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: ThinBar(value: v, height: 10, color: const Color(0xFF8BD347), track: Colors.white70)),
                        const SizedBox(width: 8),
                        Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                      ]),
                    ]);
                  },
                ),
              ),
            ]),
          ),
        ]),
      );
}
