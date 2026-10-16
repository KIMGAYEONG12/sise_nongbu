import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';

/// 5장짜리 튜토리얼 (시세 확인 → 파종 → 성장 → 판매 → 시작). 장마다 움직이는 연출이 있고,
/// 2~4장은 누구나 직접 눌러 체험할 수 있다 (연습용이라 로그인 전에도 되고 실제 게임 데이터는 바뀌지 않는다).
/// 2~5장 그림은 챗GPT 시안 일러스트(assets/images)를 쓰고, 움직이는 부분(손가락·+칸·카드·버튼)은 코드로 그 위에 올린다.
class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

/// 튜토리얼 4장(판매하기)에 보여줄 연습용 배추 시세 (시안과 같은 1,850원/kg, 전날보다 오름 ▲)
final _demoCabbage =
    AuctionPrice('CABBAGE', 1850, DateTime(2026, 10, 7), prevPerKg: 1650);

class _TutorialPageState extends ConsumerState<TutorialPage>
    with SingleTickerProviderStateMixin {
  final _ctrl = PageController();
  int _i = 0;
  static const _total = 5;

  /// 튜토리얼 그림 틀의 가로÷세로 비율 (1~5장 모두 같다)
  static const _frameAspect = 0.86;

  /// 제목+설명 영역의 기본 높이 (제목 1줄 + 설명 최대 3줄). 글씨 배율이 커지면 같이 커진다.
  static const _headerBase = 112.0;

  /// 마지막 장의 '시작하기' 버튼이 숨쉬듯 커졌다 작아지는 연출
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _breathScale = Tween(begin: 1.0, end: 1.04)
      .animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));

  static const _titles = [
    '시세를 확인해보세요!',
    '밭에 작물을 심어보세요!',
    '작물이 자라요!',
    '시세를 보고 판매해보세요!',
    '농부가 될 준비 완료!',
  ];
  static const _subs = [
    '농산물 가격은 실시간으로 변동됩니다.\n가격이 높을 때 판매하면 더 많은 수익을 얻을 수 있어요.',
    '빈 밭을 눌러 원하는 작물을 심고\n정성껏 키워주세요.',
    '시간이 지나면 작물이 성장하고,\n수확할 수 있게 됩니다.',
    '시세를 확인하고, 가격이 높을 때\n판매하면 더 많은 수익을 얻을 수 있어요.',
    '미션과 업적을 달성하면 포인트를 받아요.\n이제 나만의 농장을 키워볼까요?',
  ];

  @override
  void dispose() {
    _breath.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onPage(int v) {
    setState(() => _i = v);
    if (v == _total - 1) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  void _next() {
    if (_i >= _total - 1) {
      widget.onDone();
    } else {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_i > 0) {
      _ctrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              // 시안: 왼쪽 < , 가운데 "튜토리얼 n/5", 오른쪽 건너뛰기
              SizedBox(
                width: double.infinity, // 폭을 화면 전체로 잡아야 < 와 건너뛰기가 양 끝에 붙는다
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  if (_i > 0)
                    Positioned(
                      left: 4,
                      child: IconButton(
                          onPressed: _back,
                          icon: const Icon(Icons.chevron_left_rounded,
                              size: 32, color: AppColors.ink)),
                    ),
                  Text('튜토리얼 ${_i + 1} / $_total',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3D4A40))),
                  Positioned(
                    right: 8,
                    child: TextButton(
                        onPressed: widget.onDone,
                        child: const Text('건너뛰기',
                            style: TextStyle(
                                color: AppColors.sub,
                                fontWeight: FontWeight.w600))),
                  ),
                ]),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _total,
                  onPageChanged: _onPage,
                  // 1~5장 모두 똑같은 틀: 제목(1줄)·설명(2줄) 높이가 고정이라 그림 틀의 위치·크기가 장마다 완전히 같다.
                  // 지금 보고 있는 장(active)일 때만 움직이고, 다시 들어오면 처음부터 다시 움직인다.
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                    child: LayoutBuilder(builder: (context, box) {
                      final headerH = _headerBase *
                          math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0)) *
                          1.08; // 여유 8%: 글씨가 커져도 노란 줄무늬(넘침)가 안 생기게
                      final frameH = math.max(
                          0.0,
                          math.min(box.maxHeight - headerH,
                              box.maxWidth / _frameAspect));
                      // 화면이 세로로 길면 남는 공간은 위아래로 나눠서 글+그림 덩어리가 위쪽 가까이에 놓이게 한다
                      final top = math.max(
                          0.0, (box.maxHeight - headerH - frameH) * .3);
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: top),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                              height: headerH,
                              child: Column(children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_titles[i],
                                      style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1C2B20))),
                                ),
                                const SizedBox(height: 10),
                                KoText(_subs[i],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        color: Color(0xFF1C2B20),
                                        height: 1.55,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            SizedBox(
                                key: ValueKey('tutorialFrame$i'),
                                width: box.maxWidth,
                                height: frameH,
                                child: _Visual(index: i, active: i == _i)),
                          ]),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: ScaleTransition(
                  scale: _breathScale,
                  child: GreenButton(
                      label: _i == _total - 1 ? '시작하기' : '다음',
                      height: 52,
                      onPressed: _next),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _i ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= _i
                            ? AppColors.green
                            : const Color(0xFFD3DCCB)),
                  ),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      );
}

