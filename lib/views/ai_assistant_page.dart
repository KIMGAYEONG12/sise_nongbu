import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_agent.dart';
import '../models/models.dart';
import '../services/ai_input_service.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 사진·음성 입력 서비스 (테스트에서는 가짜로 바꿔 끼운다)
final photoInputProvider =
    Provider<PhotoInput>((ref) => ImagePickerPhotoInput());
final voiceInputProvider = Provider<VoiceInput>((ref) => SpeechVoiceInput());

/// 도우미 첫 인사
const aiGreeting =
    '시세나 농사에 대해 물어보세요!\n글로 쓰거나, 🎤 음성으로 말하거나, 📷 사진을 올려서 물어볼 수 있어요.';

/// 대화 한 줄: 내가 보낸 건지, 글, (있으면) 함께 보낸 사진
class _Msg {
  const _Msg(this.mine, this.text, {this.image});
  final bool mine;
  final String text;
  final AiImage? image;
}

/// AI 농사 도우미 대화 화면. 아래 추천 질문을 눌러 바로 물어볼 수도 있고, 직접 입력하거나
/// 🎤 음성으로 말하거나 📷 사진을 함께 올려서 물어볼 수도 있다.
class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _chips = ScrollController(); // 추천 질문 줄 (옆으로 밀기)
  final _msgs = <_Msg>[const _Msg(false, aiGreeting)];
  bool _busy = false;
  bool _listening = false;

  /// 다음 질문과 함께 보낼 사진 (고르면 입력창 위에 작게 보인다)
  AiImage? _photo;

  @override
  void initState() {
    super.initState();
    // 카메라를 쓰는 동안 앱이 다시 시작됐다면 찍어 둔 사진을 되찾는다
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = ref.read(photoInputProvider);
      if (p is! ImagePickerPhotoInput) return;
      final lost = await p.recoverLost();
      if (lost != null && mounted) setState(() => _photo = lost);
    });
  }

  @override
  void dispose() {
    // 화면을 나갈 때 듣고 있었다면 멈춘다 (provider는 이미 해제됐을 수 있어 실패해도 무시)
    if (_listening) {
      try {
        ref.read(voiceInputProvider).stop();
      } catch (_) {}
    }
    _ctrl.dispose();
    _scroll.dispose();
    _chips.dispose();
    super.dispose();
  }

