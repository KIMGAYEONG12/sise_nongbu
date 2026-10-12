import 'package:flutter/material.dart';

/// 앱 전체 글꼴 (assets/fonts/NotoSansKR.ttf)
const appFontFamily = 'NotoSansKR';

/// 시안(연두 파스텔 + 짙은 초록 버튼) 색상
class AppColors {
  static const bg = Color(0xFFF6F8EB); // 시안의 크림빛 연두 배경
  static const bg2 = Color(0xFFEAF3DC);
  static const green = Color(0xFF2F8F3E);
  static const greenDark = Color(0xFF1F6B2E);
  static const greenLight = Color(0xFFD8EDC8);
  static const ink = Color(0xFF1F3D2B);
  static const sub = Color(0xFF1F2A22); // 보조 글씨도 흐린 회색이 아니라 거의 검정(잘 보이게)
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
  static const farmScene = 'assets/images/farm_scene_design.jpg'; // ChatGPT 농장 화면 시안의 풍경을 그대로 (구 farm_scene_hd3.jpg 대신)
  // // 압축 노이즈를 줄여 곱게 다듬은 농장 그림 (원본 farm_scene.jpg와 같은 크기)

  /// 레벨 업 창 위쪽 일러스트 (시안에서 오려 낸 그림)
  static const levelupHero = 'assets/images/levelup_hero.png';

  /// 레벨 업 창 전체 일러스트 (시안에서 오려 낸 그림: 농부·간판·풀숲)
  static const levelupCard = 'assets/images/levelup_card.png';

  /// 레벨 업 창 시안 그림을 3배로 곱게 키운 것 (1062×1458). 창은 이 그림 위에 글자·버튼만 얹는다.
  static const levelupCardHd = 'assets/images/levelup_card_hd.png';

  /// 프로필 아바타: 튜토리얼 마지막 그림(밀짚모자 쓴 농부)에서 오려 낸 그림
  static const avatarGirl = 'assets/images/avatar_girl.png';
  static const loginLand = 'assets/images/login_land.png';
  static const signupLand = 'assets/images/signup_land.png';
  static const leafTopRight = 'assets/images/leaf_tr.png';
  static const leafTopLeft = 'assets/images/leaf_tl.png';

  /// 스플래시가 떠 있는 동안 미리 읽어 두면 다음 화면에서 그림이 늦게 뜨지 않는다.
  static Future<void> precacheAll(BuildContext context) async {
    for (final a in const [splash, avatarGirl, tutPlant, tutHand, tutGrow, tutSell, tutReady, farmScene, loginLand, signupLand, leafTopRight, leafTopLeft]) {
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

/// 게임 안의 돈(Point). 심사·발표에서 실제 돈으로 오해되지 않도록 '원' 대신 'P'로 보여준다.
String won(num v) => '${commaNum(v)}P';

/// 실제 도매시장 시세(kg당 가격)는 현실 가격이라 '원'으로 보여준다.
String krw(num v) => '${commaNum(v)}원';

/// 한글 낱말이 줄 끝에서 글자 단위로 끊기지 않게 "띄어쓰기에서만" 줄을 바꾸는 글자 위젯.
/// 낱말마다 [Text]를 따로 만들어 [Wrap]에 늘어놓는 방식이라 보이지 않는 특수문자를 쓰지 않는다(글꼴이 깨질 일이 없다).
/// 줄바꿈 문자는 그대로 지켜지고, 길게 이어지는 설명 문구에 쓴다.
class KoText extends StatelessWidget {
  const KoText(this.data, {super.key, this.style, this.textAlign = TextAlign.start});
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final st = DefaultTextStyle.of(context).style.merge(style);
    final size = st.fontSize ?? 14;
    final align = switch (textAlign) {
      TextAlign.center => WrapAlignment.center,
      TextAlign.end || TextAlign.right => WrapAlignment.end,
      _ => WrapAlignment.start,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in data.split('\n'))
          line.trim().isEmpty
              ? SizedBox(height: size * (st.height ?? 1.2))
              : Wrap(
                  alignment: align,
                  spacing: size * .3,
                  runSpacing: 0,
                  children: [for (final w in line.split(' ')) if (w.isNotEmpty) Text(w, style: st)],
                ),
      ],
    );
  }
}

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

/// 작물 알림 (수확·파종). 작물 그림은 붙이지 않고, 문구 끝의 이모티콘만 보여 준다. 예) "수박을 수확했어요! 🍉"
/// [cropCode]는 호출하는 쪽과 맞추기 위해 남겨 둔 값이고 화면에는 쓰지 않는다 (이모티콘은 문구에 이미 들어 있다).
void showCropMsg(BuildContext context, String cropCode, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
      behavior: SnackBarBehavior.floating,
    ));
}