class _Visual extends ConsumerWidget {
  const _Visual({required this.index, required this.active});
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        return _PriceCard(
            prices: ref.watch(marketViewModelProvider).valueOrNull,
            active: active);
      case 1:
        return _PlantVisual(active: active);
      case 2:
        return _GrowVisual(active: active);
      case 3:
        return _SellVisual(price: _demoCabbage, active: active);
      default:
        return _ReadyVisual(active: active);
    }
  }
}

/// 움직이는 장의 공통 틀: 들어올 때 한 번 재생하는 [intro]와 계속 반복하는 [loop].
/// 보고 있지 않은 장은 멈춰서 배터리를 아낀다.
abstract class _AnimState<T extends StatefulWidget> extends State<T>
    with TickerProviderStateMixin<T> {
  late final AnimationController intro =
      AnimationController(vsync: this, duration: introDuration);
  late final AnimationController loop =
      AnimationController(vsync: this, duration: loopDuration);

  Duration get introDuration;
  Duration get loopDuration;
  bool get active;

  @override
  void initState() {
    super.initState();
    if (active) _play();
  }

  void _play() {
    intro.forward(from: 0);
    loop.repeat();
  }

  void _stop() {
    intro.stop();
    loop.stop();
  }

  void syncActive(bool was) {
    if (active && !was) _play();
    if (!active && was) _stop();
  }

  @override
  void dispose() {
    intro.dispose();
    loop.dispose();
    super.dispose();
  }
}

/// 0~1 진행값 [t]에서 [a]~[b] 구간만 0~1로 늘린 값 (곡선 적용)
double _seg(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return curve.transform((t - a) / (b - a));
}

// ───────────────────────── 1. 시세 확인 ─────────────────────────

