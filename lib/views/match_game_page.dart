import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/match_logic.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';

/// 작물 매칭: 인접한 두 칸을 바꿔 같은 작물 3개 이상을 맞추는 90초 퍼즐
class MatchGamePage extends ConsumerStatefulWidget {
  const MatchGamePage({super.key});
  @override
  ConsumerState<MatchGamePage> createState() => _MatchGamePageState();
}

class _MatchGamePageState extends ConsumerState<MatchGamePage> {
  static const _emojis = ['🥬', '🍎', '🍅', '🧅', '🥔'];
  static const _rows = 7, _cols = 6, _seconds = 90;

  late MatchBoard _board = MatchBoard(_rows, _cols, _emojis.length);
  Timer? _timer;
  int _phase = 0; // 0 시작 전, 1 진행 중, 2 종료
  int _left = _seconds;
  int _score = 0;
  int? _sel;
  bool? _rewarded;
  bool _settling = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock => '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  void _start() {
    setState(() {
      _board = MatchBoard(_rows, _cols, _emojis.length);
      _phase = 1;
      _left = _seconds;
      _score = 0;
      _sel = null;
      _rewarded = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
        _finish();
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _finish() async {
    if (_settling) return;
    _settling = true;
    setState(() {
      _phase = 2;
      _sel = null;
    });
    try {
      final r = await ref.read(farmViewModelProvider).gameReward(_score);
      if (mounted) setState(() => _rewarded = r);
    } catch (e) {
      if (mounted) showMsg(context, errMsg(e));
    }
    _settling = false;
  }

  void _tap(int r, int c) {
    if (_phase != 1) return;
    final idx = r * _cols + c;
    final s = _sel;
    if (s == null) {
      setState(() => _sel = idx);
      return;
    }
    if (s == idx) {
      setState(() => _sel = null);
      return;
    }
    final r0 = s ~/ _cols, c0 = s % _cols;
    if (!_board.adjacent(r0, c0, r, c)) {
      setState(() => _sel = idx);
      return;
    }
    final res = _board.trySwap(r0, c0, r, c);
    setState(() {
      _sel = null;
      if (res != null) {
        _score += res.score;
        if (!_board.hasMove()) _board.shuffle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final tag = dayTag(DateTime.now());
    final playedToday = periodCount(user.daily, tag, 'game');
    final leftToday = (gameDailyRewardLimit - playedToday).clamp(0, gameDailyRewardLimit).toInt();

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            PageHeader(
              title: '작물 매칭',
              onBack: () {
                if (_phase == 1) {
                  showMsg(context, '진행 중인 게임을 나가면 보상을 받을 수 없어요');
                }
                Navigator.of(context).pop();
              },
              trailing: PointPill(points: user.points),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(child: _stat('⏱️', '남은 시간', _clock)),
                const SizedBox(width: 10),
                Expanded(child: _stat('⭐', '점수', commaNum(_score))),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _cols / _rows,
                    child: Stack(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                        child: Column(children: [
                          for (var r = 0; r < _rows; r++)
                            Expanded(
                              child: Row(children: [
                                for (var c = 0; c < _cols; c++)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _tap(r, c),
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _sel == r * _cols + c ? AppColors.greenLight : AppColors.bg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: _sel == r * _cols + c ? Border.all(color: AppColors.green, width: 2) : null,
                                        ),
                                        child: FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Text(_emojis[_board.at(r, c)], style: const TextStyle(fontSize: 30)))),
                                      ),
                                    ),
                                  ),
                              ]),
                            ),
                        ]),
                      ),
                      if (_phase != 1)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .93), borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.all(20),
                            child: _overlay(leftToday),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String emoji, String label, String value) => SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      );

  Widget _overlay(int leftToday) {
    if (_phase == 0) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🧩', style: TextStyle(fontSize: 54)),
        const SizedBox(height: 8),
        const Text('작물 매칭', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('인접한 작물 두 개를 눌러 자리를 바꾸고\n같은 작물 3개 이상을 맞춰요.\n제한 시간 $_clock', textAlign: TextAlign.center, style: const TextStyle(height: 1.5, color: AppColors.sub)),
        const SizedBox(height: 6),
        Text(leftToday > 0 ? '오늘 보상 받을 수 있는 횟수 $leftToday번' : '오늘 보상은 모두 받았어요 (연습 플레이는 가능)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
        const SizedBox(height: 16),
        GreenButton(label: '시작하기', onPressed: _start),
      ]);
    }
    final money = gameRewardMoney(_score), pts = gameRewardPoints(_score);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎉', style: TextStyle(fontSize: 54)),
      const SizedBox(height: 8),
      const Text('시간 종료!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('점수 ${commaNum(_score)}점', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (_rewarded == null)
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
      else if (_rewarded == true)
        Text('보상 ${won(money)} + ${pts}P', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenDark))
      else
        const Text('오늘 보상 횟수를 모두 썼어요', style: TextStyle(color: AppColors.sub)),
      const SizedBox(height: 16),
      GreenButton(label: '다시 하기', onPressed: _settling ? null : _start),
      const SizedBox(height: 8),
      GreenButton(label: '나가기', outlined: true, onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
