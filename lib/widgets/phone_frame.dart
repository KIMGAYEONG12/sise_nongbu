import 'package:flutter/material.dart';

/// 웹에서 화면이 넓을 때(PC) 앱을 휴대폰 테두리 안에 보여준다.
/// 폭이 좁은 화면(실제 휴대폰)에서는 아무것도 바꾸지 않는다.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const double _bezel = 10;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 600) return child;

    final screenH = (mq.size.height - 40 - _bezel * 2).clamp(480.0, 860.0).toDouble();
    final screenW = (screenH * 0.5).clamp(300.0, 420.0).toDouble();
    final inner = Size(screenW, screenH);

    return ColoredBox(
      color: const Color(0xFFE8EEE4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(_bezel),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(46),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: SizedBox.fromSize(
              size: inner,
              child: MediaQuery(
                data: mq.copyWith(size: inner),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