/// 오늘의 시세 카드: 줄이 위에서부터 하나씩 스르륵 나타나고, 가격은 0에서 촤라락 올라가고, ▲▼는 통통 튄다.
class _PriceCard extends StatefulWidget {
  const _PriceCard({required this.prices, required this.active});
  final Map<String, AuctionPrice>? prices;
  final bool active;
  @override
  State<_PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends _AnimState<_PriceCard> {
  /// 눌러서 고른 줄 (누르면 초록색으로 강조되고 가격이 다시 촤라락 올라간다)
  int? _sel;

  /// 누른 품목의 시세 설명 (전일 대비 오름/내림/보합)
  String _hint(List<CropSpec> list) {
    final k = _sel;
    if (k == null) return '👆 품목을 눌러 보세요';
    final c = list[k];
    final pr = widget.prices?[c.code];
    final pct = pr == null ? null : changePercent(pr.pricePerKg, pr.prevPerKg);
    if (pct == null) return '${c.label}: 시세를 불러오는 중이에요';
    if (pct.abs() < 0.05) {
      return '${c.label}: 어제와 같아요 – 급하지 않으면 기다려 봐요';
    }
    return pct > 0
        ? '${c.label}: 어제보다 ${pct.toStringAsFixed(1)}% 올랐어요 ▲ 지금 팔면 이득이에요'
        : '${c.label}: 어제보다 ${pct.abs().toStringAsFixed(1)}% 내렸어요 ▼ 오를 때까지 보관해 봐요';
  }

  @override
  Duration get introDuration => const Duration(milliseconds: 1800);
  @override
  Duration get loopDuration => const Duration(milliseconds: 2400);
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(_PriceCard old) {
    super.didUpdateWidget(old);
    syncActive(old.active);
  }

  @override
  Widget build(BuildContext context) {
    final list = crops.take(5).toList();
    return AnimatedBuilder(
      animation: Listenable.merge([intro, loop]),
      builder: (_, __) {
        final t = intro.value;
        return SizedBox.expand(
            child: SoftCard(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Opacity(
              opacity: _seg(t, 0, .15),
              child: const Row(children: [
                Icon(Icons.trending_up_rounded, size: 20, color: AppColors.ink),
                SizedBox(width: 8),
                Text('오늘의 시세',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 8),
            for (var k = 0; k < list.length; k++) ...[
              Expanded(child: Builder(builder: (_) {
                final c = list[k];
                final p = widget.prices?[c.code];
                final pct =
                    p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
                // 줄마다 0.12초씩 늦게 등장
                final show = _seg(t, .08 + k * .1, .38 + k * .1);
                final count = _seg(t, .12 + k * .1, .7 + k * .06);
                // ▲▼: 처음엔 통 튀어나오고, 그 뒤로는 2.4초마다 한 번씩 살짝 통통
                final pop =
                    _seg(t, .4 + k * .1, .7 + k * .1, Curves.elasticOut);
                final bounce = 1 +
                    .12 *
                        math
                            .max(
                                0,
                                math.sin(
                                    (loop.value * 2 - k * .15) * math.pi * 2))
                            .toDouble() *
                        (loop.value < .5 ? 1 : 0);
                return Opacity(
                  opacity: show,
                  child: Transform.translate(
                    offset: Offset(0, (1 - show) * 14),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() => _sel = k);
                        intro.forward(from: .35);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _sel == k
                                ? const Color(0xFFEAF6DF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          SizedBox(width: 30, child: CropArt(code: c.code, size: 30)),
                          const SizedBox(width: 12),
                          SizedBox(
                              width: 56,
                              child: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16))),
                          Expanded(
                            child: Text(
                              p == null
                                  ? '시세를 불러오는 중…'
                                  : '${commaNum(p.pricePerKg * count)}원/kg',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: p == null
                                      ? AppColors.sub
                                      : AppColors.ink),
                            ),
                          ),
                          Transform.scale(
                              scale: pop * bounce,
                              child: ChangeChip(percent: pct)),
                        ]),
                      ),
                    ),
                  ),
                );
              })),
              if (k < list.length - 1)
                const Divider(height: 1, color: Color(0xFFEDF1E8)),
            ],
            const SizedBox(height: 6),
            // 누른 품목에 대한 설명 (누르기 전에는 안내 문구)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF6DF),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_hint(list),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF000000),
                      height: 1.35)),
            ),
            const SizedBox(height: 4),
          ]),
        ));
      },
    );
  }
}

// ───────────────────────── 2. 파종하기 ─────────────────────────

/// 밭 그림 위에서 손가락이 + 칸으로 다가가 톡 누르고, 누를 때 + 칸이 반짝, 새싹이 퐁 돋아난다.
class _PlantVisual extends StatefulWidget {
  const _PlantVisual({required this.active});
  final bool active;
  @override
  State<_PlantVisual> createState() => _PlantVisualState();
}

class _PlantVisualState extends _AnimState<_PlantVisual> {
  @override
  Duration get introDuration => const Duration(milliseconds: 1);
  @override
  Duration get loopDuration => const Duration(milliseconds: 2600);
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(_PlantVisual old) {
    super.didUpdateWidget(old);
    syncActive(old.active);
  }

  // 그림(810×801) 속 자리 (원본 픽셀)
  static const _imgW = 810.0, _imgH = 801.0;
  static const _tile = Rect.fromLTRB(318, 431, 502, 560); // 가운데 + 칸
  static const _tap = Offset(410, 495); // 손가락이 누르는 곳
  static const _handSize = Size(110, 139); // 손가락 그림 크기 (원본 그림과 같은 비율)

  /// 그림 속 밭 9칸 (원본 픽셀). 4번이 가운데 + 칸. 눌러서 직접 심어 볼 수 있다.
  static const _plots = [
    Rect.fromLTRB(115, 315, 300, 415),
    Rect.fromLTRB(330, 315, 485, 415),
    Rect.fromLTRB(510, 315, 690, 415),
    Rect.fromLTRB(70, 435, 285, 550),
    _tile,
    Rect.fromLTRB(528, 432, 728, 548),
    Rect.fromLTRB(30, 575, 262, 695),
    Rect.fromLTRB(298, 572, 510, 692),
    Rect.fromLTRB(550, 572, 770, 692),
  ];

