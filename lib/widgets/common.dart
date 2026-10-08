import 'package:flutter/material.dart';

/// 시안(연두 파스텔 + 짙은 초록 버튼) 색상
class AppColors {
  static const bg = Color(0xFFF6F8EB); // 시안의 크림빛 연두 배경
  static const bg2 = Color(0xFFEAF3DC);
  static const green = Color(0xFF2F8F3E);
  static const greenDark = Color(0xFF1F6B2E);
  static const greenLight = Color(0xFFD8EDC8);
  static const ink = Color(0xFF1F3D2B);
  static const sub = Color(0xFF6B7F70);
  static const line = Color(0xFFD6E8C8);
  static const coin = Color(0xFFF4A81D);
  static const soil = Color(0xFF8A5A33);
  static const soilDark = Color(0xFF6E4524);
  static const up = Color(0xFFE5483B); // 상승: 빨강 (한국 시세 표기)
  static const down = Color(0xFF3B82E0); // 하락: 파랑
}

/// 챗GPT 시안에서 가져온 일러스트 이미지 (assets/images)
class AppImages {
  static const splash = 'assets/images/splash_bg.jpg';
  static const tutPlant = 'assets/images/tut_plant.jpg';
  static const tutGrow = 'assets/images/tut_grow.jpg';
  static const tutSell = 'assets/images/tut_sell.jpg';
  static const tutReady = 'assets/images/tut_ready.jpg';

  /// 튜토리얼 2장에서 움직이는 손가락 (tut_plant.jpg에서 오려 낸 그림)
  static const tutHand = 'assets/images/tut_hand.png';
  static const farmScene = 'assets/images/farm_scene.jpg';
  static const loginLand = 'assets/images/login_land.png';
  static const signupLand = 'assets/images/signup_land.png';
  static const leafTopRight = 'assets/images/leaf_tr.png';
  static const leafTopLeft = 'assets/images/leaf_tl.png';

  /// 스플래시가 떠 있는 동안 미리 읽어 두면 다음 화면에서 그림이 늦게 뜨지 않는다.
  static Future<void> precacheAll(BuildContext context) async {
    for (final a in const [splash, tutPlant, tutHand, tutGrow, tutSell, tutReady, farmScene, loginLand, signupLand, leafTopRight, leafTopLeft]) {
      if (!context.mounted) return;
      try {
        await precacheImage(AssetImage(a), context);
      } catch (_) {
        // 미리 읽기에 실패해도 화면에서 다시 읽으므로 무시한다.
      }
    }
  }
}

String commaNum(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String won(num v) => '${commaNum(v)}원';

/// 남은 시간 문구
String leftText(DateTime ready, DateTime now) {
  final d = ready.difference(now);
  if (d.inSeconds <= 0) return '수확 가능!';
  if (d.inHours >= 24) return '${d.inDays}일 ${d.inHours % 24}시간 남음';
  if (d.inHours >= 1) return '${d.inHours}시간 ${d.inMinutes % 60}분 남음';
  if (d.inMinutes >= 1) return '${d.inMinutes}분 ${d.inSeconds % 60}초 남음';
  return '${d.inSeconds}초 남음';
}

/// 사용자에게 보여줄 오류 문구
String errMsg(Object e) {
  if (e is StateError) return e.message;
  final s = '$e';
  if (s.contains('permission-denied')) return '권한이 없어요. Firebase 콘솔의 Firestore 보안 규칙을 확인해 주세요';
  if (s.contains('unavailable') || s.contains('network')) return '네트워크 연결을 확인해 주세요';
  return s;
}

void showMsg(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// 비동기 작업을 실행하고 실패하면 스낵바로 알린다. 성공 시 [ok]가 있으면 그 문구를 보여준다. 성공 여부를 돌려준다.
Future<bool> runGuarded(BuildContext context, Future<void> Function() job, {String? ok}) async {
  try {
    await job();
    if (ok != null) showMsg(context, ok);
    return true;
  } catch (e) {
    showMsg(context, errMsg(e));
    return false;
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.sub, fontSize: 14),
      prefixIconColor: AppColors.ink,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3ECD9))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3ECD9))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.green, width: 1.6)),
    ),
  );
}

