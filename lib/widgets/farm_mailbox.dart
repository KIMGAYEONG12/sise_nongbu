import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

/// 우체통 색 (이름, 색). 편지 창 아래에서 고를 수 있고, 고른 색은 기기에 저장된다.
/// 파스텔 느낌의 예쁜 색 (농장 그림과 어울리게 채도를 살짝 낮췄다)
const mailboxColors = <(String, Color)>[
  ('체리', Color(0xFFEF6461)),
  ('벚꽃', Color(0xFFF6A5C5)),
  ('라벤더', Color(0xFFB79CE0)),
  ('크림', Color(0xFFFFF6E6)),
  ('하늘', Color(0xFF8ED1F2)),
  ('민트', Color(0xFF7FD6BC)),
  ('레몬', Color(0xFFFFD966)),
  ('밤하늘', Color(0xFF45415A)),
];

/// 레몬색 우체통 (깃발을 노랑 대신 빨강으로 그린다)
const _lemon = Color(0xFFFFD966);

/// 저장된 번호를 안전하게 색으로 바꾼다 (범위를 벗어나면 빨강)
Color mailboxColorOf(int index) => mailboxColors[(index >= 0 && index < mailboxColors.length) ? index : 0].$2;

/// 농장에 서 있는 작은 우체통. 새 버전이 나오면 편지가 와서 노란 깃발이 서고 빨간 숫자 1이 통통 튄다.
/// 누르면 [onTap] (편지 창 열기). 코드로 그려서 큰 화면에서도 선명하다.
class FarmMailbox extends StatefulWidget {
  const FarmMailbox({super.key, required this.hasLetter, required this.onTap, this.size = 46, this.active = true, this.color = const Color(0xFFEF6461)});
  final bool hasLetter;
  final VoidCallback onTap;
  final double size;

  /// 우체통 몸통 색
  final Color color;

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
            Positioned.fill(child: CustomPaint(painter: MailboxPainter(flagUp: widget.hasLetter, color: widget.color))),
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

/// 나무 기둥 + 둥근 지붕의 우체통 + 편지 넣는 구멍 + 옆의 노란 깃발 (편지가 있으면 서 있다)
class MailboxPainter extends CustomPainter {
  const MailboxPainter({required this.flagUp, this.color = const Color(0xFFEF6461)});
  final bool flagUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final light = color.computeLuminance() > .6; // 하양·노랑처럼 밝은 색이면 테두리를 진하게
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * .03)
      ..strokeJoin = StrokeJoin.round
      ..color = light ? const Color(0xFF6B5A4A) : Color.lerp(color, Colors.black, .55)!;
    // 바닥 그림자
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .5, h * .97), width: w * .55, height: h * .06), Paint()..color = const Color(0x33000000));
    // 나무 기둥
    final post = RRect.fromRectAndRadius(Rect.fromLTWH(w * .43, h * .5, w * .14, h * .47), Radius.circular(w * .03));
    canvas.drawRRect(post, Paint()..color = const Color(0xFF9A6B3F));
    canvas.drawRRect(post, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.2, w * .03)..color = const Color(0xFF5A3A22));
    // 우체통 몸통 (윗부분이 둥근 상자)
    final body = Path()
      ..moveTo(w * .14, h * .56)
      ..lineTo(w * .14, h * .36)
      ..arcToPoint(Offset(w * .86, h * .36), radius: Radius.circular(w * .36))
      ..lineTo(w * .86, h * .56)
      ..close();
    canvas.drawPath(body, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, .28)!, Color.lerp(color, Colors.black, light ? .12 : .2)!]).createShader(Rect.fromLTWH(0, h * .18, w, h * .4)));
    canvas.drawPath(body, line);
    // 반짝임
    canvas.drawOval(Rect.fromLTWH(w * .24, h * .27, w * .12, h * .1), Paint()..color = const Color(0x66FFFFFF));
    // 몸통 아래쪽의 작은 하트 스티커 (귀엽게)
    final hc = Offset(w * .5, h * .505), hr = w * .055;
    final heart = Path()
      ..moveTo(hc.dx, hc.dy + hr * .9)
      ..cubicTo(hc.dx - hr * 1.6, hc.dy - hr * .2, hc.dx - hr * .7, hc.dy - hr * 1.3, hc.dx, hc.dy - hr * .4)
      ..cubicTo(hc.dx + hr * .7, hc.dy - hr * 1.3, hc.dx + hr * 1.6, hc.dy - hr * .2, hc.dx, hc.dy + hr * .9)
      ..close();
    canvas.drawPath(heart, Paint()..color = light ? const Color(0xFFF28FA8) : Colors.white.withValues(alpha: .9));
    // 편지 넣는 구멍
    final slot =RRect.fromRectAndRadius(Rect.fromLTWH(w * .32, h * .42, w * .36, h * .045), Radius.circular(h * .02));
    canvas.drawRRect(slot, Paint()..color = const Color(0xFF3A2620));
    // 편지가 있으면 흰 봉투 끝이 구멍 위로 살짝 보인다
    if (flagUp) {
      final env = Rect.fromLTWH(w * .36, h * .37, w * .28, h * .065);
      canvas.drawRect(env, Paint()..color = Colors.white);
      canvas.drawRect(env, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, w * .02)..color = const Color(0xFF6B5A4A));
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
    // 우체통이 노란색이면 깃발은 빨간색으로 (눈에 띄게)
    canvas.drawPath(flag, Paint()..color = color == _lemon ? const Color(0xFFE5483F) : const Color(0xFFFFC93C));
    canvas.drawPath(flag, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, w * .02)..color = const Color(0xFF6B5A4A));
    canvas.restore();
  }

  @override
  bool shouldRepaint(MailboxPainter old) => old.flagUp != flagUp || old.color != color;
}

