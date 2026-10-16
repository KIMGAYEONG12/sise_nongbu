import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/korean.dart';
import '../core/progress_rules.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'harvest_result_page.dart';

/// 성장 시간 문구 (예: 4시간, 6분, 24초)
String durText(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}시간${d.inMinutes % 60 == 0 ? '' : ' ${d.inMinutes % 60}분'}';
  if (d.inMinutes >= 1) return '${d.inMinutes}분';
  return '${d.inSeconds}초';
}

/// 작물 고르는 창의 갈래 버튼 (전체 + 작물 종류)
const plantKinds = ['전체', '채소', '과일', '특수'];

/// [query](이름 검색)와 [kind](갈래)에 맞는 작물만 고른다. 검색은 띄어쓰기를 무시한다.
List<CropSpec> filterCrops(String query, String kind) {
  final q = query.replaceAll(' ', '');
  return [
    for (final c in crops)
      if ((kind == '전체' || c.kind == kind) && (q.isEmpty || c.name.replaceAll(' ', '').contains(q))) c,
  ];
}

/// 빈 밭을 눌렀을 때: 심을 작물을 고르는 시트.
/// 검색창과 갈래 버튼(전체·채소·과일·특수)이 있고, 고르는 작물 수와 상관없이 창 크기는 항상 같다.
Future<void> showPlantSheet(BuildContext context, WidgetRef ref, Plot plot) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SizedBox(
      // 창 높이를 화면의 72%로 고정 (검색·갈래를 바꿔도 창이 커졌다 작아졌다 하지 않는다)
      height: MediaQuery.sizeOf(sheetContext).height * .72,
      child: _PlantSheet(outer: context, sheetContext: sheetContext, plot: plot),
    ),
  );
}

class _PlantSheet extends ConsumerStatefulWidget {
  const _PlantSheet({required this.outer, required this.sheetContext, required this.plot});
  final BuildContext outer, sheetContext;
  final Plot plot;
  @override
  ConsumerState<_PlantSheet> createState() => _PlantSheetState();
}

class _PlantSheetState extends ConsumerState<_PlantSheet> {
  final _search = TextEditingController();
  String _kind = '전체';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final speed = ref.watch(speedProvider);
    final list = filterCrops(_search.text, _kind);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 14),
        const Text('무엇을 심을까요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('보유 자금 ${won(user.money)}${user.greenhouses > 0 ? ' · 🏠 하우스 ${user.greenhouses}채로 성장 ${(100 - greenhouseFactor(user.greenhouses) * 100).round()}% 단축' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        const SizedBox(height: 10),
        // 작물 검색
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '작물 이름 검색 (예: 무화과)',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.sub),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '지우기',
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.sub),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 갈래 버튼: 네 개 모두 같은 너비·높이
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (i, k) in plantKinds.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: Material(
                    color: _kind == k ? AppColors.green : Colors.white,
                    shape: StadiumBorder(side: BorderSide(color: _kind == k ? AppColors.green : AppColors.line)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => _kind = k),
                      child: Center(
                        child: Text(k, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kind == k ? Colors.white : AppColors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('찾는 작물이 없어요', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700)))
              : ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + keyboard), children: [
                  for (final c in list)
                    Builder(builder: (_) {
                      final seeds = user.item(seedKey(c.code));
                      final dur = applyGreenhouses(growDuration(c, speed), user.greenhouses);
                      return SoftCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        onTap: () {
                          final outer = widget.outer;
                          final vm = ref.read(farmViewModelProvider);
                          Navigator.pop(widget.sheetContext);
                          runGuarded(outer, () => vm.plant(widget.plot.index, c), ok: '${withJosa(c.name, '을', '를')} 심었어요!', okCrop: c.code);
                        },
                        child: Row(children: [
                          CropBadge(c.code),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text('수확 ${c.yieldKg.toStringAsFixed(0)}kg · ${durText(dur)}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: seeds > 0 ? AppColors.greenLight : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
                            child: Text(seeds > 0 ? '씨앗 사용 ($seeds)' : won(c.seedCost),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: seeds > 0 ? AppColors.greenDark : AppColors.ink)),
                          ),
                        ]),
                      );
                    }),
                ]),
        ),
      ]),
    );
  }
}

/// 다 자란 밭 수확: 성공하면 수확 완료 화면을 연다.
Future<void> harvestPlot(BuildContext context, WidgetRef ref, Plot plot) async {
  final cropCode = plot.cropCode;
  if (cropCode == null) return;
  try {
    final kg = await ref.read(farmViewModelProvider).harvest(plot);
    if (!context.mounted) return;
    final spec = cropOf(cropCode);
    showCropMsg(context, cropCode, '${withJosa(spec.name, '을', '를')} 수확했습니다!');
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HarvestResultPage(cropCode: cropCode, kg: kg)));
  } catch (e) {
    if (context.mounted) showMsg(context, errMsg(e));
  }
}
