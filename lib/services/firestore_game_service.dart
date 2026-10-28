import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/game_rules.dart';
import '../core/progress_rules.dart';
import '../core/korean.dart';
import '../models/models.dart';

Map<String, dynamic>? _asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// 닉네임을 정하지 않은 농부의 기본 이름 (MY 화면에서 바꿀 수 있다)
const defaultNickname = '농부이서';

Map<String, dynamic> _emptyPlot() =>
    {'cropCode': null, 'status': 'empty', 'plantedAt': null, 'readyAt': null, 'growMs': 0, 'bonus': 0, 'watered': 0, 'boosted': false};

class FirestoreGameService {
  FirestoreGameService(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> get _user => db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> get _fund => db.collection('community').doc('fund');
  CollectionReference<Map<String, dynamic>> _col(String n) => _user.collection(n);
  /// Firestore 트랜잭션. 일시적인 오류(unknown·aborted·unavailable 등)는 잠깐 쉬었다가 최대 3번까지 다시 시도한다.
  /// (에뮬레이터나 불안정한 네트워크에서 [cloud_firestore/unknown] null 같은 오류가 한 번 나고 지나가는 일이 있어서)
  Future<T> _tx<T>(Future<T> Function(Transaction tx) handler) async {
    for (var attempt = 0;; attempt++) {
      // 규칙 위반(예: "포인트가 부족합니다")으로 던진 StateError는 Firestore가 "[cloud_firestore/unknown] null"로 바꿔 버리므로,
      // 던질 때 따로 붙잡아 두었다가 그 문구를 그대로 사용자에게 돌려준다. (다시 시도하지도 않는다)
      StateError? rule;
      try {
        return await db.runTransaction<T>((tx) async {
          try {
            return await handler(tx);
          } on StateError catch (e) {
            rule = e;
            rethrow;
          }
        });
      } on FirebaseException catch (e) {
        final r = rule;
        if (r != null) throw r;
        const retryable = {'unknown', 'aborted', 'unavailable', 'deadline-exceeded', 'internal'};
        if (!retryable.contains(e.code) || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  /// 이미 있는 농장에 물통·영양제·성장촉진제를 10개씩 한 번만 채워 준다 (10개보다 적을 때만 10개로).
  Future<void> _giveStarterItems() async {
    await db.runTransaction((tx) async {
      final u = (await tx.get(_user)).data() ?? {};
      if (_int(u['starterItems']) >= 1) return;
      final items = _asMap(u['items']) ?? {};
      final upd = <String, dynamic>{'starterItems': 1};
      for (final k in starterItemKeys) {
        if (_int(items[k]) < starterItemCount) upd['items.$k'] = starterItemCount;
      }
      tx.update(_user, upd);
    });
  }

  /// 처음 로그인한 사용자의 문서와 밭을 만든다. 이미 있으면 닉네임이 비어 있을 때만 채운다.
  Future<void> ensureUser({String? nickname}) async {
    final name = (nickname != null && nickname.trim().isNotEmpty) ? nickname.trim() : null;
    const fallback = defaultNickname;
    // 예전에 자동으로 붙던 이름 (예: 농부UcHh) — 이런 이름은 기본 닉네임으로 바꿔 준다
    final oldAuto = '농부${uid.substring(0, uid.length < 4 ? uid.length : 4)}';
    final snap = await _user.get();
    if (snap.exists) {
      final cur = snap.data()?['nickname'];
      if (cur == null || cur == '' || cur == oldAuto) await _user.update({'nickname': name ?? fallback});
      await _giveStarterItems();
      return;
    }
    final b = db.batch();
    b.set(_user, {
      'money': startMoney,
      'totalProfit': 0,
      'exp': 0,
      'points': 0,
      'nickname': name ?? fallback,
      'warehouseLevel': 0,
      'warehouseBonusKg': 0,
      'greenhouse': false,
      'greenhouses': 0,
      'decor': 0,
      'items': <String, dynamic>{for (final k in starterItemKeys) k: starterItemCount},
      'starterItems': 1,
      'stats': <String, dynamic>{},
      'fundGiven': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < plotCount; i++) {
      b.set(_col('plots').doc('$i'), _emptyPlot());
    }
    await b.commit();
  }

  /// 테스트 도구: 보유 자금을 시작 자금(100,000원)으로 되돌린다.
  Future<void> resetMoney() => _user.update({'money': startMoney, 'updatedAt': FieldValue.serverTimestamp()});

  /// 성장 시간이 줄어든 작물(예: 배추 4시간 → 50분)이 예전 시간으로 심겨 있으면 새 시간에 맞춘다.
  /// 바뀐 밭의 (번호, 작물, 새 수확 시각)을 돌려준다.
  Future<List<(int, CropSpec, DateTime)>> fitGrowTimes({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final snap = await _col('plots').get();
    final b = db.batch();
    final changed = <(int, CropSpec, DateTime)>[];
    for (final d in snap.docs) {
      final m = d.data();
      final code = m['cropCode'];
      if (code is! String) continue;
      final idx = int.tryParse(d.id);
      if (idx == null) continue;
      CropSpec c;
      try {
        c = cropOf(code);
      } catch (_) {
        continue;
      }
      final ready = (m['readyAt'] as Timestamp?)?.toDate();
      if (ready == null || !ready.isAfter(t)) continue;
      final full = c.growMinutes * 60 * 1000;
      final growMs = _int(m['growMs']);
      if (growMs <= full) continue;
      final planted = ready.subtract(Duration(milliseconds: growMs));
      var r = planted.add(Duration(milliseconds: full));
      if (r.isBefore(t)) r = t;
      if (!r.isBefore(ready)) continue;
      b.update(d.reference, {'readyAt': Timestamp.fromDate(r), 'growMs': full});
      changed.add((idx, c, r));
    }
    if (changed.isNotEmpty) await b.commit();
    return changed;
  }

  Future<void> setNickname(String name) => _user.update({'nickname': name.trim(), 'updatedAt': FieldValue.serverTimestamp()});

  /// 프로필 캐릭터 고르기 ('girl' 또는 'boy')
  Future<void> setAvatar(bool boy) => _user.update({'avatar': boy ? 'boy' : 'girl', 'updatedAt': FieldValue.serverTimestamp()});

  /// 칭호 장착 ([index]가 null이면 자동: 레벨에 맞는 가장 높은 칭호). 아직 얻지 못한 칭호는 장착할 수 없다.
  Future<void> setTitle(int? index) => _tx((tx) async {
        final u = (await tx.get(_user)).data()!;
        if (index != null) {
          if (index < 0 || index >= farmerTitles.length) throw StateError('없는 칭호예요');
          if (levelInfo(_int(u['exp'])).level < farmerTitles[index].minLevel) throw StateError('아직 얻지 못한 칭호예요');
        }
        tx.update(_user, {'titleIdx': index ?? FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()});
      });

  Stream<Map<String, dynamic>> user() => _user.snapshots().map((s) => s.data() ?? {});
  Stream<List<Plot>> plots() => _col('plots').snapshots().map((s) => s.docs.map(Plot.fromDoc).toList()..sort((a, b) => a.index - b.index));
  Stream<List<Lot>> lots() => _col('inventory').snapshots().map((s) => s.docs.map(Lot.fromDoc).toList());
  Stream<List<Trade>> trades() =>
      _col('trades').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(Trade.fromDoc).toList());
  Stream<FundData> fund() => _fund.snapshots().map((s) => FundData.fromMap(s.data()));

  /// 미션 카운터(일일·주간)를 한 번에 올리는 업데이트 항목
  Map<String, dynamic> _bumps(Map<String, dynamic> u, DateTime t, List<String> keys, {String? plantedCrop}) {
    var d = _asMap(u['daily']);
    var w = _asMap(u['weekly']);
    if (plantedCrop != null) {
      d = bumpVariety(d, dayTag(t), plantedCrop);
      w = bumpVariety(w, weekTag(t), plantedCrop);
    }
    for (final k in keys) {
      d = bumpPeriod(d, dayTag(t), k);
      w = bumpPeriod(w, weekTag(t), k);
    }
    return {'daily': d, 'weekly': w};
  }

  // ───────────────────────── 파종·수확·출하 ─────────────────────────

  /// 씨앗이 있으면 씨앗을 쓰고, 없으면 파종비를 낸다.
  Future<void> plant(int idx, CropSpec c, DateTime readyAt, {DateTime? now}) => _tx((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final money = _int(u['money']);
        final key = seedKey(c.code);
        final seeds = _int(_asMap(u['items'])?[key]);
        final useSeed = seeds > 0;
        if (!useSeed && money < c.seedCost) throw StateError('포인트가 부족합니다');
        final upd = <String, dynamic>{
          'money': useSeed ? money : money - c.seedCost,
          'totalProfit': _int(u['totalProfit']) - (useSeed ? 0 : c.seedCost),
          'exp': _int(u['exp']) + 5 * expBoost,
          'stats.plant': FieldValue.increment(1),
          ..._bumps(u, t, ['plant'], plantedCrop: c.code),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (useSeed) upd['items.$key'] = seeds - 1;
        tx.update(_user, upd);
        tx.set(_col('plots').doc('$idx'), {
          'cropCode': c.code,
          'status': 'growing',
          'plantedAt': FieldValue.serverTimestamp(),
          'readyAt': Timestamp.fromDate(readyAt),
          'growMs': readyAt.difference(t).inMilliseconds,
          'bonus': 0,
          'watered': 0,
          'boosted': false,
          'usedSeed': useSeed, // 다시 심기(뽑기) 때 무엇을 돌려줄지 판단
          'paid': useSeed ? 0 : c.seedCost,
        });
      });

  /// 잘못 심은 작물을 뽑아 밭을 비운다. 심은 지 [uprootRefundWindow] 안이면 파종비(또는 씨앗)를 돌려준다.
  /// 돌려준 내용을 사용자에게 보여줄 문구로 돌려준다.
  Future<String> uproot(int idx, {DateTime? now}) => _tx<String>((tx) async {
        final t = now ?? DateTime.now();
        final plotRef = _col('plots').doc('$idx');
        final pm = (await tx.get(plotRef)).data() ?? {};
        final code = pm['cropCode'];
        if (code is! String) throw StateError('비어 있는 밭이에요');
        final c = cropOf(code);
        final ready = (pm['readyAt'] as Timestamp?)?.toDate();
        if (ready != null && !t.isBefore(ready)) throw StateError('다 자란 작물은 뽑지 말고 수확해 주세요');
        final u = (await tx.get(_user)).data()!;
        final planted = (pm['plantedAt'] as Timestamp?)?.toDate();
        final refund = planted != null && t.difference(planted) <= uprootRefundWindow;
        final upd = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
        var msg = '${withJosa(c.name, '을', '를')} 뽑았어요. 빈 밭에 다시 심어 주세요';
        if (refund) {
          // 파종으로 얻은 경험치는 되돌린다 (심었다 뽑기를 반복해 경험치를 얻지 못하게)
          final exp = _int(u['exp']) - 5 * expBoost;
          upd['exp'] = exp < 0 ? 0 : exp;
          if (pm['usedSeed'] == true) {
            upd['items.${seedKey(code)}'] = FieldValue.increment(1);
            msg = '${withJosa(c.name, '을', '를')} 뽑고 씨앗 1개를 돌려받았어요';
          } else {
            final paid = pm['paid'] is num ? (pm['paid'] as num).toInt() : c.seedCost;
            upd['money'] = _int(u['money']) + paid;
            upd['totalProfit'] = _int(u['totalProfit']) + paid;
            msg = '${withJosa(c.name, '을', '를')} 뽑고 파종비 ${_comma(paid)}P를 돌려받았어요';
          }
        }
        tx.set(plotRef, _emptyPlot());
        tx.update(_user, upd);
        return msg;
      });

  static String _comma(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// 수확해서 창고에 넣고, 수확량(kg)을 돌려준다. 영양제로 늘어난 수확량이 반영된다.
  Future<double> harvest(int idx, CropSpec c, {DateTime? now}) => _tx<double>((tx) async {
        final t = now ?? DateTime.now();
        final pm = (await tx.get(_col('plots').doc('$idx'))).data() ?? {};
        final u = (await tx.get(_user)).data()!;
        final bonus = (pm['bonus'] as num?)?.toDouble() ?? 0;
        final kg = c.yieldKg * (1 + bonus);
        tx.set(_col('plots').doc('$idx'), _emptyPlot());
        tx.set(_col('inventory').doc(), {'cropCode': c.code, 'quantityKg': kg, 'harvestedAt': FieldValue.serverTimestamp()});
        tx.update(_user, {
          'exp': _int(u['exp']) + harvestExp,
          'stats.harvest': FieldValue.increment(1),
          'stats.harvestKg': FieldValue.increment(kg),
          'stats.crop_${c.code}': FieldValue.increment(1),
          ..._bumps(u, t, ['harvest']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return kg;
      });

  /// 자금 증가 + 입고분 삭제 + 거래 기록을 한 트랜잭션으로 처리
  Future<void> sell(Lot lot, AuctionPrice p, double freshness, int amount, {DateTime? now}) => _tx((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final good = (p.change ?? 0) > 0;
        tx.update(_user, {
          'money': _int(u['money']) + amount,
          'totalProfit': _int(u['totalProfit']) + amount,
          'points': FieldValue.increment(sellPointReward),
          'exp': _int(u['exp']) + sellExp(amount),
          'stats.sell': FieldValue.increment(1),
          if (good) 'stats.goodSell': FieldValue.increment(1),
          ..._bumps(u, t, ['sell']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.delete(_col('inventory').doc(lot.id));
        tx.set(_col('trades').doc(), {
          'cropCode': lot.cropCode, 'quantityKg': lot.kg, 'unitPrice': p.pricePerKg, 'freshness': freshness,
          'amount': amount, 'priceAsOf': Timestamp.fromDate(p.asOf), 'createdAt': FieldValue.serverTimestamp(),
        });
      });

  // ───────────────────────── 아이템 ─────────────────────────

  /// 일반 상점 구매 (씨앗·물통·영양제·성장촉진제)
  Future<void> buyItem(String key, int price, {int qty = 1, DateTime? now}) => _tx((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final total = price * qty;
        final money = _int(u['money']);
        if (money < total) throw StateError('오늘 상품을 다 썼습니다!');
        final have = _int(_asMap(u['items'])?[key]);
        tx.update(_user, {
          'money': money - total,
          'items.$key': have + qty,
          'exp': _int(u['exp']) + 3 * expBoost,
          'stats.shop': FieldValue.increment(1),
          ..._bumps(u, t, ['shop']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  /// 창고의 아이템(물통·영양제·성장촉진제·씨앗)을 [qty]개 판다. 1개 값은 상점 가격의 절반. 받은 돈을 돌려준다.
  Future<int> sellItem(String key, int qty) => _tx<int>((tx) async {
        final unit = itemSellPrice(key);
        if (unit <= 0) throw StateError('팔 수 없는 아이템이에요');
        if (qty <= 0) throw StateError('팔 개수를 골라 주세요');
        final u = (await tx.get(_user)).data()!;
        final have = _int(_asMap(u['items'])?[key]);
        if (have < qty) throw StateError('아이템이 모자라요');
        final amount = unit * qty;
        tx.update(_user, {
          'money': _int(u['money']) + amount,
          'items.$key': have - qty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return amount;
      });

  /// 창고의 아이템 여러 가지를 한 번에 판다 (씨앗 전체 선택 판매). [qtys]는 아이템 키 → 팔 개수. 받은 돈을 돌려준다.
  Future<int> sellItems(Map<String, int> qtys) => _tx<int>((tx) async {
        final u = (await tx.get(_user)).data()!;
        final items = _asMap(u['items']);
        final upd = <String, dynamic>{};
        var amount = 0;
        for (final e in qtys.entries) {
          final unit = itemSellPrice(e.key);
          if (unit <= 0 || e.value <= 0) continue;
          final have = _int(items?[e.key]);
          if (have < e.value) throw StateError('아이템이 모자라요');
          upd['items.${e.key}'] = have - e.value;
          amount += unit * e.value;
        }
        if (upd.isEmpty) throw StateError('팔 씨앗을 골라 주세요');
        tx.update(_user, {
          ...upd,
          'money': _int(u['money']) + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return amount;
      });

  /// 밭에 아이템을 쓴다. 성장 시간이 줄면 새 수확 시각을 돌려주고, 아니면 null.
  Future<DateTime?> useItem(int idx, String key, {DateTime? now}) => _tx<DateTime?>((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final pref = _col('plots').doc('$idx');
        final pm = (await tx.get(pref)).data() ?? {};
        if (pm['cropCode'] == null) throw StateError('작물이 심어진 밭에만 쓸 수 있어요');
        final have = _int(_asMap(u['items'])?[key]);
        // 물주기·영양제·성장촉진제는 무제한 (개수를 쓰지 않는다)
        final ready = (pm['readyAt'] as Timestamp?)?.toDate();
        if (ready == null) throw StateError('밭 정보를 읽지 못했어요');
        final left = ready.difference(t).inMilliseconds;
        final growMs = _int(pm['growMs']) > 0 ? _int(pm['growMs']) : (left > 0 ? left : 1);

        final plotUpd = <String, dynamic>{};
        final userUpd = <String, dynamic>{'items.$key': have, 'updatedAt': FieldValue.serverTimestamp()};
        DateTime? newReady;
        if (key == itemWater || key == itemBooster) {
          if (left <= 0) throw StateError('이미 다 자랐어요. 수확해 주세요');
          final cut = key == itemWater ? waterCut : boosterCut;
          if (key == itemWater) {
            final watered = _int(pm['watered']);
            plotUpd['watered'] = watered + 1;
            userUpd['stats.water'] = FieldValue.increment(1);
            userUpd['exp'] = _int(u['exp']) + 2 * expBoost;
            userUpd.addAll(_bumps(u, t, ['water']));
          } else {
            plotUpd['boosted'] = true; // 횟수 제한 없음 (여러 번 써도 된다)
            userUpd['stats.booster'] = FieldValue.increment(1);
          }
          var r = ready.subtract(Duration(milliseconds: (growMs * cut).round()));
          if (r.isBefore(t)) r = t;
          newReady = r;
          plotUpd['readyAt'] = Timestamp.fromDate(r);
        } else if (key == itemFertilizer) {
          final bonus = (pm['bonus'] as num?)?.toDouble() ?? 0;
          plotUpd['bonus'] = bonus + fertilizerBonus;
          userUpd['stats.fertilizer'] = FieldValue.increment(1);
        } else {
          throw StateError('여기서는 쓸 수 없는 아이템이에요');
        }
        tx.update(pref, plotUpd);
        tx.update(_user, userUpd);
        return newReady;
      });

  // ───────────────────────── 시설 확장 ─────────────────────────

  Future<void> expandPlots(int currentCount) => _tx((tx) async {
        final cost = plotExpandCost(currentCount);
        if (cost == null) throw StateError('더 이상 밭을 넓힐 수 없어요');
        final u = (await tx.get(_user)).data()!;
        final money = _int(u['money']);
        if (money < cost) throw StateError('포인트가 부족합니다');
        tx.update(_user, {'money': money - cost, 'updatedAt': FieldValue.serverTimestamp()});
        for (var i = currentCount; i < currentCount + plotExpandStep && i < maxPlots; i++) {
          tx.set(_col('plots').doc('$i'), _emptyPlot());
        }
      });

  Future<void> expandWarehouse() => _tx((tx) async {
        final u = (await tx.get(_user)).data()!;
        final lv = _int(u['warehouseLevel']);
        if (lv >= maxWarehouseLevel) throw StateError('창고를 더 이상 넓힐 수 없어요');
        final cost = warehouseCost(lv);
        final money = _int(u['money']);
        if (money < cost) throw StateError('포인트가 부족합니다');
        tx.update(_user, {'money': money - cost, 'warehouseLevel': lv + 1, 'updatedAt': FieldValue.serverTimestamp()});
      });

  /// 하우스를 한 채 더 짓는다 (최대 [maxGreenhouses]채, 한 채 값은 늘 같다).
  /// 지금 자라고 있는 작물도 바로 빨라진다: 남은 성장 시간이 새 하우스 배율만큼 줄어든다.
  /// 시간이 바뀐 밭의 (칸 번호, 작물, 새 수확 시각)을 돌려준다 (알림을 다시 예약하는 데 쓴다).
  Future<List<(int, CropSpec, DateTime)>> buyGreenhouse({DateTime? now}) => _tx<List<(int, CropSpec, DateTime)>>((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final owned = UserData(u).greenhouses;
        if (owned >= maxGreenhouses) throw StateError('하우스는 최대 $maxGreenhouses채까지 지을 수 있어요');
        final cost = greenhouseCostFor(owned);
        final money = _int(u['money']);
        if (money < cost) throw StateError('포인트가 부족합니다');
        // 트랜잭션은 읽기를 모두 끝낸 뒤에 쓴다
        final plotSnaps = [for (var i = 0; i < maxPlots; i++) await tx.get(_col('plots').doc('$i'))];
        tx.update(_user, {'money': money - cost, 'greenhouse': true, 'greenhouses': owned + 1, 'updatedAt': FieldValue.serverTimestamp()});
        final ratio = greenhouseFactor(owned + 1) / greenhouseFactor(owned);
        final changed = <(int, CropSpec, DateTime)>[];
        for (final s in plotSnaps) {
          if (!s.exists) continue;
          final m = s.data()!;
          final code = m['cropCode'];
          final idx = int.tryParse(s.id);
          final ready = (m['readyAt'] as Timestamp?)?.toDate();
          if (code is! String || idx == null || ready == null || !ready.isAfter(t)) continue;
          CropSpec c;
          try {
            c = cropOf(code);
          } catch (_) {
            continue;
          }
          final remaining = ready.difference(t).inMilliseconds;
          final newRemain = (remaining * ratio).round();
          if (newRemain >= remaining) continue;
          final r = t.add(Duration(milliseconds: newRemain));
          final upd = <String, dynamic>{'readyAt': Timestamp.fromDate(r)};
          final growMs = _int(m['growMs']);
          if (growMs > 0) {
            final g = growMs - (remaining - newRemain);
            upd['growMs'] = g < newRemain ? newRemain : g; // 지나간 시간은 그대로, 남은 시간만 줄어든다
          }
          tx.update(s.reference, upd);
          changed.add((idx, c, r));
        }
        return changed;
      });

  /// 씨앗 꾸러미: 기본 여섯 작물의 씨앗을 1개씩 한 번에 받는다.
  Future<void> buySeedPack(int price) => _tx((tx) async {
        final t = DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final money = _int(u['money']);
        if (money < price) throw StateError('오늘 상품을 다 썼습니다!');
        final items = _asMap(u['items']) ?? {};
        final upd = <String, dynamic>{
          'money': money - price,
          'exp': _int(u['exp']) + 3 * expBoost,
          'stats.shop': FieldValue.increment(1),
          ..._bumps(u, t, ['shop']),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        for (final c in seedPackCrops) {
          upd['items.${seedKey(c.code)}'] = _int(items[seedKey(c.code)]) + 1;
        }
        tx.update(_user, upd);
      });

  // ───────────────────────── 포인트 ─────────────────────────

  /// 포인트 상점 구매. 희귀 씨앗은 [cropCode]로 받을 씨앗 종류를 정한다.
  Future<void> buyPointItem(String key, {String? cropCode}) => _tx((tx) async {
        PointItem? item;
        for (final p in pointItems) {
          if (p.key == key) item = p;
        }
        if (item == null) throw StateError('알 수 없는 상품이에요');
        final u = (await tx.get(_user)).data()!;
        final pts = _int(u['points']);
        if (pts < item.cost) throw StateError('캐시가 부족합니다');
        final upd = <String, dynamic>{'points': pts - item.cost, 'updatedAt': FieldValue.serverTimestamp()};
        final items = _asMap(u['items']) ?? {};
        switch (key) {
          case pointRareSeed:
            final k = seedKey(cropCode ?? crops.first.code);
            upd['items.$k'] = _int(items[k]) + 3;
            break;
          case pointDecor:
            final d = _int(u['decor']);
            if (d >= maxDecor) throw StateError('농장 장식은 최대 $maxDecor개까지예요');
            upd['decor'] = d + 1;
            break;
          case pointVault:
            final b = _int(u['warehouseBonusKg']);
            if (b >= maxVaultBonusKg) throw StateError('특별 보관함은 최대 ${maxVaultBonusKg ~/ vaultStepKg}번까지 살 수 있어요');
            upd['warehouseBonusKg'] = b + vaultStepKg;
            break;
          case pointLucky:
            upd['items.$itemFertilizer'] = _int(items[itemFertilizer]) + 3;
            break;
          case pointWaterPack:
            upd['items.$itemWater'] = _int(items[itemWater]) + 10;
            break;
          case pointBoosterPack:
            upd['items.$itemBooster'] = _int(items[itemBooster]) + 2;
            break;
          case pointSeedBox:
            for (final c in seedPackCrops) {
              upd['items.${seedKey(c.code)}'] = _int(items[seedKey(c.code)]) + 1;
            }
            break;
          case pointCoinBag:
            upd['money'] = _int(u['money']) + coinBagMoney;
            break;
          case pointFarmBook:
            upd['exp'] = _int(u['exp']) + farmBookExp;
            break;
        }
        tx.update(_user, upd);
      });

  /// 레벨이 [from]에서 [to]로 올랐을 때 보상(포인트·희귀 씨앗)을 한 번만 준다.
  /// 레벨이 올라간 만큼(from → to) 보상을 준다. 올라가지 않았으면 null. (`levelRewarded`는 기록용으로만 적는다)
  Future<LevelUpReward?> claimLevelUpReward(int from, int to) => _tx<LevelUpReward?>((tx) async {
        final u = (await tx.get(_user)).data()!;
        // 레벨이 오를 때마다 항상 보상(포인트·씨앗)을 준다. 예전에 받은 레벨이어도 다시 오르면 받는다 (레벨 규칙이 바뀌어 내려갔다 오른 경우 포함).
        final done = from;
        if (to <= done) return null;
        final code = levelUpSeedCrop(to);
        final k = seedKey(code);
        final items = _asMap(u['items']) ?? {};
        final (pts, seeds) = levelUpTotals(done, to); // 레벨이 높을수록 보상이 커진다
        tx.update(_user, {
          'points': _int(u['points']) + pts,
          'items.$k': _int(items[k]) + seeds,
          'levelRewarded': to,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return LevelUpReward(points: pts, seedCode: code, seedCount: seeds);
      });

  Future<void> claimMission(MissionDef def, {DateTime? now}) => _tx((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final field = def.weekly ? 'weekly' : 'daily';
        final tag = def.weekly ? weekTag(t) : dayTag(t);
        final cur = _asMap(u[field]);
        if (periodCount(cur, tag, def.key) < def.target) throw StateError('아직 완료하지 못한 미션이에요');
        if (periodClaimed(cur, tag).contains(def.id)) throw StateError('이미 받은 보상이에요');
        tx.update(_user, {
          field: markClaimed(cur, tag, def.id),
          'points': FieldValue.increment(def.points),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> claimAchievement(AchievementDef def, int plots) => _tx((tx) async {
        final u = (await tx.get(_user)).data()!;
        final claimed = (u['achClaimed'] is List) ? (u['achClaimed'] as List).map((e) => '$e').toList() : <String>[];
        if (claimed.contains(def.id)) throw StateError('이미 받은 보상이에요');
        if (achievementProgress(def, u, plots) < def.target) throw StateError('아직 달성하지 못했어요');
        tx.update(_user, {
          'achClaimed': FieldValue.arrayUnion([def.id]),
          'points': FieldValue.increment(def.points),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  // ───────────────────────── 마을 공동기금 ─────────────────────────

  /// 마을 기금에 기부한다. 기부할 때마다 바로 포인트 보상을 주고, 받은 포인트를 돌려준다.
  Future<int> donateToFund(int amount) => _tx<int>((tx) async {
        if (amount <= 0) throw StateError('기부할 금액을 입력해 주세요');
        final u = (await tx.get(_user)).data()!;
        final f = (await tx.get(_fund)).data();
        final money = _int(u['money']);
        if (money < amount) throw StateError('포인트가 부족합니다');
        final total = _int(f?['total']);
        final goal = _int(f?['goal']) > 0 ? _int(f?['goal']) : fundDefaultGoal;
        final reward = donateRewardPoints(amount);
        tx.update(_user, {
          'money': money - amount,
          'fundGiven': FieldValue.increment(amount),
          'stats.donate': FieldValue.increment(amount),
          'exp': _int(u['exp']) + donateExp(amount),
          'points': FieldValue.increment(reward),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_fund, {'total': total + amount, 'goal': goal, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return reward;
      });

  Future<void> claimFundMilestone(FundMilestone m) => _tx((tx) async {
        final u = (await tx.get(_user)).data()!;
        final f = FundData.fromMap((await tx.get(_fund)).data());
        final claimed = (u['fundClaimed'] is List) ? (u['fundClaimed'] as List).map((e) => '$e').toList() : <String>[];
        if (claimed.contains('${m.percent}')) throw StateError('이미 받은 보상이에요');
        if (_int(u['fundGiven']) <= 0) throw StateError('기금에 기부한 농부만 받을 수 있어요');
        if (f.ratio * 100 + 1e-9 < m.percent) throw StateError('아직 ${m.percent}%에 도달하지 못했어요');
        tx.update(_user, {
          'fundClaimed': FieldValue.arrayUnion(['${m.percent}']),
          'points': FieldValue.increment(m.points),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  // ───────────────────────── 작물 매칭·고객센터 ─────────────────────────

  /// 게임 결과를 정산한다. 하루 [gameDailyRewardLimit]번까지만 보상이 있고, 보상을 받았으면 true.
  Future<bool> gameReward(int score, {DateTime? now}) => _tx<bool>((tx) async {
        final t = now ?? DateTime.now();
        final u = (await tx.get(_user)).data()!;
        final played = periodCount(_asMap(u['daily']), dayTag(t), 'game');
        final rewarded = played < gameDailyRewardLimit;
        final money = rewarded ? gameRewardMoney(score) : 0;
        final pts = rewarded ? gameRewardPoints(score) : 0;
        tx.update(_user, {
          'money': _int(u['money']) + money,
          'points': FieldValue.increment(pts),
          'exp': _int(u['exp']) + 10 * expBoost,
          'stats.game': FieldValue.increment(1),
          ..._bumps(u, t, ['game']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return rewarded;
      });
}
