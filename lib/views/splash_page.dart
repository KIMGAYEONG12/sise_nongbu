import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/common.dart';

/// 챗GPT 시안 그대로의 시작 화면 (간판·농부 일러스트 + 하단 진행 막대). 막대가 다 차면 [onDone]을 부른다.
///
/// 그림 위에 튜토리얼 화면들처럼 움직이는 연출을 올렸다:
/// 천천히 다가가는 화면, 흘러가는 구름, 간판을 훑고 지나가는 빛, 반짝이는 별빛, 흩날리는 꽃잎,
/// 아래에서 올라오는 문구와 진행 패널.
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

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  /// 처음 한 번 재생하는 등장 연출
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  /// 계속 반복하는 연출 (구름·빛·별빛·꽃잎)
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000));
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
    _in.forward();
    _fx.repeat();
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
    _in.dispose();
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF42AAF0),
      body: Stack(children: [
        // 그림 + 그 위의 연출 (같은 좌표계라서 함께 천천히 다가간다)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_in, _fx, _c]),
            builder: (_, __) {
              final zoom = 1.0 + .07 * Curves.easeOut.transform(_c.value); // 막대가 차는 동안 천천히 다가간다
              return Transform.scale(
                scale: zoom,
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(builder: (context, box) => _Scene(size: box.biggest, intro: _in.value, loop: _fx.value)),
              );
            },
          ),
        ),
        // 시안 하단의 흰색 둥근 패널 + "농부의 꿈이 자라고 있어요..." + 진행 막대 (아래에서 올라온다)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: _in,
            builder: (_, child) {
              final v = Curves.easeOutCubic.transform(_in.value);
              return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 40), child: child));
            },
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
        ),
      ]),
    );
  }
}

/// 스플래시 그림(993×2160)과 그 위의 연출. 그림은 BoxFit.cover + 아래 정렬이라,
/// 같은 계산으로 그림 속 위치(원본 픽셀)를 화면 좌표로 바꿔서 연출을 놓는다.
class _Scene extends StatelessWidget {
  const _Scene({required this.size, required this.intro, required this.loop});
  final Size size;

  /// 등장 연출 진행 0~1
  final double intro;

  /// 반복 연출 진행 0~1
  final double loop;

  static const _imgW = 993.0, _imgH = 2160.0;

  /// 간판 나무판이 그려진 자리 (원본 픽셀)
  static const _sign = Rect.fromLTRB(120, 940, 915, 1260);

  /// 간판 둘레에서 반짝일 별빛 (가로, 세로, 시차)
  static const _stars = [(90.0, 800.0, .0), (905.0, 835.0, .3), (505.0, 770.0, .6), (860.0, 1290.0, .15), (150.0, 1275.0, .75), (640.0, 700.0, .45)];

  /// 흩날리는 꽃잎 (화면 가로 비율, 시차, 이모지)
  static const _petals = [(.12, .0, '🌸'), (.34, .35, '🍃'), (.58, .6, '🌼'), (.8, .15, '🌸'), (.92, .8, '🍃')];

  /// 흘러가는 구름 (화면 세로 비율, 시차, 너비)
  static const _clouds = [(.16, .0, 150.0), (.30, .5, 110.0)];

  static double _seg(double t, double a, double b) => t <= a ? 0 : (t >= b ? 1 : Curves.easeOutCubic.transform((t - a) / (b - a)));

