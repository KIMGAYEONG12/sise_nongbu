import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';

/// 우체통 색 (이름, 색). 편지 창 아래에서 고를 수 있고, 고른 색은 기기에 저장된다.
/// 맑고 선명한 색 10가지 (첫 번째 빨강이 기본)
const mailboxColors = <(String, Color)>[
  ('빨강', Color(0xFFE8453C)),
  ('코랄', Color(0xFFFF7A6B)),
  ('핑크', Color(0xFFFF86B3)),
  ('주황', Color(0xFFFF9A3D)),
  ('노랑', Color(0xFFFFC83D)),
  ('연두', Color(0xFF7CCB5B)),
  ('민트', Color(0xFF38CDB0)),
  ('하늘', Color(0xFF4DA8F5)),
  ('보라', Color(0xFF9B7BE8)),
  ('크림', Color(0xFFFFF3DC)),
];

/// 노란색 우체통 (깃발을 노랑 대신 빨강으로 그린다)
const _lemon = Color(0xFFFFC83D);

/// 저장된 번호를 안전하게 색으로 바꾼다 (범위를 벗어나면 빨강)
Color mailboxColorOf(int index) => mailboxColors[(index >= 0 && index < mailboxColors.length) ? index : 0].$2;

/// 농장에 서 있는 작은 우체통. 새 버전이 나오면 편지가 와서 노란 깃발이 서고 빨간 숫자 1이 통통 튄다.
/// 누르면 [onTap] (편지 창 열기). 코드로 그려서 큰 화면에서도 선명하다.
class FarmMailbox extends StatefulWidget {
  const FarmMailbox({super.key, required this.hasLetter, required this.onTap, this.size = 46, this.active = true, this.color = const Color(0xFFE8453C)});
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

/// 시안의 우체통: 비스듬히 보이는 둥근 지붕 상자(앞면 편지 무늬 + 옆면) · 노란 깃발 · 나무 기둥 · 풀과 꽃.
/// [flagUp]이면 깃발이 서고 노란 알림 빛줄기가 반짝인다(편지 도착). [open]이면 앞문이 열려 편지가 보인다(편지 확인).
/// 몸통 색은 [color] 그대로 쓴다 (사용자가 고른 우체통 색 유지).
class MailboxPainter extends CustomPainter {
  const MailboxPainter({required this.flagUp, this.color = const Color(0xFFE8453C), this.open = false});
  final bool flagUp;
  final Color color;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final light = color.computeLuminance() > .6; // 하양·노랑처럼 밝은 색이면 테두리를 진하게
    final outline = light ? const Color(0xFF6B5A4A) : Color.lerp(color, Colors.black, .55)!;
    final sw = math.max(1.2, w * .026);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outline;

