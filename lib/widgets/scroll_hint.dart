import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';
import 'crop_art.dart';

/// 농장 첫 화면 아래쪽에 떠 있는 예쁜 알림창: "아래로 내리면 작물 관리가 있어요!"
/// - 배추 그림 + 안내 글 + 통통 튀는 아래 화살표
/// - 누르면 [scrollTo] 위치(작물 관리 버튼)까지 부드럽게 내려간다
/// - 조금이라도 아래로 내리면 사라지고, 맨 위로 돌아오면 다시 보인다
/// - × 를 누르면 앱을 다시 켤 때까지 숨긴다
/// 가장 가까운 스크롤(ListView) 안에 있어야 한다. 스크롤이 없으면 누르기만 안 된다.
class FarmScrollHint extends StatefulWidget {
  const FarmScrollHint({super.key, required this.scrollTo});
  final double scrollTo;

  /// × 로 닫았는지 (앱이 켜져 있는 동안 기억)
  static bool closed = false;

  @override
  State<FarmScrollHint> createState() => _FarmScrollHintState();
}

class _FarmScrollHintState extends State<FarmScrollHint> with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..addStatusListener(_onShow);
  late final CurvedAnimation _curve = CurvedAnimation(parent: _show, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

  /// 화면이 뜨고 잠깐(0.7초) 기다렸다가 올라오게 하는 시계 (Timer 대신 써서 테스트에서도 깔끔하게 정리된다)
  late final AnimationController _delay = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  ScrollPosition? _pos;
  bool _atTop = true;

  @override
  void initState() {
    super.initState();
    // 화면이 뜨고 잠깐 뒤에 아래에서 쏙 올라온다
    _delay.forward().whenCompleteOrCancel(() {
      if (mounted && _atTop && !FarmScrollHint.closed) _show.forward();
    });
  }

  /// 보일 때만 화살표가 튄다 (숨어 있을 때는 멈춰서 배터리를 아낀다)
  void _onShow(AnimationStatus s) {
    if (s == AnimationStatus.dismissed) {
      _bounce.stop();
    } else if (!_bounce.isAnimating) {
      _bounce.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_onScroll);
      _pos = pos;
      _pos?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final p = _pos;
    if (p == null || !p.hasPixels) return;
    final top = p.pixels < 40;
    if (top == _atTop) return;
    _atTop = top;
    if (FarmScrollHint.closed) return;
    if (top) {
      _show.forward();
    } else {
      _show.reverse();
    }
  }

  void _goDown() {
    final p = _pos;
    if (p == null || !p.hasContentDimensions) return;
    p.animateTo(math.min(widget.scrollTo, p.maxScrollExtent), duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
  }

  void _close() {
    FarmScrollHint.closed = true;
    _show.reverse();
  }

  @override
  void dispose() {
    _pos?.removeListener(_onScroll);
    _delay.dispose();
    _curve.dispose();
    _bounce.dispose();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _show,
      builder: (context, child) => _show.value == 0
          ? const SizedBox.shrink()
          : IgnorePointer(
              ignoring: _show.status == AnimationStatus.reverse,
              child: Opacity(
                opacity: _show.value.clamp(0.0, 1.0).toDouble(),
                child: Transform.translate(offset: Offset(0, (1 - _curve.value) * 40), child: child),
              ),
            ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Semantics(
            button: true,
            label: '아래로 내리면 작물 관리가 있어요. 눌러서 내려가기',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _goDown,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFFFF8E6)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF2C14B), width: 1.6),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF7A5200).withValues(alpha: .22), blurRadius: 16, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.white.withValues(alpha: .6), blurRadius: 2, offset: const Offset(0, -1)),
                  ],
                ),
                child: Row(children: [
                  // 배추 그림이 든 연두 동그라미
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0xFFEAF7D9), Color(0xFFBFE3A0)]),
                    ),
                    child: const CropArt(code: 'CABBAGE', size: 28),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('아래로 내리면 작물 관리가 있어요!', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink)),
                      SizedBox(height: 2),
                      Text('씨앗 심기 · 물 주기 · 수확 · 바로가기', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF6A7A5E))),
                    ]),
                  ),
                  // 통통 튀는 아래 화살표
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (_, __) {
                      final t = _bounce.value;
                      final hop = t < .5 ? math.sin(t / .5 * math.pi) : 0.0;
                      return Transform.translate(
                        offset: Offset(0, hop * 6),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3FAA52), AppColors.green]),
                            boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .35), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.white, size: 24),
                        ),
                      );
                    },
                  ),
                  // 닫기
                  SizedBox(
                    width: 30,
                    height: 34,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: '알림 닫기',
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8A8A7A)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