  @override
  Widget build(BuildContext context) {
    final w = size.width, h = size.height;
    final scale = w / _imgW > h / _imgH ? w / _imgW : h / _imgH; // cover
    final dx = (w - _imgW * scale) / 2; // 가운데 정렬(가로)
    final dy = h - _imgH * scale; // 아래 정렬(세로)
    Offset at(double x, double y) => Offset(dx + x * scale, dy + y * scale);

    final fadeIn = intro.clamp(0.0, 1.0).toDouble();

    // 간판을 훑는 빛: 반복 주기의 앞 55% 동안 왼쪽 → 오른쪽
    final shineP = loop / .55;
    final signTopLeft = at(_sign.left, _sign.top), signBottomRight = at(_sign.right, _sign.bottom);

    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(
        child: Opacity(
          opacity: fadeIn,
          child: Image.asset(AppImages.splash, fit: BoxFit.cover, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.medium),
        ),
      ),
      // 하늘을 천천히 지나가는 구름 (둥근 덩어리 세 개를 겹쳐 그린다)
      for (final c in _clouds)
        Positioned(
          left: -c.$3 + ((loop + c.$2) % 1.0) * (w + c.$3 * 2),
          top: h * c.$1,
          child: IgnorePointer(child: Opacity(opacity: .7 * fadeIn, child: _Puff(width: c.$3))),
        ),
      // 간판 위를 지나가는 빛
      if (shineP > -.2 && shineP < 1.2)
        Positioned.fromRect(
          rect: Rect.fromPoints(signTopLeft, signBottomRight),
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34 * scale),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1, -.4),
                    end: const Alignment(1, .4),
                    colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: .5), Colors.white.withValues(alpha: 0)],
                    stops: [(shineP - .14).clamp(0.0, 1.0).toDouble(), shineP.clamp(0.0, 1.0).toDouble(), (shineP + .14).clamp(0.0, 1.0).toDouble()],
                  ),
                ),
              ),
            ),
          ),
        ),
      // 간판 둘레 별빛
      for (final s in _stars)
        Builder(builder: (_) {
          final p = at(s.$1, s.$2);
          final v = (loop * 2 + s.$3) % 1.0; // 한 주기에 두 번 반짝
          final a = math.max(0.0, math.sin(v * math.pi));
          return Positioned(
            left: p.dx - 12,
            top: p.dy - 12,
            child: IgnorePointer(
              child: Opacity(
                opacity: (a * fadeIn).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(scale: .6 + .6 * a, child: const Text('✨', style: TextStyle(fontSize: 22, height: 1))),
              ),
            ),
          );
        }),
      // 흩날리는 꽃잎 (풀밭 위)
      for (final pt in _petals)
        Builder(builder: (_) {
          final v = (loop + pt.$2) % 1.0;
          final alpha = math.sin(v * math.pi);
          return Positioned(
            left: pt.$1 * w + math.sin(v * math.pi * 2) * 18,
            top: h * (.52 + v * .36),
            child: IgnorePointer(
              child: Opacity(
                opacity: (alpha * fadeIn).clamp(0.0, 1.0).toDouble(),
                child: Transform.rotate(angle: v * math.pi * 2, child: Text(pt.$3, style: const TextStyle(fontSize: 16, height: 1))),
              ),
            ),
          );
        }),
      // 간판 아래 문구: 그림 속 작은 글씨는 흐리고 구름과 겹쳐 잘 안 보여서 지우고, 같은 자리에 선명한 글씨로 다시 쓴다
      Positioned.fill(
        child: Opacity(
          opacity: _seg(intro, .45, 1),
          child: Transform.translate(offset: Offset(0, (1 - _seg(intro, .45, 1)) * 14), child: _Slogan(size: size)),
        ),
      ),
    ]);
  }
}

/// 하늘을 떠가는 작은 구름: 둥근 덩어리 세 개 + 납작한 바닥
class _Puff extends StatelessWidget {
  const _Puff({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) {
    final h = width * .45;
    Widget ball(double l, double t, double d) => Positioned(left: l, top: t, child: Container(width: d, height: d, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)));
    return SizedBox(
      width: width,
      height: h,
      child: Stack(children: [
        ball(width * .06, h * .38, h * .6),
        ball(width * .26, h * .02, h * .9),
        ball(width * .55, h * .24, h * .7),
        Positioned(left: width * .05, right: width * .04, bottom: 0, height: h * .38, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(h)))),
      ]),
    );
  }
}

/// 스플래시 그림(993×2160)의 간판 바로 아래에 놓는 "시세를 알고, 수확의 기쁨을!" 문구.
/// 그림은 BoxFit.cover + 아래 정렬이라, 같은 계산으로 그림 속 위치를 화면 좌표로 바꿔서 놓는다.
class _Slogan extends StatelessWidget {
  const _Slogan({required this.size});
  final Size size;

  static const _imgW = 993.0, _imgH = 2160.0;
  static const _centerX = 512.0, _centerY = 1300.0; // 그림 속 문구 자리 (원본 픽셀)

  @override
  Widget build(BuildContext context) {
    final w = size.width, h = size.height;
    final scale = w / _imgW > h / _imgH ? w / _imgW : h / _imgH; // cover
    final dx = (w - _imgW * scale) / 2; // 가운데 정렬(가로)
    final dy = h - _imgH * scale; // 아래 정렬(세로)
    final cx = dx + _centerX * scale, cy = dy + _centerY * scale;
    final font = (46 * scale).clamp(15.0, 24.0).toDouble();
    const text = '시세를 알고, 수확의 기쁨을!';
    final style = TextStyle(fontSize: font, fontWeight: FontWeight.w900, letterSpacing: .5, height: 1.2);
    return Stack(children: [
      Positioned(
        left: 0,
        right: 0,
        top: cy - font * .95,
        child: IgnorePointer(
          // 문구 가운데를 그림 속 원래 자리(cx)에 맞춘다
          child: Transform.translate(
            offset: Offset(cx - w / 2, 0),
            child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: font * .9, vertical: font * .25),
              decoration: BoxDecoration(
                // 구름 위에서도 글씨가 또렷하게 보이도록 아주 옅은 흰 바탕
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(font * 2),
              ),
              child: Stack(children: [
                // 흰 테두리
                Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = font * .22
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white,
                  ),
                ),
                // 진한 남색 글씨 (시안 색)
                Text(text, maxLines: 1, softWrap: false, style: style.copyWith(color: const Color(0xFF1E3F7A))),
              ]),
            ),
          ),
          ),
        ),
      ),
    ]);
  }
}
