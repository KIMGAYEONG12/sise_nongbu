import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import 'news_page.dart';
import 'price_detail_page.dart';

/// 시세판 탭: 품목별 kg당 시세와 전일 대비 등락. 카드를 누르면 품목 상세로 이동한다.
class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(marketViewModelProvider);
    final fetched = ref.read(marketRepoProvider).fetchedAt;

    Widget header() => PageHeader(
          title: '시세판',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: '새로고침',
              onPressed: () => ref.read(marketViewModelProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            ),
            IconButton(
              tooltip: '농부 뉴스',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NewsPage())),
              icon: const Icon(Icons.newspaper_rounded, color: AppColors.ink),
            ),
          ]),
        );

    return vm.when(
      loading: () => Column(children: [header(), const Expanded(child: Center(child: CircularProgressIndicator()))]),
      error: (e, _) => Column(children: [
        header(),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('시세를 불러오지 못했어요'),
              const SizedBox(height: 10),
              SizedBox(width: 160, child: GreenButton(label: '다시 시도', onPressed: () => ref.read(marketViewModelProvider.notifier).refresh())),
            ]),
          ),
        ),
      ]),
      data: (prices) => Column(children: [
        header(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(marketViewModelProvider.notifier).refresh(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  '가상 게임이며 실제 투자·거래 조언이 아닙니다.${fetched == null ? '' : '  ·  ${fetched.hour.toString().padLeft(2, '0')}:${fetched.minute.toString().padLeft(2, '0')} 조회'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              ),
              for (final c in crops)
                if (prices[c.code] case final p?)
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PriceDetailPage(cropCode: c.code))),
                    child: Row(children: [
                      EmojiBadge(c.emoji, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('${p.asOf.month}월 ${p.asOf.day}일 기준', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${won(p.pricePerKg)}/kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        if (p.change != null) ChangeChip(percent: changePercent(p.pricePerKg, p.prevPerKg)),
                      ]),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.sub),
                    ]),
                  ),
            ]),
          ),
        ),
      ]),
    );
  }
}
