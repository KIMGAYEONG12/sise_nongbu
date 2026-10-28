import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/home_decor_rules.dart';
import '../core/home_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/greenhouse_art.dart';
import '../widgets/home_art.dart';
import '../widgets/home_interior_art.dart';

/// 둘러보기 화면의 자동 카메라 길: (가로 초점, 세로 초점, 확대 배율). 처음과 끝은 전체 모습.
const _tourStops = <(double, double, double)>[
  (.5, .5, 1.0),
  (.36, .5, 2.2),
  (.64, .42, 2.2),
  (.5, .78, 1.9),
  (.5, .5, 1.0),
];

/// 지금 하우스 단계 (하우스가 없으면 0)
int _myStage(WidgetRef ref) {
  final user = ref.watch(userDataProvider);
  return greenhouseStage(user.level.level, user.greenhouses);
}

/// 하우스·아파트 둘러보기: 큰 그림을 손가락으로 확대·이동하거나 "자동 둘러보기"로 한 바퀴 돌아본다.
/// 아래 단계 목록에서 다른 단계(앞으로 될 모양)도 미리 볼 수 있고, 열린 단계는 "들어가기"로 집 안에 들어간다.
class HomeTourPage extends ConsumerStatefulWidget {
  const HomeTourPage({super.key});
  @override
  ConsumerState<HomeTourPage> createState() => _HomeTourPageState();
}

class _HomeTourPageState extends ConsumerState<HomeTourPage> with TickerProviderStateMixin {
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final AnimationController _tour = AnimationController(vsync: this, duration: const Duration(seconds: 10))..addListener(_onTour)
    ..addStatusListener(_onTourStatus);
  final _tc = TransformationController();
  Size _scene = Size.zero;

  /// 미리 보고 있는 단계 (1~10). null이면 지금 내 단계
  int? _preview;

  @override
  void dispose() {
    _tour.removeListener(_onTour);
    _tour.removeStatusListener(_onTourStatus);
    _tour.dispose();
    _life.dispose();
    _tc.dispose();
    super.dispose();
  }

