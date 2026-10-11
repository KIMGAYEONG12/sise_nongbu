import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/game_rules.dart';

const auctionApiKey = String.fromEnvironment('AUCTION_API_KEY');

abstract class AuctionSource {
  Future<List<AuctionRow>> rows(String cropCode, DateTime date);
}

/// 공공데이터포털 "한국농수산식품유통공사_전국 공영도매시장 실시간 경매정보" API (trades2).
///
/// 요청 예)
///   https://apis.data.go.kr/B552845/katRealTime2/trades2
///     ?serviceKey=인증키&returnType=json&pageNo=1&numOfRows=1000
///     &cond[trd_clcln_ymd::EQ]=2026-10-06      ← 거래정산일자(필수, YYYY-MM-DD)
///     &cond[whsl_mrkt_cd::EQ]=110001           ← 도매시장 (110001 = 서울가락)
///     &cond[gds_lclsf_cd::EQ]=10&cond[gds_mclsf_cd::EQ]=01   ← 품목 대·중분류 (배추)
///
/// 응답 한 건(item)의 주요 필드 (값은 모두 문자열, 예: "10000.000")
///   scsbd_prc : 단량당 낙찰가(원)  ← 한 포장(unit_qty × unit_nm)의 가격
///   unit_qty  : 단위물량 (예: 10)
///   unit_nm   : 단위명 (예: kg)
///   qty       : 수량 (포장 개수)
///   trd_se    : 매매방법 (경매 / 정가수의 …)
/// kg당 가격 = scsbd_prc ÷ (unit_qty kg),  거래량(kg) = qty × unit_qty kg
class AuctionApiService implements AuctionSource {
  AuctionApiService(this.client);
  final http.Client client;

  static const baseUrl = 'https://apis.data.go.kr/B552845/katRealTime2/trades2';

  // 요청 변수
  static const dateParam = 'cond[trd_clcln_ymd::EQ]'; // 거래정산일자 (필수)
  static const marketParam = 'cond[whsl_mrkt_cd::EQ]'; // 도매시장코드
  static const itemLargeParam = 'cond[gds_lclsf_cd::EQ]'; // 상품 대분류코드
  static const itemParam = 'cond[gds_mclsf_cd::EQ]'; // 상품 중분류코드

  /// 기준 도매시장: 서울가락 (전국 최대 거래량)
  static const marketCode = '110001';

  // 응답 필드
  static const priceKey = 'scsbd_prc', unitKgKey = 'unit_qty', volumeKey = 'qty';
  static const unitNameKey = 'unit_nm', saleTypeKey = 'trd_se';

  /// 응답에서 필요한 컬럼만 받아 트래픽을 줄인다.
  static const selectable = 'scsbd_prc,qty,unit_qty,unit_nm,trd_se';

  /// 한 번에 최대 1,000건까지 내려준다. 사과·토마토처럼 하루 1,000건이 넘는 품목은 여러 쪽을 받는다.
  static const pageSize = 1000;
  static const maxPages = 5;

  /// 게임 작물 코드 → (상품 대분류코드, 상품 중분류코드). 2026-10-06 서울가락 실제 응답으로 확인한 값.
  static const itemCodes = <String, (String, String)>{
    'CABBAGE': ('10', '01'), // 엽경채류 > 배추
    'RADISH': ('11', '01'), // 근채류 > 무
    'ONION': ('12', '01'), // 조미채소류 > 양파
    'APPLE': ('06', '01'), // 과실류 > 사과
    'TOMATO': ('08', '03'), // 과일과채류 > 토마토
    'POTATO': ('05', '01'), // 서류 > 감자
    'CORN': ('04', '01'), // 잡곡류 > 옥수수
    'SWEETPOTATO': ('05', '02'), // 서류 > 고구마
    'STRAWBERRY': ('08', '04'), // 과일과채류 > 딸기
    'PUMPKIN': ('09', '02'), // 과채류 > 호박
    'FIG': ('06', '27'), // 과실류 > 무화과
    'CARROT': ('11', '03'), // 근채류 > 당근
    'CUCUMBER': ('09', '01'), // 과채류 > 오이
    'EGGPLANT': ('09', '03'), // 과채류 > 가지
    'GRAPE': ('06', '03'), // 과실류 > 포도
    'PEAR': ('06', '02'), // 과실류 > 배
    'WATERMELON': ('08', '01'), // 과일과채류 > 수박
    'MANDARIN': ('06', '14'), // 과실류 > 감귤
    'PAPRIKA': ('13', '26'), // 양채류 > 파프리카
    'GARLIC': ('12', '09'), // 조미채소류 > 마늘
    'BROCCOLI': ('13', '06'), // 양채류 > 브로콜리
  };

  /// 공공데이터포털의 "Encoding" 키(%가 들어 있음)를 넣어도 두 번 인코딩되지 않게 풀어서 쓴다.
  static String get _key {
    final k = auctionApiKey.trim();
    if (!k.contains('%')) return k;
    try {
      return Uri.decodeComponent(k);
    } catch (_) {
      return k;
    }
  }

