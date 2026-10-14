import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 프로필 창: 농장 화면의 프로필이나 MY 화면의 아바타를 누르면 열린다.
/// 캐릭터(여자 아이 / 남자 아이)를 고르고, MY 화면으로 갈 수 있다.
Future<void> showProfileSheet(BuildContext context, {bool showMyButton = true}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProfileSheet(showMyButton: showMyButton),
    );

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet({required this.showMyButton});
  final bool showMyButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDataProvider);
    final lv = user.level;
    final title = farmerTitles[user.titleIndex];

    Widget choice(bool boy, String label) {
      final selected = user.isBoy == boy;
      return Expanded(
        child: GestureDetector(
          onTap: selected ? null : () => runGuarded(context, () => ref.read(farmViewModelProvider).setAvatar(boy), ok: '$label 캐릭터로 바꿨어요'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE7F4E0) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? AppColors.green : AppColors.line, width: selected ? 2.5 : 1),
            ),
            child: Column(children: [
              FarmerAvatar(size: 76, boy: boy),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(selected ? '✔ 사용 중' : '눌러서 바꾸기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.greenDark : AppColors.sub)),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          FarmerAvatar(size: 96, boy: user.isBoy),
          const SizedBox(height: 10),
          Text(user.nickname, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text('Lv. ${lv.level}  ·  ${title.emoji} ${title.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3D4A40))),
          const SizedBox(height: 18),
          const Align(alignment: Alignment.centerLeft, child: Text('캐릭터 고르기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink))),
          const SizedBox(height: 8),
          Row(children: [choice(false, '여자 아이'), const SizedBox(width: 12), choice(true, '남자 아이')]),
          if (showMyButton) ...[
            const SizedBox(height: 16),
            GreenButton(
              label: 'MY 화면으로',
              icon: const Icon(Icons.person_rounded, size: 20),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(shellIndexProvider.notifier).state = 4; // MY 탭
              },
            ),
          ],
        ]),
      ),
    );
  }
}