/// 비동기 작업을 실행하고 실패하면 스낵바로 알린다. 성공 시 [ok]가 있으면 그 문구를 보여준다. 성공 여부를 돌려준다.
/// [okCrop]에 작물 코드를 주면 성공 문구 앞에 그 작물 그림을 붙인다.
Future<bool> runGuarded(BuildContext context, Future<void> Function() job, {String? ok, String? okCrop}) async {
  try {
    await job();
    if (ok != null && context.mounted) {
      if (okCrop != null) {
        showCropMsg(context, okCrop, ok);
      } else {
        showMsg(context, ok);
      }
    }
    return true;
  } catch (e) {
    if (context.mounted) showMsg(context, errMsg(e));
    return false;
  }
}

/// 안드로이드 12 이상의 "끝에서 당기면 화면이 늘어나는" 효과를 끈다. 스크롤은 그대로 되고 끝에서만 멈춘다.
class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    fontFamily: appFontFamily,
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
          if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.ink)) else const SizedBox(width: 8),
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
                  child: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: i == index ? Colors.white : AppColors.sub)),
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
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        // 하늘·구름 위에서도 잘 보이도록 불투명한 흰 바탕 + 진한 큰 글씨
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0A800), width: 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const CoinIcon(size: 16),
          const SizedBox(width: 4),
          Text('${commaNum(money)} P', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF111111))),
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
  const IllustCard({super.key, required this.asset, this.aspect = 1, this.overlay, this.radius = 20, this.fill = false, this.imageScale = 1.0, this.alignment = Alignment.center});
  final String asset;
  final double aspect;
  final Widget? overlay;
  final double radius;

  /// true면 그림 비율로 크기를 정하지 않고 주어진 칸을 가득 채운다 (그림은 칸을 덮도록 잘린다)
  final bool fill;

  /// 그림만 천천히 확대·축소하는 연출용 배율
  final double imageScale;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => _frame(
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .15), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 3),
            child: Stack(fit: StackFit.expand, children: [
              Transform.scale(scale: imageScale, child: Image.asset(asset, fit: BoxFit.cover, alignment: alignment, filterQuality: FilterQuality.high)),
              if (overlay != null) overlay!,
            ]),
          ),
        ),
      );

  Widget _frame(Widget child) => fill ? SizedBox.expand(child: child) : AspectRatio(aspectRatio: aspect, child: child);
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
    final label = percent != null ? '${up ? '+' : ''}${percent!.toStringAsFixed(1)}%' : krw(amount!.abs());
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