  /// 사용자가 직접 심은 칸 (칸 번호 → 고른 작물)
  final _planted = <int, CropSpec>{};

  /// 칸을 누르면 심을 작물을 고르는 시트가 열린다 (실제 게임의 "무엇을 심을까요?"와 같은 흐름, 연습이라 비용·저장 없음)
  Future<void> _plant(int i) async {
    final picked = await showModalBottomSheet<CropSpec>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          const Text('무엇을 심을까요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('연습이라 비용이 들지 않아요',
              style: TextStyle(fontSize: 12, color: AppColors.sub)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final c in crops)
                    SoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      onTap: () => Navigator.pop(sheet, c),
                      child: Row(children: [
                        CropBadge(c.code),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                Text(
                                    '수확 ${c.yieldKg.toStringAsFixed(0)}kg · 성장 ${c.growMinutes >= 60 ? '${c.growMinutes ~/ 60}시간${c.growMinutes % 60 == 0 ? '' : ' ${c.growMinutes % 60}분'}' : '${c.growMinutes}분'}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.sub)),
                              ]),
                        ),
                      ]),
                    ),
                ]),
          ),
        ]),
      ),
    );
    if (picked != null && mounted) setState(() => _planted[i] = picked);
  }

  static const _tip = Offset(8, 6); // 손가락 그림 안에서 손끝 위치

  @override
  Widget build(BuildContext context) => IllustCard(
        asset: AppImages.tutPlant,
        fill: true,
        overlay: LayoutBuilder(builder: (context, box) {
          // 그림이 틀을 덮도록 키워 가운데에 놓으므로, 그림 속 좌표(원본 픽셀)도 같은 배율·위치로 옮긴다
          final k = math.max(box.maxWidth / _imgW, box.maxHeight / _imgH);
          final ox = (box.maxWidth - _imgW * k) / 2,
              oy = (box.maxHeight - _imgH * k) / 2;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
                left: ox,
                top: oy,
                width: _imgW * k,
                height: _imgH * k,
                child: AnimatedBuilder(
                  animation: loop,
                  builder: (_, __) {
                    final t = loop.value;
                    // 0~.35 다가가기 · .35~.45 누르기 · .45~.55 떼기 · .55~.8 새싹 · .8~1 물러나기
                    final approach = _seg(t, 0, .35, Curves.easeInOutCubic);
                    final leave = _seg(t, .8, 1, Curves.easeInCubic);
                    final press = t < .35
                        ? 0.0
                        : (t < .45 ? _seg(t, .35, .45) : 1 - _seg(t, .45, .55));
                    const away = Offset(95, 85);
                    final handOffset =
                        Offset.lerp(away, Offset.zero, approach)! +
                            away * leave;
                    final handOpacity =
                        (t < .1 ? _seg(t, 0, .1) : 1.0) * (1 - _seg(t, .9, 1));
                    final glow = t < .35
                        ? .35
                        : (t < .7 ? 1 - _seg(t, .45, .7) * .5 : .5);
                    final ripple = _seg(t, .4, .75);
                    final demo =
                        _planted.isEmpty; // 아직 직접 안 눌러 봤으면 손가락이 시범을 보인다
                    final sprout = !demo
                        ? (_planted.containsKey(4) ? 1.0 : 0.0)
                        : (t < .5
                            ? 0.0
                            : _seg(t, .5, .75, Curves.elasticOut) *
                                (1 - _seg(t, .9, 1)));

                    final tile = Rect.fromLTRB(_tile.left * k, _tile.top * k,
                        _tile.right * k, _tile.bottom * k);
                    final tap = _tap * k;
                    final handW = _handSize.width * k,
                        handH = _handSize.height * k;
                    return Stack(clipBehavior: Clip.none, children: [
                      // + 칸 (그림 속 칸 자리에 코드로 다시 그려서 반짝이게)
                      Positioned.fromRect(
                          rect: tile,
                          child: _PlusTile(glow: glow, sprout: sprout)),
                      // 직접 심은 칸: 새싹이 퐁 돋아난다
                      for (final i in _planted.keys)
                        if (i != 4)
                          Positioned.fromRect(
                            rect: Rect.fromLTRB(
                                _plots[i].left * k,
                                _plots[i].top * k,
                                _plots[i].right * k,
                                _plots[i].bottom * k),
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('sprout$i'),
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.elasticOut,
                                builder: (_, v, __) => Transform.scale(
                                  scale: v,
                                  child: Center(
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('🌱',
                                              style: TextStyle(
                                                  fontSize: _plots[i].height *
                                                      k *
                                                      .55,
                                                  height: 1)),
                                          CropArt(
                                              code: _planted[i]!.code,
                                              size: _plots[i].height * k * .45),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      // 어느 칸이든 눌러서 심기
                      for (var i = 0; i < _plots.length; i++)
                        Positioned.fromRect(
                          rect: Rect.fromLTRB(
                              _plots[i].left * k,
                              _plots[i].top * k,
                              _plots[i].right * k,
                              _plots[i].bottom * k),
                          child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _plant(i)),
                        ),
                      // 안내 문구
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10 * k,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .92),
                                  borderRadius: BorderRadius.circular(14)),
                              child: Text(
                                  _planted.isEmpty
                                      ? '👆 밭을 눌러 직접 심어보세요'
                                      : '🌱 ${_planted.length}칸 심었어요! 다른 칸도 눌러보세요',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.greenDark)),
                            ),
                          ),
                        ),
                      ),
                      // 누를 때 퍼지는 동그란 물결
                      if (demo && ripple > 0 && ripple < 1)
                        Positioned(
                          left: tap.dx - 60 * k * ripple,
                          top: tap.dy - 60 * k * ripple,
                          child: IgnorePointer(
                            child: Container(
                              width: 120 * k * ripple,
                              height: 120 * k * ripple,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 1 - ripple),
                                      width: 3)),
                            ),
                          ),
                        ),
                      // 손가락 (직접 눌러 보면 사라진다)
                      if (demo)
                        Positioned(
                          left: tap.dx - _tip.dx * k + handOffset.dx * k,
                          top: tap.dy - _tip.dy * k + handOffset.dy * k,
                          width: handW,
                          height: handH,
                          child: Opacity(
                            opacity: handOpacity.clamp(0.0, 1.0).toDouble(),
                            child: Transform.scale(
                              scale: 1 - .12 * press,
                              alignment: Alignment.topLeft,
                              child: Image.asset(AppImages.tutHand,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium),
                            ),
                          ),
                        ),
                    ]);
                  },
                )),
          ]);
        }),
      );
}