  static String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<AuctionRow>> rows(String cropCode, DateTime date) async {
    final code = itemCodes[cropCode];
    if (code == null) return [];
    final base = Uri.parse(baseUrl);
    final raw = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final uri = base.replace(queryParameters: {
        'serviceKey': _key,
        'returnType': 'json',
        'pageNo': '$page',
        'numOfRows': '$pageSize',
        dateParam: ymd(date),
        marketParam: marketCode,
        itemLargeParam: code.$1,
        itemParam: code.$2,
        'selectable': selectable,
      });
      final res = await client.get(uri).timeout(const Duration(seconds: 15));
      final body = utf8.decode(res.bodyBytes);
      if (res.statusCode != 200) throw Exception('시세 API 오류 ${res.statusCode}: ${_errorText(body)}');
      final decoded = _decode(body);
      raw.addAll(decoded.items);
      final total = decoded.totalCount ?? 0;
      if (decoded.items.length < pageSize || (total > 0 && raw.length >= total)) break;
    }
    return _toRows(raw);
  }

  /// item이 0건(없음)/1건(객체)/여러 건(배열)인 경우를 모두 처리. 환산 불가 건은 제외.
  static List<AuctionRow> parseRows(String body) => _toRows(_decode(body).items);

  /// JSON 본문 → item 목록과 전체 건수. 인증키 오류처럼 결과 코드가 정상(0)이 아니면 예외.
  static ({List<Map<String, dynamic>> items, int? totalCount}) _decode(String body) {
    final text = body.trimLeft();
    if (text.startsWith('<')) throw Exception('시세 API 오류: ${_errorText(text)}'); // 게이트웨이 오류는 XML로 올 때가 있다
    final json = jsonDecode(text);
    final response = json is Map ? json['response'] : null;
    final header = response is Map ? response['header'] : null;
    if (header is Map) {
      final rc = '${header['resultCode'] ?? '0'}';
      if (rc != '0' && rc != '00') throw Exception('시세 API 오류 $rc: ${header['resultMsg'] ?? ''}');
    }
    final b = response is Map ? response['body'] : null;
    final box = b is Map ? b['items'] : null;
    final items = box is Map ? box['item'] : null; // 0건이면 items가 빈 문자열이거나 item이 빈 배열
    final list = items == null ? const [] : (items is List ? items : [items]);
    final total = b is Map ? int.tryParse('${b['totalCount']}') : null;
    return (items: [for (final it in list) if (it is Map) Map<String, dynamic>.from(it)], totalCount: total);
  }

  /// 단위명 → kg 환산 배수. kg·g·톤이 아니면(개·속·단 등) 무게를 알 수 없어 null.
  static double? kgFactor(Object? unitName) {
    final u = '${unitName ?? ''}'.trim().toLowerCase();
    if (u.isEmpty || u == 'null' || u == 'kg' || u == '키로' || u == '킬로그램') return 1;
    if (u == 'g' || u == '그램') return 0.001;
    if (u == 't' || u == 'ton' || u == '톤') return 1000;
    return null;
  }

  /// 경매 건만 쓰고(시세판 기준과 같게), 그날 경매 건이 하나도 없으면 정가·수의 건까지 쓴다.
  static List<AuctionRow> _toRows(List<Map<String, dynamic>> list) {
    final auction = <AuctionRow>[], others = <AuctionRow>[];
    for (final it in list) {
      final price = double.tryParse('${it[priceKey]}');
      final unit = double.tryParse('${it[unitKgKey]}');
      final vol = double.tryParse('${it[volumeKey]}');
      final factor = kgFactor(it[unitNameKey]);
      if (price == null || unit == null || vol == null || factor == null) continue;
      if (price <= 0 || vol <= 0) continue;
      final unitKg = unit * factor;
      final perKg = toPricePerKg(price, unitKg);
      if (perKg == null) continue;
      final row = AuctionRow(perKg, vol * unitKg);
      final type = it[saleTypeKey];
      (type == null || '$type'.trim() == '경매' ? auction : others).add(row);
    }
    return auction.isNotEmpty ? auction : others;
  }

  static String _errorText(String body) {
    final m = RegExp(r'<(returnAuthMsg|errMsg|resultMsg)>([^<]*)<').firstMatch(body);
    if (m != null) return m.group(2)!.trim();
    return body.length > 120 ? body.substring(0, 120) : body;
  }
}

/// 키가 없거나 API 확정 전 개발용. 날짜별로 변하는 가짜 시세.
class FakeAuctionSource implements AuctionSource {
  static const _base = {'CABBAGE': 1000, 'RADISH': 800, 'ONION': 1200, 'APPLE': 3500, 'TOMATO': 3000, 'POTATO': 2000};
  @override
  Future<List<AuctionRow>> rows(String cropCode, DateTime date) async {
    final day = date.difference(DateTime(2026)).inDays;
    final wave = 1 + 0.4 * sin(day * 1.3 + cropCode.hashCode % 7);
    return [AuctionRow((_base[cropCode] ?? 1000) * wave, 500)];
  }
}