  /// 초점(fx, fy)이 화면 가운데 오도록 [s]배 확대한 변환 (그림 밖이 보이지 않게 가장자리를 맞춘다)
  Matrix4 _focus(double fx, double fy, double s) {
    final w = _scene.width, h = _scene.height;
    final tx = (w / 2 - s * fx * w).clamp(w - s * w, 0.0).toDouble();
    final ty = (h / 2 - s * fy * h).clamp(h - s * h, 0.0).toDouble();
    return Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  void _onTour() {
    if (_scene.isEmpty) return;
    final segs = _tourStops.length - 1;
    final pos = _tour.value * segs;
    final i = math.min(pos.floor(), segs - 1);
    final k = Curves.easeInOut.transform((pos - i).clamp(0.0, 1.0).toDouble());
    final a = _tourStops[i], b = _tourStops[i + 1];
    double lerp(double x, double y) => x + (y - x) * k;
    _tc.value = _focus(lerp(a.$1, b.$1), lerp(a.$2, b.$2), lerp(a.$3, b.$3));
  }

  /// 자동 둘러보기가 끝나면 단추를 다시 "자동"으로
  void _onTourStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) setState(() {});
  }

  void _toggleTour() {
    if (_tour.isAnimating) {
      _tour.stop();
    } else {
      _tour.forward(from: 0);
    }
    setState(() {});
  }

  void _resetView() {
    _tour.stop();
    _tc.value = Matrix4.identity();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final level = user.level.level;
    final owned = user.greenhouses;
    final stage = _myStage(ref);
    final has = owned > 0;
    final myLv = has ? homeLevelOf(stage) : 0;
    final view = _preview ?? (has ? myLv : 1);
    final showStage = has && view == myLv ? stage : view; // 지금 내 단계면 "+n"까지 그대로
    final unlocked = has && view <= myLv;
    // 이 단계가 되려면 하우스가 몇 채 필요한지 (단계 = 지은 하우스 + 레벨로 오른 모양 단계)
    final tier = greenhouseTier(level);
    final need = homeHousesNeeded(view, tier);
    final more = math.max(0, need - owned);
    final full = owned >= maxGreenhouses;
    // 지금 내 단계를 보고 있으면 지은 채 수, 미리보기면 그 단계에 필요한 채 수
    final houses = has && view == myLv ? owned : need;
    final cost = greenhouseCostFor(owned);
    final cut = (100 - greenhouseFactor(owned) * 100).round();
    final facilities = homeFacilitiesOf(showStage);
    final apt = isApartmentStage(showStage);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '하우스 둘러보기', onBack: () => Navigator.of(context).pop(), trailing: MoneyPill(money: user.money)),
            // ── 큰 그림: 확대·이동해서 둘러보기 ──
            // (스크롤 목록 밖에 고정해 둔다. 목록 안에 있으면 그림을 밀 때 목록 스크롤과 손가락 동작이 서로 부딪친다)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 1.12,
                    child: LayoutBuilder(builder: (context, box) {
                      _scene = Size(box.maxWidth, box.maxHeight);
                      return Stack(children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController: _tc,
                            minScale: 1,
                            maxScale: 4,
                            onInteractionStart: (_) {
                              if (_tour.isAnimating) setState(_tour.stop);
                            },
                            child: SizedBox(
                              width: box.maxWidth,
                              height: box.maxHeight,
                              child: Stack(children: [
                                Positioned.fill(child: CustomPaint(painter: HomeSceneryPainter(apartment: apt, anim: _life))),
                                // 건물 그림은 정사각형으로 (늘어나 보이지 않게)
                                Positioned.fill(
                                  top: box.maxHeight * .05,
                                  child: Center(child: AspectRatio(aspectRatio: 1, child: RepaintBoundary(child: CustomPaint(painter: HomeBuildingPainter(stage: showStage, anim: _life))))),
                                ),
                                // 아파트 편의 시설: 단계가 오를 때마다 건물 옆 앞마당에 하나씩 생긴다
                                if (facilities.isNotEmpty) Positioned.fill(child: CustomPaint(painter: HomeFacilitiesPainter(count: facilities.length, anim: _life))),
                              ]),
                            ),
                          ),
                        ),
                        // 이름표
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _Badge(text: '${apt ? '🏢' : '🏡'} ${homeBadge(showStage)}', color: AppColors.greenDark),
                        ),
                        if (!unlocked) const Positioned(right: 12, top: 12, child: _Badge(text: '🔒 미리보기', color: Color(0xFF8A5A00))),
                        // 아래: 사용법 + 자동 둘러보기 / 처음 크기
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Row(children: [
                            const Expanded(child: _Badge(text: '👆 두 손가락으로 확대 · 밀어서 둘러보기', color: Color(0xFF2B3A30), small: true)),
                            const SizedBox(width: 6),
                            _RoundBtn(icon: _tour.isAnimating ? Icons.pause_rounded : Icons.play_arrow_rounded, label: _tour.isAnimating ? '멈춤' : '자동', onTap: _toggleTour),
                            const SizedBox(width: 6),
                            _RoundBtn(icon: Icons.zoom_out_map_rounded, label: '전체', onTap: _resetView),
                          ]),
                        ),
                      ]);
                    }),
                  ),
                ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
                // ── 단계 목록: 하우스 1~4 → 아파트 1~6 ──
                const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('레벨별 변화', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink))),
                SizedBox(
                  height: 136,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: homeLevels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final lv = i + 1;
                      final open = has && lv <= myLv;
                      final sel = lv == view;
                      return GestureDetector(
                        onTap: () {
                          _resetView();
                          setState(() => _preview = lv);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 94,
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFFF8E1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? const Color(0xFFF2B526) : AppColors.line, width: sel ? 2.4 : 1),
                          ),
                          child: Column(children: [
                            Expanded(
                              child: Stack(children: [
                                Positioned.fill(child: Opacity(opacity: open ? 1 : .55, child: CustomPaint(painter: HomeBuildingPainter(stage: lv)))),
                                if (!open) const Positioned(right: 2, top: 0, child: Icon(Icons.lock_rounded, size: 16, color: Color(0xFF8A7A6A))),
                                if (has && lv == myLv) const Positioned(left: 0, top: 0, child: Text('🏠', style: TextStyle(fontSize: 13))),
                              ]),
                            ),
                            Text(homeBadge(lv), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: open ? AppColors.ink : AppColors.sub)),
                            // 이 단계에 필요한 하우스 채 수 (아파트는 세대로)
                            Text('${homeHousesNeeded(lv, tier)}${homeUnit(lv)}부터', maxLines: 1, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF8A6A2A))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // ── 정보 카드 ──
                SoftCard(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(homeName(showStage, houses: houses), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    KoText(homeDesc(showStage), style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
                    const Divider(height: 22, color: AppColors.line),
                    _line('지은 하우스', '$owned채 / 최대 $maxGreenhouses채'),
                    const SizedBox(height: 6),
                    _line('이 단계에 필요한 하우스', '$need채'),
                    if (apt) ...[
                      const SizedBox(height: 6),
                      _line('아파트 세대 수', '${homeHouseholds(houses)}세대'),
                    ],
                    const SizedBox(height: 6),
                    _line('작물 성장 시간', has ? '$cut% 단축' : '아직 없음'),
                    const SizedBox(height: 6),
                    _line('들어가 볼 수 있는 방', homeRoomsOf(showStage).map(homeRoomName).join('·')),
                    if (facilities.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('편의 시설 (시설마다 하루 한 번 이용)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF3D4A40))),
                      const SizedBox(height: 6),
                      FacilityList(stage: showStage, myStage: has ? stage : 0),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                GreenButton(
                  label: unlocked ? '${apt ? '아파트' : '하우스'} 안으로 들어가기' : (more > 0 ? '하우스를 $more채 더 지으면 열려요' : '레벨을 올리면 열려요'),
                  icon: const Icon(Icons.meeting_room_rounded, size: 22),
                  height: 52,
                  onPressed: unlocked ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HomeInteriorPage(stage: showStage, myStage: stage, title: homeName(showStage, houses: houses)))) : null,
                ),
                const SizedBox(height: 10),
                GreenButton(
                  label: full ? '하우스를 다 지었어요 ($maxGreenhouses채)' : '하우스 ${has ? '더 ' : ''}짓기 ${won(cost)}',
                  outlined: true,
                  icon: const CoinIcon(size: 20),
                  onPressed: full || user.money < cost
                      ? null
                      : () async {
                          final ok = await runGuarded(context, ref.read(farmViewModelProvider).buyGreenhouse, ok: '하우스를 지었어요 🏠 한 단계 커졌어요!');
                          if (ok && mounted) setState(() => _preview = null);
                        },
                ),
                if (!full && user.money < cost) const Padding(padding: EdgeInsets.only(top: 6), child: Center(child: Text('포인트(P)가 부족합니다', style: TextStyle(fontSize: 12.5, color: AppColors.sub)))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _line(String a, String b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3D4A40))),
        const SizedBox(width: 10),
        Expanded(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.ink))),
      ]);
}