/// 우체통을 눌렀을 때 아래에서 올라오는 편지 창 (업데이트 사전 안내).
/// 새 버전이 있으면 "지금 업데이트하기", 없으면 빈 우체통 안내. 아래에서 우체통 색을 고를 수 있다.
Future<void> showMailboxLetter(
  BuildContext context, {
  required bool hasLetter,
  required Future<void> Function() onUpdate,
  int colorIndex = 0,
  ValueChanged<int>? onColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) {
      var picked = colorIndex;
      return StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: SingleChildScrollView(
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
                    Text(hasLetter ? '농부님께 편지가 도착했어요' : '아직 도착한 편지가 없어요', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      hasLetter
                          ? '새로운 버전이 준비되었습니다. 업데이트해 주시면 더 편리해진 농장에서 계속 즐겁게 농사지으실 수 있어요.'
                          : '새 버전이 나오면 이 우체통으로 가장 먼저 알려 드릴게요. 늘 찾아 주셔서 감사합니다.',
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF3D4A40)),
                    ),
                  ]),
                ),
              ]),
              if (hasLetter) ...[
                const SizedBox(height: 10),
                const Text('키우시던 농장은 자동으로 안전하게 저장되니 걱정하지 않으셔도 돼요.', style: TextStyle(fontSize: 13, color: AppColors.greenDark, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              if (hasLetter) ...[
                GreenButton(
                  label: '지금 업데이트하기',
                  height: 52,
                  icon: const Icon(Icons.system_update_rounded, size: 20),
                  onPressed: () async {
                    Navigator.of(sheet).pop();
                    await onUpdate();
                  },
                ),
                const SizedBox(height: 6),
                TextButton(onPressed: () => Navigator.of(sheet).pop(), child: const Text('다음에 할게요', style: TextStyle(color: Color(0xFF3D4A40), fontWeight: FontWeight.w700))),
              ] else
                GreenButton(label: '확인했어요', height: 52, outlined: true, onPressed: () => Navigator.of(sheet).pop()),
              if (onColor != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text('우체통 색을 골라 주세요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (var i = 0; i < mailboxColors.length; i++)
                    Semantics(
                      button: true,
                      selected: picked == i,
                      label: '우체통 색 ${mailboxColors[i].$1}',
                      child: GestureDetector(
                        onTap: () {
                          setSheet(() => picked = i);
                          onColor(i);
                        },
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: mailboxColors[i].$2,
                              shape: BoxShape.circle,
                              border: Border.all(color: picked == i ? AppColors.greenDark : const Color(0xFFCFCBC0), width: picked == i ? 3 : 1.2),
                            ),
                            child: picked == i ? Icon(Icons.check_rounded, size: 20, color: mailboxColors[i].$2.computeLuminance() > .6 ? AppColors.greenDark : Colors.white) : null,
                          ),
                          const SizedBox(height: 3),
                          Text(mailboxColors[i].$1, style: const TextStyle(fontSize: 11, color: Color(0xFF3D4A40), fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ]),
              ],
            ]),
          ),
        ),
      );
    },
  );
}