/// 반짝이는 초록 + 칸 (누르면 + 대신 새싹이 퐁)
class _PlusTile extends StatelessWidget {
  const _PlusTile({required this.glow, required this.sprout});
  final double glow, sprout;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final s = box.maxHeight;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s * .1),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA8D84C), Color(0xFF6EAF2C)]),
            border: Border.all(color: const Color(0xFFD9F59A), width: s * .045),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFE9FF9E)
                      .withValues(alpha: .35 + .5 * glow),
                  blurRadius: 6 + 14 * glow,
                  spreadRadius: 1 + 3 * glow)
            ],
          ),
          alignment: Alignment.center,
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: (1 - sprout).clamp(0.0, 1.0).toDouble(),
              child: Icon(Icons.add_rounded,
                  size: s * .55,
                  color: const Color(0xFFE8FBFF),
                  shadows: const [
                    Shadow(color: Color(0x5537A0C8), blurRadius: 6)
                  ]),
            ),
            Transform.scale(
                scale: sprout,
                child:
                    Text('🌱', style: TextStyle(fontSize: s * .5, height: 1))),
          ]),
        );
      });
}

// ───────────────────────── 3. 성장하기 ─────────────────────────

/// 파종 → 성장 → 수확 카드가 차례로 커지며 강조되고, 사이 화살표가 깜빡이며 이어진다.
/// 카드·글자·화살표는 모두 코드로 그려서(그림 파일 속 글자를 쓰지 않아) 어떤 화면 크기에서도 또렷하다.
/// 카드를 직접 누르면 그 단계 설명이 나온다.
class _GrowVisual extends StatefulWidget {
  const _GrowVisual({required this.active});
  final bool active;
  @override
  State<_GrowVisual> createState() => _GrowVisualState();
}

class _GrowVisualState extends _AnimState<_GrowVisual> {
  @override
  Duration get introDuration => const Duration(milliseconds: 1);
  @override
  Duration get loopDuration => const Duration(milliseconds: 3000);
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(_GrowVisual old) {
    super.didUpdateWidget(old);
    syncActive(old.active);
  }

