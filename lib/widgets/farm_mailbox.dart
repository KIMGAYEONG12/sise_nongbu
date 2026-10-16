import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

/// 농장에 서 있는 작은 빨간 우체통. 새 버전이 나오면 편지가 와서 노란 깃발이 서고 빨간 숫자 1이 통통 튄다.
/// 누르면 [onTap] (편지 창 열기). 코드로 그려서 큰 화면에서도 선명하다.
class FarmMailbox extends StatefulWidget {
  const FarmMailbox({super.key, required this.hasLetter, required this.onTap, this.size = 46, this.active = true});
  final bool hasLetter;
  final VoidCallback onTap;
  final double size;

  /// 농장 탭을 보고 있을 때만 숫자가 튄다 (배터리 아끼기)
  final bool active;

  @override
  State<FarmMailbox> createState() => _FarmMailboxState();
}

class _FarmMailboxState extends State<FarmMailbox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FarmMailbox old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.hasLetter && widget.active;
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: widget.hasLetter ? '우체통: 새 편지 1통' : '우체통',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: s * 1.3,
          height: s * 1.5,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: CustomPaint(painter: MailboxPainter(flagUp: widget.hasLetter))),
            if (widget.hasLetter)
              Positioned(
                left: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    // 한 주기 앞부분에 한 번 통 튀고 쉰다
                    final t = _c.value;
                    final hop = t < .3 ? math.sin(t / .3 * math.pi) : 0.0;
                    return Transform.translate(offset: Offset(0, -hop * s * .14), child: child);
                  },
                  child: Container(
                    width: s * .42,
                    height: s * .42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFE53935), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Text('1', style: TextStyle(color: Colors.white, fontSize: s * .24, fontWeight: FontWeight.w900, height: 1)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 나무 기둥 + 둥근 지붕의 빨간 우체통 + 편지 넣는 구멍 + 옆의 노란 깃발 (편지가 있으면 서 있다)
class MailboxPainter extends CustomPainter {
  const MailboxPainter({required this.flagUp});
  final bool flagUp;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * .03)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF5A2A1A);
    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .5, h * .97), width: w * .55, height: h * .06), Paint()..color = const Color(0x33000000));
    // 나무 기둥
    final post = RRect.fromRectAndRadius(Rect.fromLTWH(w * .43, h * .5, w * .14, h * .47), Radius.circular(w * .03));
    canvas.drawRRect(post, Paint()..color = const Color(0xFF9A6B3F));
    canvas.drawRRect(post, line);
    // 우체통 몸통 (윗부분이 둥근 상자)
    final body = Path()
      ..moveTo(w * .14, h * .56)
      ..lineTo(w * .14, h * .36)
      ..arcToPoint(Offset(w * .86, h * .36), radius: Radius.circular(w * .36))
      ..lineTo(w * .86, h * .56)
      ..close();
    canvas.drawPath(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2635A), Color(0xFFC62828)]).createShader(Rect.fromLTWH(0, h * .18, w, h * .4)));
    canvas.drawPath(body, line);
    // 반짝임
    canvas.drawOval(Rect.fromLTWH(w * .24, h * .27, w * .12, h * .1), Paint()..color = const Color(0x55FFFFFF));
    // 편지 넣는 구멍
    final slot = RRect.fromRectAndRadius(Rect.fromLTWH(w * .32, h * .42, w * .36, h * .045), Radius.circular(h * .02));
    canvas.drawRRect(slot, Paint()..color = const Color(0xFF5A1A12));
    // 편지가 있으면 흰 봉투 끝이 구멍 위로 살짝 보인다
    if (flagUp) {
      final env = Rect.fromLTWH(w * .36, h * .37, w * .28, h * .065);
      canvas.drawRect(env, Paint()..color = Colors.white);
      canvas.drawRect(env, line..strokeWidth = math.max(1, w * .02));
    }
    // 깃발: 오른쪽 옆에 달린 막대 + 노란 깃발 (편지가 있으면 위로, 없으면 옆으로 눕는다)
    final pivot = Offset(w * .88, h * .48);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(flagUp ? 0 : math.pi / 2);
    final pole = Paint()
      ..color = const Color(0xFF6B6B6B)
      ..strokeWidth = math.max(1.5, w * .04)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(0, -h * .3), pole);
    final flag = Path()
      ..moveTo(0, -h * .3)
      ..lineTo(w * .2, -h * .27)
      ..lineTo(0, -h * .2)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFFC93C));
    canvas.drawPath(flag, line..strokeWidth = math.max(1, w * .02));
    canvas.restore();
  }

  @override
  bool shouldRepaint(MailboxPainter old) => old.flagUp != flagUp;
}

/// 우체통을 눌렀을 때 아래에서 올라오는 편지 창. 새 버전이 있으면 "업데이트하기", 없으면 빈 우체통 안내.
Future<void> showMailboxLetter(BuildContext context, {required bool hasLetter, required Future<void> Function() onUpdate}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
              child: Icon(hasLetter ? Icons.mail_rounded : Icons.drafts_outlined, size: 28, color: AppColors.greenDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasLetter ? '시세 농부 편지가 왔어요' : '우체통이 비어 있어요', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(
                  hasLetter ? '새 버전이 나왔어요. 업데이트하면 더 좋아진 농장에서 이어서 농사지을 수 있어요.' : '새 버전이 나오면 여기로 편지가 와요.',
                  style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF3D4A40)),
                ),
              ]),
            ),
          ]),
          if (hasLetter) ...[
            const SizedBox(height: 10),
            const Text('농장은 자동으로 저장돼요.', style: TextStyle(fontSize: 13, color: AppColors.greenDark, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 18),
          if (hasLetter) ...[
            GreenButton(
              label: '업데이트하기',
              height: 52,
              icon: const Icon(Icons.system_update_rounded, size: 20),
              onPressed: () async {
                Navigator.of(sheet).pop();
                await onUpdate();
              },
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(sheet).pop(), child: const Text('나중에', style: TextStyle(color: Color(0xFF3D4A40), fontWeight: FontWeight.w700))),
          ] else
            GreenButton(label: '확인', height: 52, outlined: true, onPressed: () => Navigator.of(sheet).pop()),
        ]),
      ),
    ),
  );
}