/// 데이터를 기다려 받되, 오래 걸리거나 실패하면 [fallback]을 쓴다
  Future<T> _orEmpty<T>(Future<T> f, T fallback) async {
    try {
      return await f.timeout(const Duration(seconds: 4));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _send([String? preset]) async {
    final typed = (preset ?? _ctrl.text).trim();
    final photo = _photo;
    // 글도 사진도 없으면 보낼 게 없다
    if ((typed.isEmpty && photo == null) || _busy) return;
    if (_listening) await _stopListening();
    _ctrl.clear();
    setState(() {
      _msgs
          .add(_Msg(true, typed.isEmpty ? '📷 사진을 보냈어요' : typed, image: photo));
      _photo = null;
      _busy = true;
    });
    _toBottom();
    final user = ref.read(userDataProvider);
    final weather = ref.read(weatherProvider).valueOrNull;
    // 창고·밭은 이 화면에서 아직 안 불러왔을 수 있으니 기다려서 받는다 (예전에는 비어 있다고 잘못 답했다)
    final lots = await _orEmpty(ref.read(lotsProvider.future), const <Lot>[]);
    final plots = await _orEmpty(ref.read(plotsProvider.future), const <Plot>[]);
    final ctx = AiContext(
      prices: ref.read(marketViewModelProvider).valueOrNull ??
          const <String, AuctionPrice>{},
      money: user.money,
      lots: lots,
      plots: plots,
      items: {for (final e in user.items.entries) e.key: (e.value as num?)?.toInt() ?? 0},
      level: user.level.level,
      expLeft: user.level.need - user.level.exp,
      greenhouses: user.greenhouses,
      weather: weather == null
          ? null
          : '${weather.label} ${weather.tempC.round()}°C',
    );
    final a = await ref.read(aiAgentProvider).ask(typed, ctx, image: photo);
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, a));
      _busy = false;
    });
    _toBottom();
  }

  /// 📷 사진 고르기: 카메라로 찍거나 앨범에서 고른다
  Future<void> _pickPhoto() async {
    if (_busy) return;
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('사진으로 물어보기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('작물이나 잎·열매 사진을 올리면 함께 보고 답해요',
                style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
            const SizedBox(height: 10),
            ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.green),
                title: const Text('카메라로 찍기'),
                onTap: () => Navigator.pop(sheet, true)),
            ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.green),
                title: const Text('앨범에서 고르기'),
                onTap: () => Navigator.pop(sheet, false)),
          ]),
        ),
      ),
    );
    if (fromCamera == null || !mounted) return; // 닫았다
    try {
      final img =
          await ref.read(photoInputProvider).pick(fromCamera: fromCamera);
      if (!mounted) return;
      if (img != null) {
        setState(() => _photo = img);
      } else if (fromCamera) {
        // 카메라 앱이 사진 없이 닫혔다 (취소했거나, 카메라를 못 열었을 때)
        showMsg(context, '사진이 오지 않았어요. 카메라가 안 열리면 앨범에서 골라 보세요');
      }
    } catch (_) {
      if (mounted)
        showMsg(
            context,
            fromCamera
                ? '카메라를 열지 못했어요. 앨범에서 골라 보세요'
                : '사진을 가져오지 못했어요. 다시 해 주세요');
    }
  }

  /// 🎤 음성으로 질문하기: 누르면 듣기 시작하고, 말이 끝나면 알아들은 글로 바로 물어본다. 듣는 중에 다시 누르면 멈춘다.
  Future<void> _toggleVoice() async {
    if (_busy) return;
    final voice = ref.read(voiceInputProvider);
    if (_listening) {
      await _stopListening();
      return;
    }
    setState(() => _listening = true);
    await voice.start(
      onText: (text, done) {
        if (!mounted) return;
        setState(() => _ctrl.text = text); // 말하는 동안 글이 실시간으로 채워진다
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
        if (done) {
          setState(() => _listening = false);
          if (text.trim().isNotEmpty) _send();
        }
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _listening = false);
        showMsg(context, message);
      },
    );
  }

  Future<void> _stopListening() async {
    try {
      await ref.read(voiceInputProvider).stop();
    } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
          title: const Text('🤖 AI 도우미'),
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
          elevation: 0),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                    decoration: BoxDecoration(
                        color: m.mine ? AppColors.green : Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.image != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(m.image!.bytes,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                            height: 40, child: Text('📷 사진'))),
                              ),
                            ),
                          Text(m.text,
                              style: TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color:
                                      m.mine ? Colors.white : AppColors.ink)),
                        ]),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('답을 찾는 중…', style: TextStyle(color: AppColors.sub))),
          if (_listening)
            const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('🎤 듣고 있어요… 말씀해 주세요',
                    style: TextStyle(
                        color: AppColors.up, fontWeight: FontWeight.w800))),
          // 추천 질문: 옆으로 밀어서 더 볼 수 있다
          SizedBox(
            height: 64,
            child: ScrollConfiguration(
              // 손가락뿐 아니라 마우스·트랙패드로도 옆으로 밀 수 있게 한다 (에뮬레이터 포함)
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus
              }, scrollbars: false),
              child: Scrollbar(
                controller: _chips,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true, // 회색 막대를 손가락·마우스로 끌어서 옆으로 옮길 수 있다
                thickness: 8,
                radius: const Radius.circular(4),
                child: ListView.separated(
                  controller: _chips,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14), // 아래 14는 회색 막대 자리
                  itemCount: aiSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (emoji, text) = aiSuggestions[i];
                    return ActionChip(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.line),
                      label: Text('$emoji $text',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      onPressed: _busy ? null : () => _send(text),
                    );
                  },
                ),
              ),
            ),
          ),
          // 함께 보낼 사진 미리보기 (✕로 뺄 수 있다)
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_photo!.bytes,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 72,
                              height: 72,
                              child: Center(child: Text('📷'))))),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: GestureDetector(
                      onTap: () => setState(() => _photo = null),
                      child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                              color: AppColors.ink, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              IconButton(
                  onPressed: _busy ? null : _pickPhoto,
                  tooltip: '사진 올리기',
                  icon: const Icon(Icons.photo_camera_rounded,
                      color: AppColors.greenDark)),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: _photo == null
                        ? '무엇이 궁금한가요?'
                        : '사진에 대해 물어보세요 (안 적어도 돼요)',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _toggleVoice,
                tooltip: _listening ? '듣기 멈추기' : '음성으로 질문하기',
                icon: Icon(
                    _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    color: _listening ? AppColors.up : AppColors.greenDark),
              ),
              IconButton.filled(
                  onPressed: () => _send(),
                  icon: const Icon(Icons.send),
                  style:
                      IconButton.styleFrom(backgroundColor: AppColors.green)),
            ]),
          ),
        ]),
      ),
    );
  }
}