  static const _labels = ['파종', '성장', '수확'];
  static const _stages = [0.1, 0.5, 1.0];
  static const _captions = [
    '🌱 파종: 밭에 씨앗을 심어요',
    '🌿 성장: 시간이 지나면 쑥쑥 자라요',
    '🧺 수확: 다 자라면 거둬서 창고에 넣어요'
  ];

  /// 사용자가 눌러 본 단계 (0 파종 · 1 성장 · 2 수확). 눌러 보기 전에는 차례로 반짝인다.
  int? _picked;

  /// 연습으로 물을 주는 횟수 (실제 게임에는 횟수 제한이 없다)
  int _water = 0;
  static const _waterMax = tutorialWaterCount;

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: _art()),
        const SizedBox(height: 10),
        _waterPanel(),
      ]);

  /// 물주기 체험: 💧 버튼을 누르면 성장 막대가 3%씩 올라간다 (연습이라 실제 데이터는 바뀌지 않는다)
  Widget _waterPanel() {
    final done = _water >= _waterMax;
    final progress = (.4 + waterCut * _water).clamp(0.0, 1.0).toDouble();
    return SoftCard(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🥬', style: TextStyle(fontSize: 28, height: 1)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('배추가 자라는 중',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF000000)))),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${(v * 100).round()}%',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF000000))),
          ),
        ]),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => ThinBar(
              value: v,
              height: 12,
              color: const Color(0xFF34A34A),
              track: const Color(0xFFE4EAE6)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: KoText(
              done
                  ? '물을 $tutorialWaterCount번 줬어요! 성장 시간이 ${(waterCut * tutorialWaterCount * 100).round()}% 줄었어요'
                  : '💧을 눌러 물을 주면 성장 시간이 ${(waterCut * 100).round()}% 줄어요 (횟수 제한 없음)',
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Color(0xFF000000),
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _water = done ? 0 : _water + 1),
            child: Container(
              width: 74,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFE3F1FB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF8CC4EA), width: 2)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💧', style: TextStyle(fontSize: 26, height: 1)),
                    Text(done ? '다시' : '물주기',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF000000))),
                  ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _art() => IllustCard(
        asset: AppImages.farmScene,
        fill: true,
        overlay: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return AnimatedBuilder(
            animation: loop,
            builder: (_, __) {
              final t = loop.value;
              // 카드 i는 [i*.28, i*.28+.3] 동안 커졌다 돌아온다. 화살표는 그 사이에 반짝.
              double cardPulse(int i) {
                if (_picked != null) return _picked == i ? 1.0 : 0.0;
                return math.sin(
                    _seg(t, i * .28, i * .28 + .3, Curves.linear) * math.pi);
              }

              double arrowPulse(int i) {
                if (_picked != null) {
                  return (_picked! > i) ? 1.0 : 0.0; // 지나온 단계의 화살표는 켜 둔다
                }
                return math.sin(
                    _seg(t, i * .28 + .18, i * .28 + .38, Curves.linear) *
                        math.pi);
              }

              Widget card(int i) {
                final p = cardPulse(i);
                return Expanded(
                  flex: 10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _picked = i),
                    child: Transform.scale(
                      scale: 1 + .08 * p,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .96),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFFFF3A6)
                                    .withValues(alpha: .8 * p),
                                blurRadius: 16 * p,
                                spreadRadius: 2 * p),
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .1),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          LayoutBuilder(
                              builder: (_, c) => CropArt(
                                  code: 'CABBAGE',
                                  size: math.min(c.maxWidth, h * .17),
                                  stage: _stages[i])),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_labels[i],
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1C2B20))),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }

              Widget arrow(int i) {
                final p = arrowPulse(i);
                return Expanded(
                  flex: 3,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 + .3 * p,
                      child: Icon(Icons.play_arrow_rounded,
                          size: w * .075,
                          color: Color.lerp(
                              Colors.white, const Color(0xFFF2A81D), p)),
                    ),
                  ),
                );
              }

              return Stack(children: [
                Positioned(
                  left: w * .035,
                  right: w * .035,
                  top: h * .46,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        card(0),
                        arrow(0),
                        card(1),
                        arrow(1),
                        card(2)
                      ]),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: h * .06,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(14)),
                        child: Text(
                            _picked == null
                                ? '👆 단계를 눌러 보세요'
                                : _captions[_picked!],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.greenDark)),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          );
        }),
      );
}

// ───────────────────────── 4. 판매하기 ─────────────────────────

