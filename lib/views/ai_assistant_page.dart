import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_agent.dart';
import '../models/models.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// AI 농사 도우미 대화 화면. 아래 추천 질문을 눌러 바로 물어볼 수도 있고, 직접 입력해도 된다.
class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <(bool, String)>[(false, '안녕하세요! 시세나 농사에 대해 물어보세요 🌱\n아래 추천 질문을 눌러도 돼요.')];
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _ctrl.text).trim();
    if (q.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _msgs.add((true, q));
      _busy = true;
    });
    _toBottom();
    final user = ref.read(userDataProvider);
    final weather = ref.read(weatherProvider).valueOrNull;
    final ctx = AiContext(
      prices: ref.read(marketViewModelProvider).valueOrNull ?? const <String, AuctionPrice>{},
      money: user.money,
      lots: ref.read(lotsProvider).valueOrNull ?? const <Lot>[],
      plots: ref.read(plotsProvider).valueOrNull ?? const <Plot>[],
      level: user.level.level,
      expLeft: user.level.need - user.level.exp,
      greenhouses: user.greenhouses,
      weather: weather == null ? null : '${weather.label} ${weather.tempC.round()}°C',
    );
    final a = await ref.read(aiAgentProvider).ask(q, ctx);
    if (!mounted) return;
    setState(() {
      _msgs.add((false, a));
      _busy = false;
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('🤖 AI 도우미'), backgroundColor: AppColors.bg, foregroundColor: AppColors.ink, elevation: 0),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final (mine, text) = _msgs[i];
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                    decoration: BoxDecoration(color: mine ? AppColors.green : Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text(text, style: TextStyle(fontSize: 15, height: 1.4, color: mine ? Colors.white : AppColors.ink)),
                  ),
                );
              },
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('생각 중…', style: TextStyle(color: AppColors.sub))),
          // 추천 질문: 옆으로 밀어서 더 볼 수 있다
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: aiSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (emoji, text) = aiSuggestions[i];
                return ActionChip(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.line),
                  label: Text('$emoji $text', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  onPressed: _busy ? null : () => _send(text),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '무엇이 궁금한가요?',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () => _send(), icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: AppColors.green)),
            ]),
          ),
        ]),
      ),
    );
  }
}
