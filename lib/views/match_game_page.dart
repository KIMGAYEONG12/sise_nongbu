import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/match_logic.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';

/// 작물 매칭 난이도: 작물 종류가 많고 판이 클수록, 시간이 짧고 힌트가 적을수록 어렵지만 점수 배율이 높다.
class MatchLevel {
  const MatchLevel(this.name, this.emoji, this.kinds, this.size, this.seconds, this.hintAfter, this.bonus);
  final String name, emoji;

  /// 나오는 작물 종류 수 (3~6)
  final int kinds;

  /// 판 한 변의 칸 수 (size × size)
  final int size;
  final int seconds;

  /// 이 시간(초) 동안 아무것도 안 누르면 힌트를 보여준다. 0이면 처음부터 계속, null이면 힌트 없음.
  final int? hintAfter;

  /// 점수 배율
  final double bonus;
}

const matchLevels = [
  MatchLevel('쉬움', '🌱', 4, 5, 180, 0, 1.0),
  MatchLevel('보통', '🌿', 5, 6, 150, 8, 1.3),
  MatchLevel('어려움', '🔥', 6, 6, 120, null, 1.7),
];

/// 판에 나오는 작물 (앞에서부터 난이도의 종류 수만큼 쓴다). 칸의 그림과 시세가 짝이 된다.
/// 쉬움(4종)에도 배추·토마토뿐 아니라 감자·사과가 나오도록 섞어 두었다.
const matchCrops = ['CABBAGE', 'POTATO', 'TOMATO', 'APPLE', 'ONION', 'RADISH'];

/// 작물 매칭: 인접한 두 칸을 바꿔 같은 작물 3개 이상을 맞추는 퍼즐.
/// 난이도(쉬움·보통·어려움)에 따라 작물 종류·판 크기·시간·힌트가 달라지고,
/// 오늘 시세가 오른 작물을 맞추면 점수를 더 받는다.
class MatchGamePage extends ConsumerStatefulWidget {
  const MatchGamePage({super.key});
  @override
  ConsumerState<MatchGamePage> createState() => _MatchGamePageState();
}

class _MatchGamePageState extends ConsumerState<MatchGamePage> {
  int _level = 0;
  MatchLevel get _lv => matchLevels[_level];
  int get _rows => _lv.size;
  int get _cols => _lv.size;
  List<String> get _codes => matchCrops.take(_lv.kinds).toList();

  /// 작물별 오늘 시세 변동률(%). 시세를 아직 모르면 null.
  List<double?> _changes() {
    final prices = ref.read(marketViewModelProvider).valueOrNull;
    return [
      for (final c in _codes)
        () {
          final p = prices?[c];
          return p == null ? null : changePercent(p.pricePerKg, p.prevPerKg);
        }()
    ];
  }

  List<double> _weights() => [for (final p in _changes()) matchWeight(p)];

  late MatchBoard _board = MatchBoard(_rows, _cols, _lv.kinds);
  Timer? _timer;
  int _phase = 0; // 0 시작 전, 1 진행 중, 2 종료
  int _left = 180;
  int _score = 0;
  int? _sel;
  bool? _rewarded;
  bool _settling = false;
  int _idle = 0; // 마지막으로 누른 뒤 지난 시간(초)
  (int, int, int, int)? _hint;
  String? _tip; // 방금 누른 결과 안내 ("3개가 맞춰졌어요!" 등)

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock => '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  /// 힌트를 항상 켜 두는 난이도(쉬움)인지
  bool get _alwaysHint => _lv.hintAfter == 0;

