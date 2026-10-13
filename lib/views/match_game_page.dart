import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_rules.dart' show cropOf, crops;
import '../core/match_logic.dart';
import '../core/progress_rules.dart';
import '../viewmodels/view_models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';

/// 작물 매칭 난이도: 작물 종류가 많고 판이 클수록, 시간이 짧고 힌트가 적을수록 어렵지만 점수 배율이 높다.
class MatchLevel {
  const MatchLevel(this.name, this.emoji, this.kinds, this.size, this.seconds,
      this.hintAfter, this.bonus);
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
const _matchDefaults = [
  'CABBAGE',
  'POTATO',
  'TOMATO',
  'APPLE',
  'ONION',
  'RADISH'
];

/// 고를 수 있는 모든 작물: 앞의 여섯 개는 난이도 기본 작물이고, 그 뒤로 새로 열린 작물이 이어진다.
final matchCrops = <String>[
  ..._matchDefaults,
  for (final c in crops)
    if (!_matchDefaults.contains(c.code)) c.code
];

/// 한 판에 고를 수 있는 작물 수 (최소 3종, 최대 6종)
const matchMaxCrops = 6;

/// 고를 수 있는 작물 수 (최소 3종, 최대 6종)
const matchMinCrops = 3;

/// 작물 목록이 규칙에 맞는지: 3~6종이고, 모두 판에 쓸 수 있는 작물이며, 겹치지 않는다.
bool validMatchCrops(List<String> crops) =>
    crops.length >= matchMinCrops &&
    crops.length <= matchMaxCrops &&
    crops.toSet().length == crops.length &&
    crops.every(matchCrops.contains);

/// 한 판을 모두 맞추면 다음 판으로 넘어가면서 더해 주는 시간(초)과 점수
const matchStageBonusSeconds = 15;
const matchStageBonusScore = 50;

/// 도중에 "저장하고 나가기"로 저장해 둔 게임. 다음에 들어오면 "이어서 하기"로 이어 할 수 있다.
class MatchSave {
  const MatchSave(
      {required this.level,
      required this.stage,
      required this.score,
      required this.left,
      required this.streak,
      required this.cells,
      required this.crops});
  final int level, stage, score, left, streak;

  /// 이 게임에서 고른 작물 (칸의 작물 번호는 이 목록의 순서를 따른다)
  final List<String> crops;

  /// 판의 칸마다 작물 번호 (비어 있으면 -1)
  final List<int> cells;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'level': level,
        'stage': stage,
        'score': score,
        'left': left,
        'streak': streak,
        'cells': cells,
        'crops': crops
      };