/// 연두색 그라데이션 배경 + 모서리 잎사귀 장식
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF8FAEE), AppColors.bg, AppColors.bg2]),
        ),
        child: Stack(children: [
          Positioned(top: 0, right: 0, child: IgnorePointer(child: Image.asset(AppImages.leafTopRight, width: 58, fit: BoxFit.contain))),
          Positioned(top: 4, left: 2, child: IgnorePointer(child: Image.asset(AppImages.leafTopLeft, width: 34, fit: BoxFit.contain))),
          Positioned.fill(child: child),
        ]),
      );
}

/// 상단 제목줄. [onBack]이 있으면 뒤로가기 버튼을 보여준다.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.onBack, this.trailing, this.center = true, this.leading});
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? leading;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: SizedBox(
        height: 44,
        child: Row(children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.ink))
          else
            const SizedBox(width: 8),
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(child: center && onBack != null ? Center(child: titleText) : titleText),
          if (trailing != null) trailing! else if (center && onBack != null) const SizedBox(width: 48),
        ]),
      ),
    );
  }
}

/// 흰색 반투명 카드
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return box;
  }
}

/// 짙은 초록 둥근 버튼
class GreenButton extends StatelessWidget {
  const GreenButton({super.key, required this.label, required this.onPressed, this.loading = false, this.outlined = false, this.icon, this.height = 48});
  final String label;
  final VoidCallback? onPressed;
  final bool loading, outlined;
  final Widget? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: outlined ? AppColors.green : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)); // 시안의 알약 모양 버튼
    return SizedBox(
      width: double.infinity,
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                backgroundColor: Colors.white,
                elevation: 1.5,
                shadowColor: AppColors.green.withValues(alpha: .25),
                side: const BorderSide(color: Color(0xFFE3ECD9)),
                shape: shape,
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.green.withValues(alpha: .4),
                disabledForegroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.greenDark.withValues(alpha: .4),
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

/// 시안의 알약 모양 탭 (선택되면 초록색)
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.green : Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: i == index ? AppColors.green : AppColors.line),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: i == index ? Colors.white : AppColors.sub)),
                ),
              ),
            ),
          ),
      ]);
}

class ThinBar extends StatelessWidget {
  const ThinBar({super.key, required this.value, this.color = AppColors.green, this.height = 8, this.track});
  final double value;
  final Color color;
  final double height;
  final Color? track;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: height, color: color, backgroundColor: track ?? AppColors.greenLight),
      );
}

class MoneyPill extends StatelessWidget {
  const MoneyPill({super.key, required this.money});
  final int money;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 6),
          Text('${commaNum(money)} 원', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );
}

/// 시안의 금화 아이콘 (동그란 금색 동전)
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFE07A), Color(0xFFF6B21B), Color(0xFFE08A00)]),
          border: Border.all(color: const Color(0xFFD98200), width: size * .06),
          boxShadow: [BoxShadow(color: const Color(0xFFE08A00).withValues(alpha: .35), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Container(
          width: size * .56,
          height: size * .56,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFF1B8).withValues(alpha: .9), width: size * .06)),
        ),
      );
}

/// 구글 로그인 버튼의 4색 G
class GoogleG extends StatelessWidget {
  const GoogleG({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const SweepGradient(
          colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFF4285F4), Color(0xFFEA4335)],
          stops: [0.0, 0.25, 0.45, 0.62, 0.9, 1.0],
          startAngle: 3.6,
          endAngle: 3.6 + 6.283,
        ).createShader(r),
        child: Text('G', style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1, color: Colors.white)),
      );
}