/// 집 안: 방 탭(거실·주방·침실·발코니·온실)을 골라 들어가 보고, 손가락으로 확대해 구석구석 둘러본다.
/// "꾸미기"를 누르면 가구를 골라 놓고, 끌어서 옮기고, 지울 수 있다 (내 계정에 저장돼 다음에도 그대로).
class HomeInteriorPage extends ConsumerStatefulWidget {
  const HomeInteriorPage({super.key, required this.stage, this.myStage, this.title, this.tips, this.mansion = false});
  final int stage;

  /// 지금 내 집 단계 (편의 시설을 쓸 수 있는지 볼 때). 없으면 [stage]
  final int? myStage;

  /// 위 제목에 쓸 집 이름 (없으면 단계 이름). 저택에서 들어올 때는 저택 이름을 준다.
  final String? title;

  /// 방마다 보여 줄 한 줄 설명 (없으면 기본 설명)
  final Map<HomeRoom, String>? tips;

  /// 농장 저택 안인지 (저택과 하우스·아파트는 따로 꾸민다)
  final bool mansion;
  @override
  ConsumerState<HomeInteriorPage> createState() => _HomeInteriorPageState();
}

class _HomeInteriorPageState extends ConsumerState<HomeInteriorPage> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  final _tc = TransformationController();
  int _room = 0;

  /// 꾸미는 중이면 지금 고친 가구 목록 (저장 전). null이면 꾸미기 중이 아니다.
  List<DecorPlacement>? _draft;
  int? _sel;
  bool _saving = false;
  Size _area = Size.zero;

  static const _roomTips = {
    HomeRoom.living: '푹신한 소파에서 쉬며 오늘의 시세를 확인해요',
    HomeRoom.kitchen: '직접 키운 채소로 맛있는 요리를 해요',
    HomeRoom.bedroom: '푹 자고 일어나면 작물이 쑥쑥 자라 있어요',
    HomeRoom.balcony: '바람을 쐬며 농장 풍경을 내려다봐요',
    HomeRoom.greenhouse: '유리 온실에서 작물이 사계절 자라요',
  };

  @override
  void dispose() {
    _life.dispose();
    _tc.dispose();
    super.dispose();
  }

  bool get _editing => _draft != null;

  void _go(int i, int count) {
    if (_editing) return; // 꾸미는 중에는 방을 바꾸지 않는다 (먼저 저장)
    setState(() {
      _room = (i % count + count) % count;
      _tc.value = Matrix4.identity();
    });
  }

  String _roomKey(HomeRoom room) => decorRoomKey(mansion: widget.mansion, room: room);

  void _startEdit(List<DecorPlacement> saved) => setState(() {
        _tc.value = Matrix4.identity();
        _draft = List.of(saved);
        _sel = null;
      });

  void _add(DecorItem item) {
    final d = _draft!;
    if (d.length >= maxDecorPerRoom) {
      showMsg(context, '한 방에는 가구를 $maxDecorPerRoom개까지 놓을 수 있어요');
      return;
    }
    // 방 가운데 근처에, 겹치지 않게 조금씩 비켜 놓는다
    final off = (d.length % 5) * .06;
    setState(() {
      _draft = [...d, DecorPlacement(item.key, .45 + off, .5 + off * .5)];
      _sel = _draft!.length - 1;
    });
  }

  void _remove() {
    final s = _sel;
    if (s == null) return;
    setState(() {
      _draft = [..._draft!]..removeAt(s);
      _sel = null;
    });
  }

  /// 손가락 아래 가장 가까운 가구 번호
  int? _hit(Offset o) {
    final d = _draft!;
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < d.length; i++) {
      final p = interiorFloorToScreen(_area, d[i].x, d[i].y);
      // 가구는 바닥 위로 솟아 있으니 바닥점보다 조금 위를 중심으로 본다
      final dist = (o - (p - Offset(0, _area.width * .05))).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return bestDist < _area.width * .12 ? best : null;
  }

  void _moveTo(Offset o) {
    final s = _sel;
    if (s == null) return;
    final (x, y) = interiorScreenToFloor(_area, o + Offset(0, _area.width * .03));
    setState(() => _draft = [..._draft!]..[s] = _draft![s].moved(x, y));
  }

  Future<void> _save(HomeRoom room) async {
    setState(() => _saving = true);
    final ok = await runGuarded(context, () => ref.read(farmViewModelProvider).saveRoomDecor(_roomKey(room), _draft!), ok: '${homeRoomName(room)}을(를) 꾸몄어요 🏡');
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _draft = null;
        _sel = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final rooms = homeRoomsOf(widget.stage);
    final room = rooms[_room.clamp(0, rooms.length - 1)];
    final apt = isApartmentStage(widget.stage);
    final facilities = widget.mansion ? const <(String, String)>[] : homeFacilitiesOf(widget.stage);
    final saved = decorOfRoom(user.homeDecor, _roomKey(room));
    final shown = _draft ?? saved;
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) setState(() => _draft = null); // 뒤로 가기: 저장하지 않고 꾸미기만 끝낸다
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              PageHeader(title: '${widget.title ?? homeName(widget.stage)} 안', onBack: () => Navigator.of(context).maybePop()),
              Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 8), child: PillTabs(labels: [for (final r in rooms) homeRoomName(r)], index: _room.clamp(0, rooms.length - 1), onChanged: (i) => _go(i, rooms.length))),
              // 방 그림은 스크롤 목록 밖에 고정 (확대·이동 손가락 동작이 목록 스크롤과 부딪치지 않게)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: apt ? const [Color(0xFFFFF9EE), Color(0xFFF3E7D2)] : const [Color(0xFFFFF6E4), Color(0xFFEAF3DC)]),
                    border: Border.all(color: _editing ? const Color(0xFFF2B526) : const Color(0xFFEADBC0), width: _editing ? 2.4 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 1.05,
                      child: LayoutBuilder(builder: (context, box) {
                        _area = Size(box.maxWidth, box.maxHeight);
                        final paint = CustomPaint(
                          key: ValueKey(room),
                          size: Size.infinite,
                          painter: HomeInteriorPainter(stage: widget.stage, room: room, anim: _life, decor: shown, selected: _editing ? _sel : null),
                        );
                        return Stack(children: [
                          Positioned.fill(
                            child: _editing
                                // 꾸미는 중: 눌러서 가구 고르기, 끌어서 옮기기 (확대는 잠시 끈다)
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (e) => setState(() => _sel = _hit(e.localPosition)),
                                    onPanStart: (e) => setState(() => _sel = _hit(e.localPosition) ?? _sel),
                                    onPanUpdate: (e) => _moveTo(e.localPosition),
                                    child: paint,
                                  )
                                : InteractiveViewer(
                                    transformationController: _tc,
                                    minScale: 1,
                                    maxScale: 4,
                                    child: AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: paint),
                                  ),
                          ),
                          Positioned(left: 12, top: 12, child: _Badge(text: _editing ? '✏️ ${homeRoomName(room)} 꾸미는 중' : homeRoomName(room), color: _editing ? const Color(0xFF9A6A00) : AppColors.greenDark)),
                          if (!_editing) ...[
                            // 이전 방 / 다음 방
                            Positioned(left: 6, top: 0, bottom: 0, child: Center(child: _ArrowBtn(icon: Icons.chevron_left_rounded, onTap: () => _go(_room - 1, rooms.length)))),
                            Positioned(right: 6, top: 0, bottom: 0, child: Center(child: _ArrowBtn(icon: Icons.chevron_right_rounded, onTap: () => _go(_room + 1, rooms.length)))),
                          ],
                          if (_editing && _sel != null)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: _RoundBtn(icon: Icons.delete_outline_rounded, label: '빼기', onTap: _remove),
                            ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
                  if (_editing) ...[
                    // ── 꾸미기: 가구 고르기 + 저장 ──
                    Text('가구를 누르면 방에 놓여요 (${shown.length}/$maxDecorPerRoom) · 놓은 가구는 끌어서 옮겨요', style: const TextStyle(fontSize: 12.5, color: AppColors.sub, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: .9,
                      children: [
                        for (final d in decorItems)
                          SoftCard(
                            padding: const EdgeInsets.all(4),
                            onTap: () => _add(d),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(d.emoji, style: const TextStyle(fontSize: 22, height: 1.1)),
                              const SizedBox(height: 3),
                              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: GreenButton(
                          label: '취소',
                          outlined: true,
                          height: 48,
                          onPressed: _saving ? null : () => setState(() => _draft = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GreenButton(
                          label: _saving ? '저장하는 중…' : '다 꾸몄어요 (저장)',
                          icon: const Icon(Icons.check_rounded, size: 22),
                          height: 48,
                          onPressed: _saving ? null : () => _save(room),
                        ),
                      ),
                    ]),
                  ] else ...[
                    SoftCard(
                      color: Colors.white,
                      child: Row(children: [
                        Text(_emoji(room), style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: KoText(widget.tips?[room] ?? _roomTips[room] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35))),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    GreenButton(
                      label: saved.isEmpty ? '${homeRoomName(room)} 꾸미기' : '${homeRoomName(room)} 다시 꾸미기 (가구 ${saved.length}개)',
                      icon: const Icon(Icons.chair_rounded, size: 22),
                      height: 50,
                      onPressed: () => _startEdit(saved),
                    ),
                    const SizedBox(height: 6),
                    const Center(child: Text('👆 두 손가락으로 확대 · 밀어서 방을 둘러보세요', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600))),
                    if (facilities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('아파트 편의 시설 (시설마다 하루 한 번)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink))),
                      FacilityList(stage: widget.stage, myStage: widget.myStage ?? widget.stage),
                    ],
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static String _emoji(HomeRoom r) => switch (r) {
        HomeRoom.living => '🛋️',
        HomeRoom.kitchen => '🍳',
        HomeRoom.bedroom => '🛏️',
        HomeRoom.balcony => '🌿',
        HomeRoom.greenhouse => '🌱',
      };
}

/// 아파트 편의 시설 목록: [stage] 집에 있는 시설을 보여 주고, 지금 내 집([myStage])에 있는 시설은 눌러서 이용한다.
/// 시설마다 하루(한국 날짜) 한 번 물통·영양제·성장촉진제·경험치·캐시를 받는다.
class FacilityList extends ConsumerWidget {
  const FacilityList({super.key, required this.stage, required this.myStage});
  final int stage, myStage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final now = ref.watch(tickProvider).valueOrNull ?? DateTime.now();
    final list = homeFacilitiesOf(stage);
    return Column(children: [
      for (var i = 0; i < list.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Builder(builder: (context) {
            final mine = canUseFacility(myStage, i);
            final used = mine && facilityUsedToday(user.facilityDaily, i, now);
            final perk = i < facilityPerks.length ? facilityPerks[i] : null;
            return SoftCard(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              onTap: !mine || used || perk == null
                  ? null
                  : () => runGuarded(context, () async {
                        final got = await ref.read(farmViewModelProvider).useFacility(i, myStage);
                        if (context.mounted) showMsg(context, '${list[i].$1} ${list[i].$2} 이용! ${got.rewardText} 받았어요');
                      }),
              child: Row(children: [
                Text(list[i].$1, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(list[i].$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    if (perk != null) Text('${perk.desc} (${perk.rewardText})', style: const TextStyle(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: !mine ? const Color(0xFFEDEDED) : (used ? const Color(0xFFE8F3E2) : AppColors.green),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(!mine ? '🔒 잠김' : (used ? '오늘 이용함' : '이용하기'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: !mine ? AppColors.sub : (used ? AppColors.greenDark : Colors.white))),
                ),
              ]),
            );
          }),
        ),
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.small = false});
  final String text;
  final Color color;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 6 : 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: small ? 11 : 13, fontWeight: FontWeight.w900, color: color)),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 2),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
        ),
      );
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .85),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 28, color: AppColors.ink))),
      );
}