/// 시세 카드가 아래에서 쑥 올라오고, 가격이 올라가는 숫자 효과, 판매하기 버튼이 숨쉬듯 커졌다 작아진다.
class _SellVisual extends StatefulWidget {
  const _SellVisual({required this.price, required this.active});
  final AuctionPrice? price;
  final bool active;
  @override
  State<_SellVisual> createState() => _SellVisualState();
}

class _SellVisualState extends _AnimState<_SellVisual> {
  /// 판매하기를 눌러 연습 판매를 마쳤는지
  bool _sold = false;

  @override
  Duration get introDuration => const Duration(milliseconds: 1400);
  @override
  Duration get loopDuration => const Duration(milliseconds: 1600);
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(_SellVisual old) {
    super.didUpdateWidget(old);
    syncActive(old.active);
  }

  @override
  Widget build(BuildContext context) => IllustCard(
        // 글자·카드가 그려져 있지 않은 깨끗한 농장 그림 위에 시세 카드를 코드로 그린다 (그림 속 카드와 겹쳐 보이지 않게)
        asset: AppImages.farmScene,
        fill: true,
        overlay: AnimatedBuilder(
          animation: Listenable.merge([intro, loop]),
          builder: (_, __) {
            final t = intro.value;
            final rise = _seg(t, 0, .45, Curves.easeOutBack);
            final count = _seg(t, .3, .95);
            final breath =
                1 + .05 * (0.5 - 0.5 * math.cos(loop.value * math.pi * 2));
            return _SellOverlay(
                price: widget.price,
                rise: rise,
                count: count,
                breath: breath,
                sold: _sold,
                onSell: () => setState(() => _sold = !_sold));
          },
        ),
      );
}

/// 그림 위 시세 카드 자리(시안과 같은 위치)에 실제 배추 시세 + 판매하기 버튼
class _SellOverlay extends StatelessWidget {
  const _SellOverlay(
      {required this.price,
      this.rise = 1,
      this.count = 1,
      this.breath = 1,
      this.sold = false,
      this.onSell});
  final AuctionPrice? price;

  /// 연습 판매를 마친 상태 (버튼이 "판매 완료"로 바뀌고 +금액이 떠오른다)
  final bool sold;
  final VoidCallback? onSell;

  /// 0(아래에 숨어 있음) ~ 1(제자리)
  final double rise;

  /// 가격 숫자 진행 0 ~ 1
  final double count;

  /// 판매하기 버튼 크기 배율
  final double breath;

