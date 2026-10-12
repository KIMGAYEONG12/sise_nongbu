// 시세 농부 서버 작업: 공공데이터 "전국 공영도매시장 실시간 경매정보" API를 불러
// Firestore 문서 market/prices 에 품목별 kg당 시세를 저장한다.
// GitHub Actions(.github/workflows/prices.yml)가 정해진 시간마다 실행한다.
//
// 필요한 환경변수 (GitHub 저장소 → Settings → Secrets and variables → Actions)
//   AUCTION_API_KEY          : 공공데이터포털 인증키
//   FIREBASE_SERVICE_ACCOUNT : Firebase 서비스 계정 키 JSON 전체
//
// 저장 형태 (market/prices)
//   updatedAt : 서버 저장 시각
//   CABBAGE   : { price, prev, asOf: '2026-10-07', prevDate, volumeKg }   ← 시세판에 쓰는 값
//   days      : { '2026-10-07': { done: true, CABBAGE: { p, v }, ... }, ... }  ← 최근 30일 (품목 상세 7·14·30일 그래프용)

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const RAW_KEY = (process.env.AUCTION_API_KEY || '').trim();
const SA = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!RAW_KEY || !SA) {
  console.error('AUCTION_API_KEY 또는 FIREBASE_SERVICE_ACCOUNT 시크릿이 없어요. GitHub 저장소 설정에서 등록해 주세요.');
  process.exit(1);
}
// 공공데이터포털 "Encoding" 키(%가 들어 있음)를 넣어도 두 번 인코딩되지 않게
const SERVICE_KEY = RAW_KEY.includes('%') ? decodeURIComponent(RAW_KEY) : RAW_KEY;

initializeApp({ credential: cert(JSON.parse(SA)) });
const db = getFirestore();

const BASE = 'https://apis.data.go.kr/B552845/katRealTime2/trades2';
const MARKET = '110001'; // 서울가락 (앱 lib/services/auction_api_service.dart 와 같은 값)
const CROPS = {
  CABBAGE: ['10', '01'], // 엽경채류 > 배추
  RADISH: ['11', '01'], // 근채류 > 무
  ONION: ['12', '01'], // 조미채소류 > 양파
  APPLE: ['06', '01'], // 과실류 > 사과
  TOMATO: ['08', '03'], // 과일과채류 > 토마토
  POTATO: ['05', '01'], // 서류 > 감자
  CORN: ['04', '01'], // 잡곡류 > 옥수수
  SWEETPOTATO: ['05', '02'], // 서류 > 고구마
  STRAWBERRY: ['08', '04'], // 과일과채류 > 딸기
  PUMPKIN: ['09', '02'], // 과채류 > 호박
  FIG: ['06', '27'], // 과실류 > 무화과
  CARROT: ['11', '03'], // 근채류 > 당근
  CUCUMBER: ['09', '01'], // 과채류 > 오이
  EGGPLANT: ['09', '03'], // 과채류 > 가지
  GRAPE: ['06', '03'], // 과실류 > 포도
  PEAR: ['06', '02'], // 과실류 > 배
  WATERMELON: ['08', '01'], // 과일과채류 > 수박
  MANDARIN: ['06', '14'], // 과실류 > 감귤
  PAPRIKA: ['13', '26'], // 양채류 > 파프리카
  GARLIC: ['12', '09'], // 조미채소류 > 마늘
  BROCCOLI: ['13', '06'], // 양채류 > 브로콜리
};
const KEEP_DAYS = 30; // 저장해 두는 날짜 수 (품목 상세의 30일 그래프까지)
const RECENT_DAYS = 2; // 오늘·어제는 거래가 계속 들어올 수 있어 매번 다시 받는다 (그 전 날짜는 한 번 받으면 재사용)
const PAGE = 1000;

/** 한국 날짜 'YYYY-MM-DD' (back일 전) */
const kstYmd = (back) => new Date(Date.now() + 9 * 3600e3 - back * 86400e3).toISOString().slice(0, 10);

/** 단위명 → kg 배수. 무게 단위가 아니면 null */
function kgFactor(unit) {
  const u = String(unit ?? '').trim().toLowerCase();
  if (!u || u === 'kg' || u === '키로' || u === '킬로그램') return 1;
  if (u === 'g' || u === '그램') return 0.001;
  if (u === 't' || u === 'ton' || u === '톤') return 1000;
  return null;
}

// 공공데이터 API는 초당 요청 수가 제한되어 있다(429). 요청 사이에 간격을 둔다.
let lastCall = 0;
async function paced() {
  const wait = 300 - (Date.now() - lastCall);
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastCall = Date.now();
}

