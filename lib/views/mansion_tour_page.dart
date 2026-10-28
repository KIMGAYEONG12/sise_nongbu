import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/home_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/farm_mansion.dart';
import 'home_tour_page.dart';

/// 농장 큰 집(오두막 → … → 황금 농장 저택 → 전설의 농장 성) 둘러보기: 아파트 둘러보기처럼
/// 큰 그림을 확대·이동해 보고, 단계 목록에서 다른 단계를 미리 보고, 열린 단계는 집 안으로 들어간다.
class MansionTourPage extends ConsumerStatefulWidget {
  const MansionTourPage({super.key});
  @override
  ConsumerState<MansionTourPage> createState() => _MansionTourPageState();
}

class _MansionTourPageState extends ConsumerState<MansionTourPage> {
  final _tc = TransformationController();

  /// 미리 보고 있는 단계 (farmHouseNames 위치). null이면 지금 내 단계
  int? _preview;

  /// 저택 안 방마다의 한 줄 설명
  static const _roomTips = {
    HomeRoom.living: '넓은 거실 벽난로 앞에서 오늘의 시세를 확인해요',
    HomeRoom.kitchen: '농장에서 갓 딴 채소로 근사한 요리를 해요',
    HomeRoom.bedroom: '푹신한 침대에서 자고 나면 작물이 쑥쑥 자라 있어요',
    HomeRoom.balcony: '테라스에서 바람을 쐬며 농장을 내려다봐요',
    HomeRoom.greenhouse: '저택 뒤 유리 온실에서 작물이 사계절 자라요',
  };

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final level = user.level.level;
    final mine = farmHouseIndex(level);
    final view = _preview ?? mine;
    final unlocked = view <= mine;
    final (needLevel, name) = farmHouseNames[view];
    final features = farmHouseFeaturesOf(view);
    final golden = isGoldenHouseStage(view);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(title: '농장 저택 둘러보기', onBack: () => Navigator.of(context).pop(), trailing: MoneyPill(money: user.money)),
            // ── 큰 그림: 확대·이동해서 둘러보기 (스크롤 목록 밖에 고정) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 440 / 360,
                  child: Stack(children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _tc,
                        minScale: 1,
                        maxScale: 4,
                        child: FarmHouseScene(key: ValueKey(view), stageIndex: view),
                      ),
                    ),
                    Positioned(left: 12, top: 12, child: _Badge(text: '${view == farmHouseNames.length - 1 ? '🏰' : '🏡'} $name', color: golden ? const Color(0xFF9A6A00) : AppColors.greenDark)),
                    if (!unlocked) const Positioned(right: 12, top: 12, child: _Badge(text: '🔒 미리보기', color: Color(0xFF8A5A00))),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(children: [
                        const Expanded(child: _Badge(text: '👆 두 손가락으로 확대 · 밀어서 둘러보기', color: Color(0xFF2B3A30), small: true)),
                        const SizedBox(width: 6),
                        Material(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _tc.value = Matrix4.identity(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.zoom_out_map_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 2),
                                Text('전체', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
                // ── 단계 목록: 작은 오두막 → … → 전설의 농장 성 ──
                const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('레벨별 변화', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink))),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: farmHouseNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final open = i <= mine;
                      final sel = i == view;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _tc.value = Matrix4.identity();
                          _preview = i;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 104,
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFFF8E1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? const Color(0xFFF2B526) : AppColors.line, width: sel ? 2.4 : 1),
                          ),
                          child: Column(children: [
                            Expanded(
                              child: Stack(children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Opacity(opacity: open ? 1 : .55, child: FarmHouseScene(stageIndex: i, crop: const Rect.fromLTWH(60, 110, 360, 300))),
                                  ),
                                ),
                                if (!open) const Positioned(right: 2, top: 2, child: Icon(Icons.lock_rounded, size: 16, color: Colors.white)),
                                if (i == mine) const Positioned(left: 2, top: 0, child: Text('🏠', style: TextStyle(fontSize: 13))),
                              ]),
                            ),
                            const SizedBox(height: 3),
                            Text(farmHouseNames[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: open ? AppColors.ink : AppColors.sub)),
                            Text('Lv.${farmHouseNames[i].$1}부터', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF8A6A2A))),
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
                    Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: golden ? const Color(0xFF9A6A00) : AppColors.ink)),
                    const SizedBox(height: 2),
                    KoText(farmHouseDescs[view], style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
                    const Divider(height: 22, color: AppColors.line),
                    _line('필요한 농부 레벨', 'Lv.$needLevel'),
                    const SizedBox(height: 6),
                    _line('지금 내 레벨', 'Lv.$level'),
                    const SizedBox(height: 6),
                    _line('단계', '${view + 1} / ${farmHouseNames.length}단계'),
                    if (view + 1 < farmHouseNames.length) ...[
                      const SizedBox(height: 6),
                      _line('다음 단계', '${farmHouseNames[view + 1].$2} (Lv.${farmHouseNames[view + 1].$1})'),
                    ],
                    const SizedBox(height: 6),
                    _line('들어가 볼 수 있는 방', homeRoomsOf(4).map(homeRoomName).join('·')),
                    if (features.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('저택 시설', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF3D4A40))),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final f in features)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3DC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF2D59A))),
                            child: Text('${f.$1} ${f.$2}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF7A5200))),
                          ),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                GreenButton(
                  label: unlocked ? '$name 안으로 들어가기' : 'Lv.$needLevel이 되면 열려요',
                  icon: const Icon(Icons.meeting_room_rounded, size: 22),
                  height: 52,
                  // 저택 안은 유리 온실까지 있는 넓은 집 안 그림으로 보여 준다
                  onPressed: unlocked ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HomeInteriorPage(stage: 4, title: name, tips: _roomTips, mansion: true))) : null,
                ),
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