  void _start() {
    setState(() {
      _board = MatchBoard(_rows, _cols, _lv.kinds);
      if (!_board.hasMove()) _board.shuffle();
      _phase = 1;
      _left = _lv.seconds;
      _score = 0;
      _sel = null;
      _rewarded = null;
      _idle = 0;
      _hint = _alwaysHint ? _board.findHint() : null;
      _tip = _alwaysHint ? '반짝이는 두 칸을 차례로 눌러 보세요' : '옆 칸과 자리를 바꿔 같은 작물 3개를 맞춰요';
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
        _finish();
      } else {
        setState(() {
          _left--;
          _idle++;
          final after = _lv.hintAfter;
          if (after != null && _idle >= after && _hint == null) _hint = _board.findHint();
        });
      }
    });
  }

  Future<void> _finish() async {
    if (_settling) return;
    _settling = true;
    setState(() {
      _phase = 2;
      _sel = null;
      _hint = null;
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
    _idle = 0;
    final idx = r * _cols + c;
    final s = _sel;
    if (s == null) {
      setState(() {
        _sel = idx;
        _hint = _alwaysHint ? _hint : null;
        _tip = '옆 칸을 눌러 자리를 바꿔요';
      });
      return;
    }
    if (s == idx) {
      setState(() => _sel = null);
      return;
    }
    final r0 = s ~/ _cols, c0 = s % _cols;
    if (!_board.adjacent(r0, c0, r, c)) {
      setState(() {
        _sel = idx;
        _tip = '바로 옆(위·아래·좌·우) 작물을 눌러야 해요';
      });
      return;
    }
    final res = _board.trySwap(r0, c0, r, c);
    setState(() {
      _sel = null;
      if (res != null) {
        final pts = (res.scoreWith(_weights()) * _lv.bonus).round();
        _score += pts;
        _tip = '${res.cleared}개가 맞춰졌어요! +$pts점';
        if (!_board.hasMove()) _board.shuffle();
        _hint = _alwaysHint ? _board.findHint() : null;
      } else {
        _tip = _alwaysHint ? '반짝이는 두 칸을 눌러 보세요' : '맞춰지지 않아요. 다른 칸을 바꿔 보세요';
        _hint = _alwaysHint ? _board.findHint() : null;
      }
    });
  }

  bool _isHint(int r, int c) {
    final h = _hint;
    return h != null && ((h.$1 == r && h.$2 == c) || (h.$3 == r && h.$4 == c));
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
            // 오늘 시세에 따른 작물별 점수 배율 (오른 작물을 맞추면 점수가 더 높다)
            _legend(),
            // 방금 한 행동에 대한 안내 (글씨 크게)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(_tip ?? ' ', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.greenDark)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _cols / _rows,
                    child: Stack(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                        child: Column(children: [
                          for (var r = 0; r < _rows; r++)
                            Expanded(
                              child: Row(children: [
                                for (var c = 0; c < _cols; c++)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _tap(r, c),
                                      child: _cell(r, c),
                                    ),
                                  ),
                              ]),
                            ),
                        ]),
                      ),
                      if (_phase != 1)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .96), borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.all(16),
                            // 칸이 작은 화면에서도 안내 글이 잘리거나 넘치지 않게 알맞게 줄인다
                            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 300, child: _overlay(leftToday)))),
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

  /// 작물마다 그림 + 오늘 시세 변동 + 점수 배율을 보여주는 한 줄
  Widget _legend() {
    ref.watch(marketViewModelProvider); // 시세가 도착하면 다시 그린다
    final ch = _changes();
    final w = _weights();
    final codes = _codes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(children: [
        for (var i = 0; i < codes.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CropArt(code: codes[i], size: 28),
                  Text(
                    ch[i] == null ? '시세 –' : '${ch[i]! >= 0 ? '▲' : '▼'}${ch[i]!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: ch[i] == null ? AppColors.sub : (ch[i]! >= 0 ? AppColors.up : AppColors.down)),
                  ),
                  Text('×${w[i].toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _cell(int r, int c) {
    final selected = _sel == r * _cols + c;
    final hint = _isHint(r, c);
    final kind = _board.at(r, c);
    return Container(
      margin: EdgeInsets.all(_rows > 5 ? 2 : 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.greenLight : (hint ? const Color(0xFFFFF3B0) : AppColors.bg),
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? Border.all(color: AppColors.green, width: 3)
            : (hint ? Border.all(color: AppColors.coin, width: 3) : null),
        boxShadow: hint ? [BoxShadow(color: AppColors.coin.withValues(alpha: .6), blurRadius: 10)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(builder: (_, box) => CropArt(code: matchCrops[kind], size: box.biggest.shortestSide)),
      ),
    );
  }

  Widget _stat(String emoji, String label, String value) => SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF000000), fontWeight: FontWeight.w700)),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
            ]),
          ),
        ]),
      );

  /// 난이도 고르기 (시작 화면)
  Widget _levelPicker() => Row(children: [
        for (var i = 0; i < matchLevels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _level = i;
                _board = MatchBoard(_rows, _cols, _lv.kinds);
                _left = _lv.seconds;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _level == i ? AppColors.green : AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _level == i ? AppColors.greenDark : AppColors.line, width: 2),
                ),
                child: Column(children: [
                  Text(matchLevels[i].emoji, style: const TextStyle(fontSize: 22)),
                  Text(matchLevels[i].name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _level == i ? Colors.white : const Color(0xFF000000))),
                ]),
              ),
            ),
          ),
        ],
      ]);

  Widget _overlay(int leftToday) {
    if (_phase == 0) {
      final lv = _lv;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🧩', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 4),
        const Text('작물 매칭', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
        const SizedBox(height: 10),
        _levelPicker(),
        const SizedBox(height: 10),
        KoText(
          '작물 ${lv.kinds}종 · ${lv.size}×${lv.size}칸 · ${lv.seconds ~/ 60}분 ${lv.seconds % 60 == 0 ? '' : '${lv.seconds % 60}초 '}\n'
          '${lv.hintAfter == 0 ? '힌트가 계속 반짝여요' : lv.hintAfter == null ? '힌트 없음 (점수 ×${lv.bonus})' : '${lv.hintAfter}초 가만히 있으면 힌트 (점수 ×${lv.bonus})'}\n'
          '오늘 시세가 오른 작물(▲)을 맞추면 점수가 최대 2배!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF000000), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(leftToday > 0 ? '오늘 보상 받을 수 있는 횟수 $leftToday번' : '오늘 보상은 모두 받았어요 (연습 플레이는 가능)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
        const SizedBox(height: 14),
        GreenButton(label: '시작하기', height: 56, onPressed: _start),
      ]);
    }
    final money = gameRewardMoney(_score), pts = gameRewardPoints(_score);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎉', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 8),
      const Text('시간 종료!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
      const SizedBox(height: 8),
      Text('점수 ${commaNum(_score)}점', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF000000))),
      const SizedBox(height: 8),
      if (_rewarded == null)
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
      else if (_rewarded == true)
        Text('보상 ${won(money)} + ${pts}P', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.greenDark))
      else
        const Text('오늘 보상 횟수를 모두 썼어요', style: TextStyle(fontSize: 16, color: Color(0xFF000000), fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      _levelPicker(),
      const SizedBox(height: 12),
      GreenButton(label: '다시 하기', height: 54, onPressed: _settling ? null : _start),
      const SizedBox(height: 8),
      GreenButton(label: '나가기', height: 54, outlined: true, onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