async function getJson(url) {
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      await paced();
      const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
      const text = await res.text();
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 150)}`);
      if (text.trimStart().startsWith('<')) throw new Error(`XML 오류 응답: ${text.slice(0, 150)}`);
      const j = JSON.parse(text);
      const h = j?.response?.header;
      if (h && String(h.resultCode) !== '0' && String(h.resultCode) !== '00') throw new Error(`API ${h.resultCode}: ${h.resultMsg}`);
      return j;
    } catch (e) {
      lastErr = e;
      await new Promise((r) => setTimeout(r, 1500 * attempt));
    }
  }
  throw lastErr;
}

/** 하루치 품목 거래 건 전부 (1,000건씩 여러 쪽) */
async function fetchItems(code, day) {
  const [l, m] = CROPS[code];
  const all = [];
  for (let page = 1; page <= 5; page++) {
    const qs = new URLSearchParams({
      serviceKey: SERVICE_KEY,
      returnType: 'json',
      pageNo: String(page),
      numOfRows: String(PAGE),
      'cond[trd_clcln_ymd::EQ]': day,
      'cond[whsl_mrkt_cd::EQ]': MARKET,
      'cond[gds_lclsf_cd::EQ]': l,
      'cond[gds_mclsf_cd::EQ]': m,
      selectable: 'scsbd_prc,qty,unit_qty,unit_nm,trd_se',
    });
    const j = await getJson(`${BASE}?${qs}`);
    const body = j?.response?.body ?? {};
    let it = body?.items?.item ?? [];
    if (!Array.isArray(it)) it = [it];
    all.push(...it);
    const total = Number(body.totalCount) || 0;
    if (it.length < PAGE || (total > 0 && all.length >= total)) break;
  }
  return all;
}

/** 거래 건 → { p: kg당 가중평균가, v: 거래량(kg) }. 경매 건 우선, 없으면 정가·수의 건까지. */
function summarize(items) {
  const calc = (onlyAuction) => {
    let vol = 0, sum = 0;
    for (const i of items) {
      if (onlyAuction && i.trd_se != null && String(i.trd_se).trim() !== '경매') continue;
      const f = kgFactor(i.unit_nm);
      const price = Number(i.scsbd_prc), unitKg = Number(i.unit_qty) * (f ?? 0), qty = Number(i.qty);
      if (!f || !(price > 0) || !(unitKg > 0) || !(qty > 0)) continue;
      const kg = qty * unitKg;
      vol += kg;
      sum += (price / unitKg) * kg;
    }
    return vol > 0 ? { p: Math.round((sum / vol) * 100) / 100, v: Math.round(vol) } : null;
  };
  return calc(true) ?? calc(false);
}

const ref = db.doc('market/prices');
const snap = await ref.get();
const oldDays = (snap.exists && snap.data().days) || {};

const days = {};
let calls = 0, failures = 0;
for (let back = 0; back < KEEP_DAYS; back++) {
  const day = kstYmd(back);
  const prev = oldDays[day];
  // 지난 날짜는 바뀌지 않으므로 한 번 받은 값을 그대로 쓴다. 다만 나중에 새로 추가된 작물은 그 날짜 기록이 없으니 그것만 다시 받는다.
  // (이미 받아 봤는데 거래가 없던 작물은 none 에 적어 두어서 매번 다시 받지 않는다)
  const known = (c) => prev && (prev[c] || (prev.none || []).includes(c));
  const missing = Object.keys(CROPS).filter((c) => !known(c));
  if (back >= RECENT_DAYS && prev && prev.done && missing.length === 0) {
    days[day] = prev;
    continue;
  }
  const entry = { done: true, none: [] };
  for (const code of Object.keys(CROPS)) {
    if (back >= RECENT_DAYS && prev && prev.done && known(code)) {
      if (prev[code]) entry[code] = prev[code];
      else entry.none.push(code);
      continue;
    }
    try {
      calls++;
      const s = summarize(await fetchItems(code, day));
      if (s) entry[code] = s;
      else entry.none.push(code);
    } catch (e) {
      failures++;
      entry.done = false; // 다음 실행 때 다시 받는다
      if (prev && prev[code]) entry[code] = prev[code];
      console.error(`[${day} ${code}] ${e.message}`);
    }
  }
  days[day] = entry;
}

const out = { updatedAt: FieldValue.serverTimestamp(), market: MARKET, days };
const newestFirst = Object.keys(days).sort().reverse();
for (const code of Object.keys(CROPS)) {
  const dates = newestFirst.filter((d) => days[d][code] && days[d][code].p != null);
  if (dates.length === 0) continue;
  const asOf = dates[0], prevDate = dates[1] ?? null;
  out[code] = {
    price: days[asOf][code].p,
    prev: prevDate ? days[prevDate][code].p : null,
    asOf,
    prevDate,
    volumeKg: days[asOf][code].v,
  };
}

if (Object.keys(CROPS).every((c) => !out[c])) {
  console.error(`시세를 하나도 받지 못해 저장하지 않았어요 (요청 ${calls}건, 실패 ${failures}건)`);
  process.exit(1);
}
await ref.set(out);
console.log(`저장 완료 (요청 ${calls}건, 실패 ${failures}건)`);
for (const code of Object.keys(CROPS)) {
  if (out[code]) console.log(`  ${code}: ${Math.round(out[code].price)}원/kg (${out[code].asOf}), 전일 ${out[code].prev == null ? '-' : Math.round(out[code].prev)}`);
}