/// 그림 카드: 이미지 비율을 지키며 둥근 모서리로 보여주고, [overlay]를 같은 크기로 위에 얹는다.
class IllustCard extends StatelessWidget {
  const IllustCard({super.key, required this.asset, required this.aspect, this.overlay, this.radius = 20});
  final String asset;
  final double aspect;
  final Widget? overlay;
  final double radius;
  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 3),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                if (overlay != null) overlay!,
              ]),
            ),
          ),
        ),
      );
}

class PointPill extends StatelessWidget {
  const PointPill({super.key, required this.points});
  final int points;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('⭐', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text('${commaNum(points)} P', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );
}

/// 이모지를 둥근 배경에 담은 아이콘
class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.emoji, {super.key, this.size = 44, this.color});
  final String emoji;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color ?? AppColors.greenLight.withValues(alpha: .7), shape: BoxShape.circle),
        child: Text(emoji, style: TextStyle(fontSize: size * .55, height: 1)),
      );
}

/// ▲ 12.4% 같은 등락 표시
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.percent, this.amount});
  final double? percent;
  final double? amount;
  @override
  Widget build(BuildContext context) {
    if (percent == null && amount == null) return const SizedBox.shrink();
    final v = percent ?? amount ?? 0;
    // 0.0%(소수 첫째 자리에서 0)는 오르지도 내리지도 않은 "보합": 회색 – 로 보여준다
    final flat = percent != null ? percent!.abs() < 0.05 : v.abs() < 0.5;
    if (flat) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('–', style: TextStyle(color: AppColors.sub, fontSize: 13, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(width: 4),
        Text(percent != null ? '0.0%' : '0원', style: const TextStyle(color: AppColors.sub, fontWeight: FontWeight.w800, fontSize: 13)),
      ]);
    }
    final up = v > 0;
    final color = up ? AppColors.up : AppColors.down;
    final label = percent != null ? '${up ? '+' : ''}${percent!.toStringAsFixed(1)}%' : won(amount!.abs());
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(up ? '▲' : '▼', style: TextStyle(color: color, fontSize: 10, height: 1)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
    ]);
  }
}

/// 섹션 제목
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// 시안의 프로필 아바타: 노란 원 + 흰 테두리 안의 농부
class FarmerAvatar extends StatelessWidget {
  const FarmerAvatar({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFFFFF0A8), Color(0xFFFFD34E)]),
          border: Border.all(color: Colors.white, width: size * .06),
          boxShadow: [BoxShadow(color: const Color(0xFFE0A800).withValues(alpha: .3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text('👩‍🌾', style: TextStyle(fontSize: size * .56, height: 1)),
      );
}

/// 글자를 한 줄 입력받는 대화상자. 취소하면 null.
///
/// 컨트롤러를 대화상자 위젯 안에서 만들고 정리한다. 예전처럼 showDialog가 끝나자마자 바깥에서 dispose하면
/// 닫히는 애니메이션 동안 아직 남아 있는 입력칸이 정리된 컨트롤러를 써서
/// "'_dependents.isEmpty': is not true" 빨간 화면이 떴다.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? message,
  String okLabel = '저장',
  int? maxLength,
  TextInputType? keyboardType,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(title: title, initial: initial, hint: hint, message: message, okLabel: okLabel, maxLength: maxLength, keyboardType: keyboardType),
    );

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({required this.title, required this.initial, required this.okLabel, this.hint, this.message, this.maxLength, this.keyboardType});
  final String title, initial, okLabel;
  final String? hint, message;
  final int? maxLength;
  final TextInputType? keyboardType;
  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(_c.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.message != null) ...[Text(widget.message!, style: const TextStyle(fontSize: 13)), const SizedBox(height: 12)],
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType ?? TextInputType.text,
            textInputAction: TextInputAction.done,
            // 한글 조합 입력이 끊기지 않도록 자동 수정·추천을 끈다
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (_) => _ok(),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          TextButton(onPressed: _ok, child: Text(widget.okLabel)),
        ],
      );
}