  /// 저장된 글이 깨졌거나 규칙에 맞지 않으면 null (이어 하기 대신 새로 시작하게 한다)
  static MatchSave? fromJson(Object? raw) {
    try {
      if (raw is! Map) return null;
      final level = (raw['level'] as num).toInt();
      if (level < 0 || level >= matchLevels.length) return null;
      final cells = [
        for (final v in (raw['cells'] as List)) (v as num).toInt()
      ];
      final lv = matchLevels[level];
      // 작물 목록이 없는 예전 저장은 난이도 기본 작물로 읽는다
      final rawCrops = raw['crops'];
      final crops = rawCrops is List
          ? [for (final c in rawCrops) '$c']
          : matchCrops.take(lv.kinds).toList();
      if (!validMatchCrops(crops)) return null;
      if (PairBoard.restore(lv.size, lv.size, crops.length, cells) == null) {
        return null;
      }
      final left = (raw['left'] as num).toInt();
      if (left <= 0) return null;
      return MatchSave(
        level: level,
        stage: ((raw['stage'] as num?)?.toInt() ?? 1).clamp(1, 9999).toInt(),
        score:
            ((raw['score'] as num?)?.toInt() ?? 0).clamp(0, 99999999).toInt(),
        left: left,
        streak: ((raw['streak'] as num?)?.toInt() ?? 0).clamp(0, 9999).toInt(),
        cells: cells,
        crops: crops,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 저장해 둔 게임을 기기에 읽고 쓴다. 계정마다 따로 저장한다. 저장 공간을 못 쓰는 환경에서도 앱이 멈추지 않게 모든 오류는 삼킨다.
class MatchSaveStore {
  static String get _key {
    var uid = 'guest';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    } catch (_) {}
    return 'match_pair_save_$uid';
  }

  static Future<MatchSave?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s == null) return null;
      final save = MatchSave.fromJson(jsonDecode(s));
      if (save == null) await prefs.remove(_key); // 깨진 저장은 지운다
      return save;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> save(MatchSave s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key, jsonEncode(s.toJson()));
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

/// 작물 매칭: 같은 작물 두 칸을 차례로 눌러 짝을 맞추는 퍼즐.
/// 양배추는 양배추끼리, 토마토는 토마토끼리, 감자는 감자끼리 맞추면 두 칸이 사라지고,
/// 한 판을 모두 맞추면 다음 판으로 넘어간다. 오늘 시세가 오른 작물을 맞추면 점수를 더 받는다.
/// 게임 도중에 나가면 "저장하고 나가기"로 저장해 두었다가 "이어서 하기"로 다시 할 수 있다.
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

  /// 이번 게임에서 맞출 작물 (직접 고를 수 있다. 난이도를 바꾸면 그 난이도의 기본 작물로 돌아간다)
  late List<String> _crops = matchCrops.take(_lv.kinds).toList();
  List<String> get _codes => _crops;

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

  late PairBoard _board = PairBoard(_rows, _cols, _crops.length);
  Timer? _timer;
  int _phase = 0; // 0 시작 전, 1 진행 중, 2 종료
  int _left = 180;
  int _score = 0;
  int _stage = 1; // 지금 몇 번째 판인지
  int _streak = 0; // 연속으로 맞춘 횟수
  int? _sel;
  bool? _rewarded;
  bool _settling = false;
  int _idle = 0; // 마지막으로 누른 뒤 지난 시간(초)
  (int, int)? _hint;
  String? _tip; // 방금 누른 결과 안내 ("두 칸이 맞춰졌어요!" 등)
  MatchSave? _saved; // 이어 할 수 있는 저장된 게임

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final s = await MatchSaveStore.load();
    if (mounted && _phase == 0) setState(() => _saved = s);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock =>
      '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  /// 처음 한 쌍에만 노란 힌트를 보여 주는 난이도(쉬움)인지
  bool get _firstHintLevel => _lv.hintAfter == 0;

  /// 처음 한 쌍을 이미 맞춰서 노란 힌트를 더는 보여 주지 않는지 (두 번째부터는 스스로 찾는다)
  bool _hintDone = false;

  String get _startTip =>
      _firstHintLevel ? '노랗게 반짝이는 두 칸이 첫 힌트예요. 다음부터는 마음대로 눌러 보세요' : '같은 작물 두 칸을 차례로 눌러 짝을 맞춰요';

  void _startTimer() {
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
          // 가만히 있으면 힌트를 보여 주는 난이도(보통)만. 쉬움(0초)은 처음 한 쌍에만 힌트라서 타이머로는 켜지 않는다.
          if (after != null && after > 0 && _idle >= after && _hint == null) {
            _hint = _board.findHint();
          }
        });
      }
    });
  }

  /// 새 게임 시작 (저장해 둔 게임은 지운다)
  void _start() {
    MatchSaveStore.clear();
    setState(() {
      _saved = null;
      _board = PairBoard(_rows, _cols, _crops.length);
      _phase = 1;
      _left = _lv.seconds;
      _score = 0;
      _stage = 1;
      _streak = 0;
      _sel = null;
      _rewarded = null;
      _idle = 0;
      _hintDone = false;
      _hint = _firstHintLevel ? _board.findHint() : null; // 노란 힌트는 첫 한 쌍에만
      _tip = _startTip;
    });
    _startTimer();
  }

  /// 저장해 둔 게임을 이어서 한다
  void _resume() {
    final s = _saved;
    if (s == null) return;
    final lv = matchLevels[s.level];
    final b = PairBoard.restore(lv.size, lv.size, s.crops.length, s.cells);
    if (b == null) {
      setState(() => _saved = null);
      MatchSaveStore.clear();
      return;
    }
    MatchSaveStore.clear(); // 이어 하는 순간 저장분은 쓴 것으로 친다 (다시 나갈 때 새로 저장한다)
    setState(() {
      _level = s.level;
      _crops = List<String>.of(s.crops);
      _board = b;
      _phase = 1;
      _left = s.left;
      _score = s.score;
      _stage = s.stage;
      _streak = s.streak;
      _sel = null;
      _rewarded = null;
      _idle = 0;
      _saved = null;
      _hintDone = true;
      _hint = null;
      _tip = '이어서 시작해요! 같은 작물 두 칸을 차례로 눌러 짝을 맞춰요';
    });
    _startTimer();
  }

  Future<void> _finish() async {
    if (_settling) return;
    _settling = true;
    MatchSaveStore.clear();
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
    if (_board.cells[idx] < 0) return; // 이미 맞춘 빈 칸
    final s = _sel;
    if (s == null) {
      setState(() {
        _sel = idx;
        _hint = _firstHintLevel && !_hintDone ? _hint : null; // 첫 한 쌍을 맞출 때까지는 노란 표시를 그대로 둔다
        _tip = '같은 작물을 하나 더 눌러요';
      });
      return;
    }
    if (s == idx) {
      setState(() => _sel = null);
      return;
    }
    final kind = _board.cells[s];
    if (_board.match(s, idx)) {
      _onMatched(kind);
    } else {
      setState(() {
        _sel = idx;
        _streak = 0;
        _tip = '같은 작물끼리만 맞출 수 있어요';
      });
    }
  }

  void _onMatched(int kind) {
    _hintDone = true; // 두 번째부터는 노란 표시 없음
    _streak++;
    final w = _weights();
    final base = 20 * (kind < w.length ? w[kind] : 1.0) * _lv.bonus;
    final streakBonus = (_streak - 1).clamp(0, 5).toInt() * 5;
    final pts = base.round() + streakBonus;
    _score += pts;
    _sel = null;
    if (_board.cleared) {
      _score += matchStageBonusScore;
      _left += matchStageBonusSeconds;
      _stage++;
      _board = PairBoard(_rows, _cols, _crops.length);
      _hint = null;
      _tip =
          '🎉 한 판 완성! 다음 판으로 넘어가요 (+$matchStageBonusScore점 · +$matchStageBonusSeconds초)';
    } else {
      _hint = null;
      _tip = _streak > 1 ? '짝이 맞았어요! $_streak연속 +$pts점' : '짝이 맞았어요! +$pts점';
    }
    setState(() {});
  }

  bool _isHint(int idx) {
    final h = _hint;
    return h != null && (h.$1 == idx || h.$2 == idx);
  }

  /// 게임 도중에 나가려 할 때: 저장하고 나가기 / 저장 없이 나가기 / 계속하기
  Future<void> _confirmExit() async {
    if (_phase != 1) {
      Navigator.of(context).pop();
      return;
    }
    _timer?.cancel(); // 물어보는 동안 시간은 멈춘다
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('게임을 나갈까요?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            '저장하고 나가면 다음에 "이어서 하기"로 이 판을 그대로 이어 할 수 있어요.\n저장하지 않고 나가면 보상을 받을 수 없어요.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
              width: double.infinity,
              child: GreenButton(
                  label: '저장하고 나가기',
                  height: 50,
                  onPressed: () => Navigator.pop(d, 'save'))),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: GreenButton(
                  label: '저장 안 하고 나가기',
                  height: 50,
                  outlined: true,
                  onPressed: () => Navigator.pop(d, 'discard'))),
          TextButton(
              onPressed: () => Navigator.pop(d, 'stay'),
              child: const Text('계속하기')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      final ok = await MatchSaveStore.save(MatchSave(
          level: _level,
          stage: _stage,
          score: _score,
          left: _left,
          streak: _streak,
          cells: List<int>.of(_board.cells),
          crops: List<String>.of(_crops)));
      if (!mounted) return;
      if (!ok) {
        showMsg(context, '저장하지 못했어요. 이 기기에서는 이어 하기를 쓸 수 없어요');
      } else {
        showMsg(context, '저장했어요! 다음에 "이어서 하기"로 계속할 수 있어요');
      }
      Navigator.of(context).pop();
    } else if (choice == 'discard') {
      Navigator.of(context).pop();
    } else {
      _startTimer(); // 계속하기
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDataProvider);
    final tag = dayTag(DateTime.now());
    final playedToday = periodCount(user.daily, tag, 'game');
    final leftToday = (gameDailyRewardLimit - playedToday)
        .clamp(0, gameDailyRewardLimit)
        .toInt();

    return PopScope(
      canPop: _phase != 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(children: [
              PageHeader(
                title: '작물 매칭',
                onBack: _confirmExit,
                trailing: PointPill(points: user.points),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Expanded(child: _stat('⏱️', '남은 시간', _clock)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _stat('⭐', _phase == 1 ? '점수 · $_stage판' : '점수',
                          commaNum(_score))),
                ]),
              ),
              // 오늘 시세에 따른 작물별 점수 배율 (오른 작물을 맞추면 점수가 더 높다)
              _legend(),
              // 방금 한 행동에 대한 안내
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_tip ?? ' ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.greenDark)),
              ),
              Expanded(
                // 시작 전·끝난 뒤에는 판 대신 안내 카드를 판 자리 전체에 크게 보여 준다 (글씨를 줄이지 않고, 길면 스크롤)
                child: _phase != 1
                    ? _overlayCard(leftToday)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _cols / _rows,
                            child: Stack(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.line)),
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
                            ]),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
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
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CropArt(code: codes[i], size: 28),
                  Text(
                    ch[i] == null
                        ? '시세 –'
                        : '${ch[i]! >= 0 ? '▲' : '▼'}${ch[i]!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ch[i] == null
                            ? AppColors.sub
                            : (ch[i]! >= 0 ? AppColors.up : AppColors.down)),
                  ),
                  Text('×${w[i].toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _cell(int r, int c) {
    final idx = r * _cols + c;
    final kind = _board.cells[idx];
    final margin = EdgeInsets.all(_rows > 5 ? 2 : 3);
    if (kind < 0) return Container(margin: margin); // 이미 맞춘 칸은 비어 있다
    final selected = _sel == idx;
    final hint = _isHint(idx);
    return Container(
      margin: margin,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.greenLight
            : (hint ? const Color(0xFFFFF3B0) : AppColors.bg),
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? Border.all(color: AppColors.green, width: 3)
            : (hint ? Border.all(color: AppColors.coin, width: 3) : null),
        boxShadow: hint
            ? [
                BoxShadow(
                    color: AppColors.coin.withValues(alpha: .6), blurRadius: 10)
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
            builder: (_, box) =>
                CropArt(code: _crops[kind], size: box.biggest.shortestSide)),
      ),
    );
  }

  Widget _stat(String emoji, String label, String value) => SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF000000),
                      fontWeight: FontWeight.w700)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF000000))),
            ]),
          ),
        ]),
      );

  /// 시작 전·끝난 뒤 안내 카드: 불투명한 흰 카드가 판 자리 전체를 쓰고, 글씨는 원래 크기 그대로 두며 내용이 길면 스크롤된다.
  Widget _overlayCard(int leftToday) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: _overlay(leftToday),
            ),
          ),
        ),
      );

  /// 플레이할 작물 고르기: 눌러서 켜고 끈다 (3~6종). 고른 작물만 판에 나온다.
  Widget _cropPicker() => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('플레이할 작물 고르기 (${_crops.length}종 · 3~6종)',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF000000))),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final code in matchCrops)
              SizedBox(width: 56, child: _cropChip(code)),
          ],
        ),
      ]);

  Widget _cropChip(String code) {
    final on = _crops.contains(code);
    return GestureDetector(
      onTap: () => _toggleCrop(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppColors.greenLight : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: on ? AppColors.green : AppColors.line,
              width: on ? 2.5 : 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Opacity(opacity: on ? 1 : .4, child: CropArt(code: code, size: 32)),
          const SizedBox(height: 2),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(cropOf(code).name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: on ? AppColors.greenDark : AppColors.sub))),
        ]),
      ),
    );
  }

  void _toggleCrop(String code) {
    final next = List<String>.of(_crops);
    if (next.contains(code)) {
      if (next.length <= matchMinCrops) {
        showMsg(context, '작물은 최소 $matchMinCrops종은 골라야 해요');
        return;
      }
      next.remove(code);
    } else {
      next.add(code);
    }
    // 항상 같은 순서로 두어서 저장·시세 배율 표시가 흔들리지 않게 한다
    final ordered = [
      for (final c in matchCrops)
        if (next.contains(c)) c
    ];
    setState(() {
      _crops = ordered;
      _board = PairBoard(_rows, _cols, _crops.length);
    });
  }

  /// 난이도 고르기 (시작 화면)
  Widget _levelPicker() => Row(children: [
        for (var i = 0; i < matchLevels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _level = i;
                _crops = matchCrops.take(_lv.kinds).toList();
                _board = PairBoard(_rows, _cols, _crops.length);
                _left = _lv.seconds;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _level == i ? AppColors.green : AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _level == i ? AppColors.greenDark : AppColors.line,
                      width: 2),
                ),
                child: Column(children: [
                  Text(matchLevels[i].emoji,
                      style: const TextStyle(fontSize: 22)),
                  Text(matchLevels[i].name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _level == i
                              ? Colors.white
                              : const Color(0xFF000000))),
                ]),
              ),
            ),
          ),
        ],
      ]);

  Widget _overlay(int leftToday) {
    if (_phase == 0) {
      final lv = _lv;
      final s = _saved;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🧩', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 4),
        const Text('작물 매칭',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF000000))),
        const SizedBox(height: 10),
        if (s != null) ...[
          // 저장해 둔 게임이 있으면 이어서 할 수 있다
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF6DF),
                borderRadius: BorderRadius.circular(14)),
            child: Text(
                '저장된 게임이 있어요\n${matchLevels[s.level].name} · ${s.stage}판 · ${commaNum(s.score)}점 · 남은 ${(s.left ~/ 60).toString().padLeft(2, '0')}:${(s.left % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: AppColors.greenDark)),
          ),
          const SizedBox(height: 10),
          GreenButton(label: '이어서 하기', height: 56, onPressed: _resume),
          const SizedBox(height: 14),
        ],
        _levelPicker(),
        const SizedBox(height: 10),
        _cropPicker(),
        const SizedBox(height: 10),
        KoText(
          '작물 ${_crops.length}종 · ${lv.size}×${lv.size}칸 · ${lv.seconds ~/ 60}분 ${lv.seconds % 60 == 0 ? '' : '${lv.seconds % 60}초 '}\n'
          '같은 작물 두 칸을 눌러 짝을 맞춰요. 한 판을 다 맞추면 다음 판!\n'
          '${lv.hintAfter == 0 ? '처음 한 쌍만 노란 힌트가 나와요' : lv.hintAfter == null ? '힌트 없음 (점수 ×${lv.bonus})' : '${lv.hintAfter}초 가만히 있으면 힌트 (점수 ×${lv.bonus})'}\n'
          '오늘 시세가 오른 작물(▲)을 맞추면 점수가 최대 2배!',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
            leftToday > 0
                ? '오늘 보상 받을 수 있는 횟수 $leftToday번'
                : '오늘 보상은 모두 받았어요 (연습 플레이는 가능)',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.greenDark)),
        const SizedBox(height: 14),
        GreenButton(
            label: s != null ? '새로 시작하기' : '시작하기',
            height: 56,
            outlined: s != null,
            onPressed: _start),
      ]);
    }
    final money = gameRewardMoney(_score), pts = gameRewardPoints(_score);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎉', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 8),
      const Text('시간 종료!',
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000))),
      const SizedBox(height: 8),
      Text('점수 ${commaNum(_score)}점 · $_stage판까지 도전',
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF000000))),
      const SizedBox(height: 8),
      if (_rewarded == null)
        const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4))
      else if (_rewarded == true)
        Text('보상 ${won(money)} + ${pts}P',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.greenDark))
      else
        const Text('오늘 보상 횟수를 모두 썼어요',
            style: TextStyle(
                fontSize: 16,
                color: Color(0xFF000000),
                fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      _levelPicker(),
      const SizedBox(height: 10),
      _cropPicker(),
      const SizedBox(height: 12),
      GreenButton(
          label: '다시 하기', height: 54, onPressed: _settling ? null : _start),
      const SizedBox(height: 8),
      GreenButton(
          label: '나가기',
          height: 54,
          outlined: true,
          onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
