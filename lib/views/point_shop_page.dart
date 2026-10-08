import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../core/korean.dart';
import 'about_page.dart';

/// 특별 상점 목록 (상점 탭과 독립 화면에서 같이 쓴다)
class PointShopBody extends ConsumerWidget {
  const PointShopBody({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, PointItem item) async {
    String? code;
    var msg = '${withJosa(item.name, '을', '를')} 받았어요';
    if (item.key == pointRareSeed) {
      final c = crops[Random().nextInt(crops.length)];
      code = c.code;
      msg = '${c.emoji} ${c.name} 씨앗 3개를 받았어요!';
    }
    await runGuarded(context, () => ref.read(farmViewModelProvider).buyPointItem(item, cropCode: code), ok: msg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    // 다음 목표: 아직 못 사는 아이템 중 가장 싼 것 (다 살 수 있으면 가장 비싼 것)
    final costs = pointItems.map((e) => e.cost).toList()..sort();
    final goal = costs.firstWhere((c) => c > user.points, orElse: () => costs.last);
    final ratio = goal <= 0 ? 1.0 : (user.points / goal).clamp(0.0, 1.0).toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      // 시안: 큰 별 · Point · 보유 포인트 · 초록 막대
      SoftCard(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(children: [
          const Text('⭐', style: TextStyle(fontSize: 42, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Point', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                const Spacer(),
                Text('보유 ⭐ ${commaNum(user.points)}P', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF55655A))),
              ]),
              const SizedBox(height: 8),
              ThinBar(value: ratio, height: 12, color: const Color(0xFF34A34A), track: const Color(0xFFE4EAE6)),
              const SizedBox(height: 5),
              Text(user.points >= goal ? '모든 아이템을 살 수 있어요!' : '다음 아이템까지 ${commaNum(goal - user.points)}P',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF55655A), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      for (final item in pointItems)
        Builder(builder: (_) {
          String? blocked;
          if (item.key == pointDecor && user.decor >= maxDecor) blocked = '최대';
          if (item.key == pointVault && user.warehouseBonusKg >= maxVaultBonusKg) blocked = '최대';
          final short = user.points < item.cost;
          final enabled = blocked == null && !short;
          final locked = blocked == null && short;
          return SoftCard(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(children: [
              // 시안: 노란 둥근 네모 안의 큰 아이콘
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF4CF), Color(0xFFFFE49A)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  Opacity(opacity: locked ? .45 : 1, child: Text(item.emoji, style: const TextStyle(fontSize: 34, height: 1))),
                  // 잠금: 포인트가 모자라면 자물쇠가 걸려 있다
                  if (locked)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0xFF7A867E), shape: BoxShape.circle),
                        child: const Icon(Icons.lock_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Text('⭐', style: TextStyle(fontSize: 13, height: 1)),
                    const SizedBox(width: 4),
                    Text('${item.cost}P', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF3D4A40))),
                  ]),
                  const SizedBox(height: 3),
                  KoText(item.desc, style: const TextStyle(fontSize: 11, color: Color(0xFF55655A), height: 1.3)),
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('🔒 ${commaNum(item.cost - user.points)}P 더 모으면 열려요', style: const TextStyle(fontSize: 11, color: Color(0xFF7A867E), fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              // 시안: 오른쪽 초록 테두리 알약 버튼
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: enabled ? () => _buy(context, ref, item) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greenDark,
                    disabledForegroundColor: const Color(0xFFA3ADA6),
                    side: BorderSide(color: enabled ? AppColors.green : const Color(0xFFD5DCD6), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(blocked ?? (locked ? '🔒 ${item.cost}P' : '${item.cost}P'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
              ),
            ]),
          );
        }),
      const SizedBox(height: 4),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('✨', style: TextStyle(fontSize: 12)),
        SizedBox(width: 4),
        Flexible(child: Text('Point는 미션, 업적, 이벤트를 통해 획득할 수 있어요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Color(0xFF55655A), fontWeight: FontWeight.w600))),
      ]),
    ]);
  }
}

class PointShopPage extends ConsumerWidget {
  const PointShopPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
              title: '특별 상점',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                MoneyPill(money: user.money),
                IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())), icon: const Icon(Icons.settings_outlined, color: AppColors.ink)),
              ]),
            ),
            const Expanded(child: PointShopBody()),
          ]),
        ),
      ),
    );
  }
}