  @override
  Widget build(BuildContext context) {
    final p = price;
    final pct = p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
    final up = (pct ?? 0) > 0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return Stack(children: [
        Positioned(
          left: w * .055,
          right: w * .055,
          top: 0,
          bottom: h * .04,
          child: Align(
            alignment: const Alignment(0, .82),
            child: Opacity(
              opacity: rise.clamp(0.0, 1.0).toDouble(),
              child: Transform.translate(
                offset: Offset(0, (1 - rise) * h * .35),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 260,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          const Text('🥬',
                              style: TextStyle(fontSize: 46, height: 1)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('배추',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF4A5A4E),
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                      p == null
                                          ? '시세 확인 중'
                                          : '${commaNum(p.pricePerKg * count)}원/kg',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1C2B20))),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.sub, size: 22),
                                const SizedBox(height: 4),
                                if (pct != null && pct.abs() >= 0.05)
                                  Opacity(
                                    opacity: count,
                                    child: Text(up ? '▲' : '▼',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: up
                                                ? AppColors.up
                                                : AppColors.down)),
                                  ),
                              ]),
                        ]),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: onSell,
                          child: Transform.scale(
                            scale: sold ? 1 : breath,
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: sold
                                      ? AppColors.greenDark
                                      : AppColors.green,
                                  borderRadius: BorderRadius.circular(22)),
                              child: Text(
                                  sold
                                      ? '판매 완료 ✓  +${commaNum((p?.pricePerKg ?? 0) * 20)}원 · +${sellPointReward}P'
                                      : '판매하기',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

// ───────────────────────── 5. 준비 완료 ─────────────────────────

/// 농부 그림이 둥실둥실 떠 있고, 그 위로 반짝이(✨)와 꽃잎이 반짝이며 흩날린다.
class _ReadyVisual extends StatefulWidget {
  const _ReadyVisual({required this.active});
  final bool active;
  @override
  State<_ReadyVisual> createState() => _ReadyVisualState();
}

class _ReadyVisualState extends _AnimState<_ReadyVisual> {
  /// 농부를 눌렀을 때 한 번 재생하는 폴짝 + 반짝이 터짐
  late final AnimationController burst = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  bool _tapped = false;

  @override
  void dispose() {
    burst.dispose();
    super.dispose();
  }

  @override
  Duration get introDuration => const Duration(milliseconds: 600);
  @override
  Duration get loopDuration => const Duration(milliseconds: 4200);
  @override
  bool get active => widget.active;

  @override
  void didUpdateWidget(_ReadyVisual old) {
    super.didUpdateWidget(old);
    syncActive(old.active);
  }

  // (가로 위치 0~1, 시작 높이 0~1, 시차 0~1, 글자)
  static const _sparkles = [
    (.12, .18, .0, '✨'),
    (.82, .12, .35, '✨'),
    (.6, .3, .7, '✨'),
    (.3, .08, .55, '🌼'),
    (.92, .45, .15, '🌸'),
    (.05, .5, .8, '🌸'),
    (.45, .55, .25, '✨'),
    (.72, .08, .9, '🌼'),
    (.2, .35, .5, '✨'),
    (.95, .25, .4, '🌸'),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([intro, loop, burst]),
        builder: (_, __) {
          final b = burst.value;
          // 둥실둥실 떠다니고(±9), 그림이 천천히 숨 쉬듯 커졌다 작아지며, 눌렀을 때는 폴짝 뛴다
          final float = math.sin(loop.value * math.pi * 2) * 9 -
              math.sin(b * math.pi) * 26;
          final breathe = 1.06 + .05 * math.sin(loop.value * math.pi * 2 + 1.2);
          final appear = _seg(intro.value, 0, 1, Curves.easeOutBack);
          return Opacity(
            opacity: intro.value.clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(0, float),
              child: Transform.scale(
                scale: .92 + .08 * appear,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _tapped = true);
                    burst.forward(from: 0);
                  },
                  child: IllustCard(
                    asset: AppImages.tutReady,
                    fill: true,
                    imageScale: breathe,
                    alignment: const Alignment(-.25, 0),
                    overlay: LayoutBuilder(builder: (context, box) {
                      final w = box.maxWidth, h = box.maxHeight;
                      return Stack(children: [
                        for (final s in _sparkles)
                          Builder(builder: (_) {
                            final v = (loop.value * 1.5 + s.$3) %
                                1.0; // 각자 다른 때에 반짝 (더 빠르게)
                            final flower = s.$4 != '✨';
                            // 꽃잎은 천천히 아래로 흩날리고, 반짝이는 제자리에서 켜졌다 꺼진다
                            final dy = flower ? v * h * .35 : 0.0;
                            final dx =
                                flower ? math.sin(v * math.pi * 2) * 10 : 0.0;
                            final alpha = flower
                                ? math.sin(v * math.pi)
                                : math.max(0.0, math.sin(v * math.pi * 2));
                            return Positioned(
                              left: s.$1 * w + dx,
                              top: s.$2 * h + dy,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: alpha.clamp(0.0, 1.0).toDouble(),
                                  child: Transform.rotate(
                                    angle: flower ? v * math.pi : 0,
                                    child: Text(s.$4,
                                        style: TextStyle(
                                            fontSize: flower
                                                ? 16.0
                                                : 20.0 + 6 * alpha,
                                            height: 1)),
                                  ),
                                ),
                              ),
                            );
                          }),
                        // 눌렀을 때 터지는 반짝이
                        if (b > 0 && b < 1)
                          for (var i = 0; i < 12; i++)
                            Builder(builder: (_) {
                              final a = i / 12 * math.pi * 2;
                              final d = w * .06 +
                                  w * .32 * Curves.easeOut.transform(b);
                              return Positioned(
                                left: w / 2 + math.cos(a) * d - 11,
                                top: h * .5 + math.sin(a) * d * .8 - 11,
                                child: IgnorePointer(
                                    child: Opacity(
                                        opacity:
                                            (1 - b).clamp(0.0, 1.0).toDouble(),
                                        child: Text(i.isEven ? '✨' : '🌟',
                                            style: TextStyle(
                                                fontSize: 18 + 8 * (1 - b),
                                                height: 1)))),
                              );
                            }),
                        // 안내 문구
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 10,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .94),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Text(
                                    _tapped
                                        ? '🌾 좋아요! 이제 농장으로 가요'
                                        : '👆 농부를 눌러 보세요',
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.greenDark)),
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