/// 프로필 아바타: 스플래시에 나오는 밀짚모자 쓴 여자 아이를 코드(벡터)로 그렸다.
/// 그림 파일이 아니라서 아무리 키워도 도트처럼 깨지지 않고 선명하다.
class FarmerAvatar extends StatelessWidget {
  const FarmerAvatar({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFFFFF0A8), Color(0xFFFFD34E)]),
          border: Border.all(color: Colors.white, width: size * .06),
          boxShadow: [BoxShadow(color: const Color(0xFFE0A800).withValues(alpha: .3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipOval(child: Image.asset(AppImages.avatarGirl, width: size, height: size, fit: BoxFit.cover, alignment: const Alignment(-.2, -.3), filterQuality: FilterQuality.high)),
      );
}

/// 밀짚모자(파란 띠)를 쓴 갈색 머리 여자 아이 (스플래시 그림의 농부).
/// 작은 크기에서도 얼굴이 또렷하게 보이도록 얼굴·눈·모자를 크게 그렸다.
class GirlAvatarPainter extends CustomPainter {
  const GirlAvatarPainter();

  static const _skin = Color(0xFFFFDDBE);
  static const _hair = Color(0xFF7B4A28);
  static const _hairDark = Color(0xFF5F3719);
  static const _straw = Color(0xFFF1D08A);
  static const _strawDark = Color(0xFFC99A4B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * s, t * s, rr * s, b * s);
    Paint fill(Color c) => Paint()..color = c;
    Paint edge(Color c, [double w = .012]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = c;

    // 몸: 흰 셔츠 위에 파란 멜빵바지
    canvas.drawOval(Rect.fromCenter(center: p(.5, 1.06), width: .96 * s, height: .6 * s), fill(const Color(0xFFFFFBF2)));
    canvas.drawRRect(RRect.fromRectAndCorners(r(.3, .86, .7, 1.1), topLeft: Radius.circular(.07 * s), topRight: Radius.circular(.07 * s)), fill(const Color(0xFF3F74CF)));
    canvas.drawRect(r(.31, .8, .39, .92), fill(const Color(0xFF3F74CF)));
    canvas.drawRect(r(.61, .8, .69, .92), fill(const Color(0xFF3F74CF)));
    canvas.drawCircle(p(.35, .91), .016 * s, fill(const Color(0xFFFFD34E)));
    canvas.drawCircle(p(.65, .91), .016 * s, fill(const Color(0xFFFFD34E)));

    // 뒤 머리 (얼굴 양옆으로 내려온다)
    final back = Path()
      ..moveTo(.2 * s, .46 * s)
      ..quadraticBezierTo(.14 * s, .8 * s, .26 * s, .86 * s)
      ..lineTo(.74 * s, .86 * s)
      ..quadraticBezierTo(.86 * s, .8 * s, .8 * s, .46 * s)
      ..close();
    canvas.drawPath(back, fill(_hairDark));

    // 목
    canvas.drawRRect(RRect.fromRectAndRadius(r(.43, .7, .57, .84), Radius.circular(.03 * s)), fill(const Color(0xFFF6C79F)));

    // 얼굴
    final face = Rect.fromCenter(center: p(.5, .56), width: .5 * s, height: .5 * s);
    canvas.drawOval(face, fill(_skin));
    canvas.drawOval(face, edge(const Color(0x33B5764A), .008));

    // 귀
    canvas.drawCircle(p(.255, .58), .034 * s, fill(_skin));
    canvas.drawCircle(p(.745, .58), .034 * s, fill(_skin));

    // 앞머리 (이마를 덮고 양옆으로 갈라진다)
    final bangs = Path()
      ..moveTo(.25 * s, .55 * s)
      ..quadraticBezierTo(.24 * s, .3 * s, .5 * s, .3 * s)
      ..quadraticBezierTo(.76 * s, .3 * s, .75 * s, .55 * s)
      ..quadraticBezierTo(.7 * s, .44 * s, .6 * s, .43 * s)
      ..quadraticBezierTo(.52 * s, .5 * s, .46 * s, .43 * s)
      ..quadraticBezierTo(.34 * s, .45 * s, .25 * s, .55 * s)
      ..close();
    canvas.drawPath(bangs, fill(_hair));

    // 눈썹 · 눈 (크고 동그랗게, 반짝이는 하이라이트)
    for (final x in [.39, .61]) {
      canvas.drawLine(p(x - .045, .5), p(x + .04, .492), edge(_hairDark, .012));
      canvas.drawOval(Rect.fromCenter(center: p(x, .585), width: .082 * s, height: .108 * s), fill(const Color(0xFF3A2216)));
      canvas.drawCircle(p(x + .013, .56), .017 * s, fill(Colors.white));
      canvas.drawCircle(p(x - .012, .61), .009 * s, fill(const Color(0xCCFFFFFF)));
    }
    // 볼 · 코 · 웃는 입
    canvas.drawCircle(p(.335, .665), .05 * s, fill(const Color(0x66FF8A78)));
    canvas.drawCircle(p(.665, .665), .05 * s, fill(const Color(0x66FF8A78)));
    canvas.drawCircle(p(.5, .63), .008 * s, fill(const Color(0x66B5764A)));
    canvas.drawPath(
      Path()
        ..moveTo(.44 * s, .685 * s)
        ..quadraticBezierTo(.5 * s, .75 * s, .56 * s, .685 * s),
      edge(const Color(0xFFB5503C), .014),
    );

    // 밀짚모자: 넓은 챙 → 둥근 윗부분 → 파란 띠 → 잎
    final brim = Rect.fromCenter(center: p(.5, .335), width: .98 * s, height: .27 * s);
    canvas.drawOval(brim, fill(_straw));
    canvas.drawOval(brim, edge(_strawDark, .012));
    final crown = Path()
      ..moveTo(.27 * s, .34 * s)
      ..quadraticBezierTo(.26 * s, .06 * s, .5 * s, .06 * s)
      ..quadraticBezierTo(.74 * s, .06 * s, .73 * s, .34 * s)
      ..close();
    canvas.drawPath(crown, fill(const Color(0xFFF7DE9C)));
    canvas.drawPath(crown, edge(_strawDark, .01));
    // 띠
    final band = Path()
      ..moveTo(.268 * s, .3 * s)
      ..lineTo(.732 * s, .3 * s)
      ..lineTo(.737 * s, .35 * s)
      ..quadraticBezierTo(.5 * s, .4 * s, .263 * s, .35 * s)
      ..close();
    canvas.drawPath(band, fill(const Color(0xFF3B70D2)));
    // 밀짚 결
    for (final x in [.38, .46, .54, .62]) {
      canvas.drawLine(p(x, .12), p(x - (.5 - x) * .25, .27), edge(const Color(0x33C99A4B), .008));
    }
    // 띠에 꽂은 잎
    canvas.save();
    canvas.translate(p(.66, .31).dx, p(.66, .31).dy);
    canvas.rotate(-.7);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: .13 * s, height: .055 * s), fill(const Color(0xFF55B23A)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(GirlAvatarPainter old) => false;
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