    // ── 땅: 그림자 + 풀 언덕 ──
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .48, h * .955), width: w * .78, height: h * .07), Paint()..color = const Color(0x2E000000));
    final mound = Rect.fromCenter(center: Offset(w * .48, h * .935), width: w * .74, height: h * .09);
    canvas.drawOval(mound, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8FD46A), Color(0xFF55A845)]).createShader(mound));

    // ── 나무 기둥 (나뭇결 + 아래 받침) ──
    final post = RRect.fromRectAndRadius(Rect.fromLTWH(w * .38, h * .56, w * .13, h * .38), Radius.circular(w * .025));
    canvas.drawRRect(post, Paint()..shader = const LinearGradient(colors: [Color(0xFFB98552), Color(0xFF8E5E33), Color(0xFF6E4524)], stops: [0, .55, 1]).createShader(post.outerRect));
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, w * .012)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5E3A1C).withValues(alpha: .55);
    canvas.drawLine(Offset(w * .415, h * .64), Offset(w * .415, h * .74), grain);
    canvas.drawLine(Offset(w * .47, h * .7), Offset(w * .47, h * .86), grain);
    canvas.drawRRect(post, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..color = const Color(0xFF4E2F17));
    // 상자 받침 나무판
    final shelf = RRect.fromRectAndRadius(Rect.fromLTWH(w * .26, h * .575, w * .44, h * .045), Radius.circular(w * .02));
    canvas.drawRRect(shelf, Paint()..color = const Color(0xFF9A6A3D));
    canvas.drawRRect(shelf, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .9..color = const Color(0xFF4E2F17));

    // ── 우체통 몸통 (앞면 아치 + 오른쪽 위로 이어지는 옆면) ──
    final l = w * .1, r = w * .54, b = h * .6;
    final rad = (r - l) / 2;
    final cy = h * .4;
    final c = Offset(l + rad, cy);
    final d = Offset(w * .3, -h * .07); // 앞면 → 뒷면
    final dl = d.distance;
    final nUp = Offset(d.dy / dl, -d.dx / dl); // 옆면 윗선이 앞면 둥근 지붕에 닿는 방향
    final aUp = math.atan2(nUp.dy, nUp.dx);
    final p1 = c + nUp * rad;
    final side = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p1.dx + d.dx, p1.dy + d.dy)
      ..arcTo(Rect.fromCircle(center: c + d, radius: rad), aUp, -aUp, false)
      ..lineTo(r + d.dx, b + d.dy)
      ..lineTo(r, b)
      ..lineTo(c.dx, c.dy)
      ..close();
    final sideRect = Rect.fromLTRB(l, cy - rad + d.dy, r + d.dx, b);
    final base = color;
    canvas.drawPath(side, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.white, .1)!, Color.lerp(base, Colors.black, light ? .14 : .26)!]).createShader(sideRect));
    // 옆면 위쪽의 둥근 광택 띠
    canvas.save();
    canvas.clipPath(side);
    final gloss = Path()
      ..moveTo(p1.dx + nUp.dx * -rad * .2, p1.dy + nUp.dy * -rad * .2)
      ..lineTo(p1.dx + d.dx + nUp.dx * -rad * .2, p1.dy + d.dy + nUp.dy * -rad * .2);
    canvas.drawPath(gloss, Paint()..style = PaintingStyle.stroke..strokeWidth = rad * .22..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: .35));
    // 옆면의 테 두 줄 (철판 이음새)
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * .016)
      ..color = Color.lerp(base, Colors.black, .3)!.withValues(alpha: .6);
    for (final t in [.35, .7]) {
      final o = d * t;
      canvas.drawArc(Rect.fromCircle(center: c + o, radius: rad), aUp, -aUp, false, rib);
      canvas.drawLine(Offset(r + o.dx, cy + o.dy), Offset(r + o.dx, b + o.dy), rib);
    }
    canvas.restore();
    canvas.drawPath(side, line);

    // 앞면
    final front = Path()
      ..moveTo(l, b)
      ..lineTo(l, cy)
      ..arcTo(Rect.fromCircle(center: c, radius: rad), math.pi, math.pi, false)
      ..lineTo(r, b)
      ..close();
    final frontRect = Rect.fromLTRB(l, cy - rad, r, b);
    canvas.drawPath(front, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(base, Colors.white, .28)!, base, Color.lerp(base, Colors.black, light ? .08 : .14)!], stops: const [0, .45, 1]).createShader(frontRect));
    canvas.drawPath(front, line);

    // 앞문: 안쪽 아치 테두리 (열렸으면 어두운 속 + 편지, 문은 아래로 내려온다)
    final inset = rad * .16;
    final door = Path()
      ..moveTo(l + inset, b - inset * .6)
      ..lineTo(l + inset, cy)
      ..arcTo(Rect.fromCircle(center: c, radius: rad - inset), math.pi, math.pi, false)
      ..lineTo(r - inset, b - inset * .6)
      ..close();
    final ink = light ? const Color(0xFF6B5A4A) : Color.lerp(base, Colors.black, .45)!;
    if (open) {
      canvas.drawPath(door, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.black, .62)!, Color.lerp(base, Colors.black, .4)!]).createShader(frontRect));
      // 안에 든 편지 (분홍 하트 봉인)
      final er = Rect.fromCenter(center: Offset(c.dx, b - rad * .55), width: rad * 1.25, height: rad * .82);
      canvas.save();
      canvas.translate(er.center.dx, er.center.dy);
      canvas.rotate(-.12);
      canvas.translate(-er.center.dx, -er.center.dy);
      _envelope(canvas, er, ink, heart: true);
      canvas.restore();
      // 아래로 열린 문짝
      final flap = Path()
        ..moveTo(l + inset * .4, b)
        ..lineTo(r - inset * .4, b)
        ..lineTo(r + rad * .12, b + h * .1)
        ..lineTo(l - rad * .12, b + h * .1)
        ..close();
      canvas.drawPath(flap, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.black, .05)!, Color.lerp(base, Colors.white, .2)!]).createShader(Rect.fromLTRB(l, b, r, b + h * .1)));
      canvas.drawPath(flap, line);
    } else {
      canvas.drawPath(door, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .8..color = ink.withValues(alpha: .7));
      // 앞면 가운데 흰 편지 봉투 무늬
      _envelope(canvas, Rect.fromCenter(center: Offset(c.dx, cy + rad * .28), width: rad * 1.05, height: rad * .7), ink);
      // 문 손잡이
      canvas.drawCircle(Offset(c.dx, cy - rad * .62), rad * .09, Paint()..color = const Color(0xFFFFD45A));
      canvas.drawCircle(Offset(c.dx, cy - rad * .62), rad * .09, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .6..color = ink);
    }
    // 앞면 왼쪽 위 반짝임
    canvas.drawArc(Rect.fromCircle(center: c, radius: rad * .78), math.pi * 1.1, math.pi * .32, false,
        Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = rad * .12..color = Colors.white.withValues(alpha: .55));

    // ── 깃발: 옆면에 달린 막대 + 노란 깃발 (편지가 있으면 서고, 없으면 옆으로 눕는다) ──
    final pivot = Offset(r + d.dx * .72, cy + d.dy * .72 + rad * .1);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(flagUp ? 0 : aUp); // 내려가면 옆면을 따라 앞쪽으로 눕는다
    final poleLen = flagUp ? h * .32 : h * .22;
    canvas.drawLine(Offset.zero, Offset(0, -poleLen), Paint()..color = const Color(0xFF5E5E5E)..strokeWidth = math.max(1.6, w * .04)..strokeCap = StrokeCap.round);
    final flag = Path()
      ..moveTo(0, -poleLen)
      ..lineTo(w * .2, -poleLen)
      ..lineTo(w * .15, -poleLen + h * .055)
      ..lineTo(w * .2, -poleLen + h * .11)
      ..lineTo(0, -poleLen + h * .11)
      ..close();
    final flagColor = color == _lemon ? const Color(0xFFE5483F) : const Color(0xFFFFC93C);
    canvas.drawPath(flag, Paint()..shader = LinearGradient(colors: [Color.lerp(flagColor, Colors.white, .25)!, flagColor]).createShader(Rect.fromLTWH(0, -poleLen, w * .2, h * .11)));
    canvas.drawPath(flag, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * .8..strokeJoin = StrokeJoin.round..color = const Color(0xFF7A5A1E));
    canvas.drawCircle(Offset.zero, w * .03, Paint()..color = const Color(0xFF5E5E5E));
    canvas.restore();

    // 편지 도착 알림: 깃발 옆 노란 빛줄기 세 개
    if (flagUp && !open) {
      final ray = Paint()
        ..color = const Color(0xFFFFC21A)
        ..strokeWidth = math.max(1.6, w * .035)
        ..strokeCap = StrokeCap.round;
      final o = Offset(pivot.dx + w * .14, pivot.dy - poleLen - h * .02);
      for (final a in [-1.15, -.55, .05]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(o + dir * w * .07, o + dir * w * .15, ray);
      }
    }

    // ── 기둥 아래 풀잎과 꽃 (하얀 데이지 + 노란 꽃) ──
    final blade = Paint()..color = const Color(0xFF4E9E3E);
    for (final x in [.2, .27, .34, .55, .62, .7, .76]) {
      final bx = w * x, by = h * .93;
      final g = Path()
        ..moveTo(bx - w * .022, by)
        ..quadraticBezierTo(bx - w * .01, by - h * .05, bx + w * .012, by - h * .07)
        ..quadraticBezierTo(bx + w * .004, by - h * .03, bx + w * .022, by)
        ..close();
      canvas.drawPath(g, blade);
    }
    _flower(canvas, Offset(w * .25, h * .9), w * .042, Colors.white);
    _flower(canvas, Offset(w * .66, h * .895), w * .046, Colors.white);
    _flower(canvas, Offset(w * .74, h * .925), w * .032, const Color(0xFFFFD43B));
    _flower(canvas, Offset(w * .32, h * .93), w * .028, const Color(0xFFFFD43B));
  }

  /// 흰 편지 봉투 (뚜껑 V선, [heart]면 분홍 하트 봉인)
  static void _envelope(Canvas canvas, Rect er, Color ink, {bool heart = false}) {
    final rr = RRect.fromRectAndRadius(er, Radius.circular(er.height * .1));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFFBF2));
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, er.width * .05)
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    canvas.drawRRect(rr, st);
    final v = Path()
      ..moveTo(er.left + er.width * .04, er.top + er.height * .1)
      ..lineTo(er.center.dx, er.top + er.height * .6)
      ..lineTo(er.right - er.width * .04, er.top + er.height * .1);
    canvas.drawPath(v, st);
    if (heart) {
      final hc = Offset(er.center.dx, er.top + er.height * .6);
      final hr = er.height * .2;
      final hp = Path()
        ..moveTo(hc.dx, hc.dy + hr * .9)
        ..cubicTo(hc.dx - hr * 1.6, hc.dy - hr * .1, hc.dx - hr * .6, hc.dy - hr * 1.3, hc.dx, hc.dy - hr * .35)
        ..cubicTo(hc.dx + hr * .6, hc.dy - hr * 1.3, hc.dx + hr * 1.6, hc.dy - hr * .1, hc.dx, hc.dy + hr * .9)
        ..close();
      canvas.drawPath(hp, Paint()..color = const Color(0xFFFF6F91));
    }
  }

  /// 꽃잎 5장 꽃
  static void _flower(Canvas canvas, Offset c, double r, Color petal) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, r * .72, Paint()..color = petal);
    }
    canvas.drawCircle(c, r * .62, Paint()..color = petal == Colors.white ? const Color(0xFFFFC93C) : const Color(0xFFF08A24));
  }

  @override
  bool shouldRepaint(MailboxPainter old) => old.flagUp != flagUp || old.color != color || old.open != open;
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
                // 시안: 편지가 오면 노란 빛이 퍼지는 동그라미 안에 문이 열린 우체통(편지 확인), 없으면 닫힌 우체통
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: hasLetter ? const [Color(0xFFFFF4C2), Color(0xFFFFE08A)] : const [Color(0xFFF1F7E8), AppColors.greenLight]),
                    boxShadow: hasLetter ? [BoxShadow(color: const Color(0xFFFFC93C).withValues(alpha: .45), blurRadius: 14, spreadRadius: 1)] : null,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: CustomPaint(painter: MailboxPainter(flagUp: hasLetter, open: hasLetter, color: mailboxColorOf(picked))),
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
