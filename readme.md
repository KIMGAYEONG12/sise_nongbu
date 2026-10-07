# 시세 농부 (SiseNongbu)

실제 전국 공영도매시장의 경매 시세로 움직이는 농장 시뮬레이션 게임 Flutter 모바일 앱. 작물을 심고 수확해 창고에 쌓아 두었다가, 실시간 도매 시세를 보고 가장 좋은 때에 출하해 수익을 낸다.

| 항목       | 내용                                              |
| ---------- | ------------------------------------------------- |
| 프로젝트명 | Open API 활용 미니 프로젝트 (시세 농부)           |
| 형태       | 개인 프로젝트                                     |
| 개발 기간  | **2026-10-01(목) ~ 2026-10-22(목)**, 3주          |
| 배포 대상  | Android (Firebase App Distribution)               |
| 핵심 API   | 전국 공영도매시장 실시간 경매정보 (활용신청 완료) |

---

## 1. 기획

### 1-1. 배경과 목표

Open API, 클라우드 DB, 푸시 알림처럼 실제 앱 서비스에 쓰이는 기능을 직접 붙여서, 화면 구현을 넘어 **개발 → 테스트 → 빌드 → 배포**까지 한 번에 경험하는 것이 목표다.

농산물 도매 시세는 매일 달라지는 실제 데이터다. 이 데이터를 화면에 보여주는 데서 끝내지 않고 **게임 규칙의 핵심(출하 대금 계산)** 에 넣으면, API가 장식이 아니라 앱이 돌아가는 이유가 된다. 파종 → 성장 → 수확 → 보관 → 출하로 이어지는 상태 흐름이 뚜렷해서 CRUD, 상태 관리, MVVM, Open API가 모두 의미 있게 들어간다.

또 구글 플레이 스토어에서 이런 컨셉(실제 도매 시세 기반 농장 게임)의 앱은 드문 편이라는 점이 차별점이다. (발표 전에 스토어를 직접 검색해 확인하고 발표 자료에 반영한다.)

### 1-2. 주제

**실시간 도매 경매 시세 기반 농장 시뮬레이션 게임**

가상 자금으로 작물을 키워 수확하고, 실제 경매 시세로 출하 대금을 정산받는다. 같은 작물이라도 언제 파느냐에 따라 수익이 달라진다.

### 1-3. 핵심 게임 루프와 사용자 시나리오

```
시세 확인 → 파종 → 성장 대기 → 수확 알림 → 창고 입고 → 출하 타이밍 선택 → 정산 → 다음 파종
```

1. 시세판에서 품목별 오늘 시세(kg당 가격)와 전일 대비 등락을 확인한다.
2. 농장의 빈 밭에 작물을 고르고 파종한다. 파종비가 자금에서 빠진다.
3. 성장 시간이 지나면 수확 알림이 오고, 수확하면 창고에 입고된다.
4. 창고에서 현재 시세를 보고 지금 출하할지, 더 보관할지 정한다. 보관하면 신선도가 떨어진다.
5. 출하하면 그 시점의 시세로 정산되어 자금이 늘고, 거래 기록이 남는다.
6. 거래 기록 화면에서 누적 수익과 품목별 손익을 확인한다.

### 1-4. 게임 규칙 (초안)

숫자는 시세 데이터를 실제로 본 뒤 플레이하면서 조정한다. 규칙 계산은 화면과 분리된 순수 Dart 함수(`game_rules.dart`)로 만들어 단위 테스트한다.

| 항목      | 규칙                                                                                                  |
| --------- | ----------------------------------------------------------------------------------------------------- |
| 시작 자금 | 100,000원 (가상 화폐, 실제 금전과 무관)                                                               |
| 밭        | 6칸                                                                                                   |
| 파종비    | 품목별 고정값. 평균 시세 대비 수확 대금의 약 60% 수준으로 시작                                        |
| 수확량    | 품목별 고정값 (kg)                                                                                    |
| 성장 시간 | 품목별 고정값 (실시간 기준 수 시간). **데모 모드**에서는 배속을 올려 발표 때 바로 수확할 수 있게 한다 |
| 보관      | 창고에 입고된 날부터 신선도가 하루 5%씩 감소, 하한 70%                                                |
| 출하 대금 | 수확량 × 출하 시점 kg당 시세 × 신선도 계수                                                            |
| 시세 기준 | 대표 도매시장 1곳을 기준으로 시작 (코드는 표준코드 API로 확인)                                        |
| 시세 계산 | 경매 건의 단위·포장을 kg당 가격으로 환산한 뒤 거래량 가중평균                                         |
| 시세 없음 | 마지막으로 조회에 성공한 시세를 쓰고, 화면에 "○월 ○일 ○시 기준"을 표시. 정산에도 기준 시각을 기록     |
| 품목      | 5~6개 (후보: 배추, 무, 양파, 사과, 토마토, 감자). 실제 API에 거래 데이터가 있는 품목만 확정           |

앱 정보 화면과 시세판에 "가상 게임이며 실제 투자·거래 조언이 아니다"라는 문구를 표시한다.

### 1-5. 범위

| 구분 | 내용                                                                                                                                                                                 |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 필수 | 시세판(API 연동), 농장(파종·성장·수확), 창고·출하·정산, 거래 기록, Firestore 저장(익명 인증), 수확 로컬 예약 알림, FCM 수신 시연, 단위·위젯 테스트, APK 빌드와 App Distribution 배포 |
| 권장 | 통합 테스트 1개 (파종 → 수확 → 출하 → 자금 반영)                                                                                                                                     |
| 선택 | 시세 추이 미니 차트, 목표 가격 도달 알림, 랜덤 이벤트(가뭄·풍작) (필수를 모두 마친 뒤)                                                                                               |
| 제외 | Google Play 출시와 비공개 테스트, 서버 예약 푸시·서버 시세 수집, 회원가입·로그인(익명 인증 사용), 랭킹·멀티플레이, 결제·광고, iOS                                                    |

Android(에뮬레이터·실기기)만 실행·배포한다.

### 1-6. 과제 요건 대응

| 과제 요건                                  | 대응                                                         |
| ------------------------------------------ | ------------------------------------------------------------ |
| Flutter 크로스플랫폼                       | Flutter/Dart 단일 코드베이스 (실행·배포는 Android만)         |
| Widget 화면 구성, 화면 이동, 사용자 이벤트 | 1-7 (Widget 구성, 하단 탭과 Navigator 이동, 이벤트 처리)     |
| Open API 1개 이상                          | 한국농수산식품유통공사 전국 공영도매시장 실시간 경매정보 API |
| Firebase 연동                              | Cloud Firestore, 익명 인증                                   |
| 푸시 알림 1개 이상                         | FCM 푸시 수신 + 로컬 예약 알림(수확)                         |
| REST API / JSON                            | 경매정보 API 호출과 응답 파싱                                |
| MVVM                                       | View / ViewModel / Repository / Service                      |
| 테스트 및 배포                             | 단위·위젯 테스트, APK 빌드, App Distribution                 |

### 1-7. 화면 구성·이동·이벤트

**화면과 주요 Widget**

| 화면             | 내용                                                       | 주요 Widget                                                                     |
| ---------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 시세판 (탭 1)    | 품목별 kg당 시세, 전일 대비 등락, 기준 시각, 새로고침      | `Scaffold`, `AppBar`, `ListView.builder`, `Card`/`ListTile`, `RefreshIndicator` |
| 농장 (탭 2)      | 밭 6칸 상태(빈 밭/성장 중/수확 가능), 자금 표시, 파종·수확 | `GridView.builder`, `Card`, `LinearProgressIndicator`, `showModalBottomSheet`   |
| 창고 (탭 3)      | 입고 목록, 신선도, 현재 시세 기준 예상 대금, 출하          | `ListView`, `ListTile`, `ElevatedButton`, `AlertDialog`, `SnackBar`             |
| 거래 기록 (탭 4) | 출하 내역, 누적 수익, 품목별 손익                          | `ListView`, `ListTile`, `Chip`                                                  |
| 품목 상세 (선택) | 시세 추이 차트, 목표 가격 설정                             | `CustomPaint` 또는 차트 패키지, `Slider`, `TextFormField`                       |
| 앱 정보          | 출처 표기, 데모 모드 스위치(설명 포함), 가상 게임 안내     | `ListView`, `SwitchListTile`, `AboutListTile`                                   |

공통으로 데이터 로딩 중에는 `CircularProgressIndicator`, 실패 시 오류 문구와 재시도 버튼을 보여준다. 시세 조회가 실패해도 마지막 시세로 게임은 계속된다.

**화면 이동**

```
하단 탭(BottomNavigationBar): 시세판 | 농장 | 창고 | 기록
시세판 ──(품목 탭, 선택)──▶ 품목 상세 ──(뒤로)──▶ 시세판
농장 ──(빈 밭 탭)──▶ 파종 선택 시트 ──(선택)──▶ 파종 후 농장 갱신
농장 ──(수확 가능 밭 탭)──▶ 수확 → 창고에 입고, 농장 갱신
창고 ──(출하 버튼)──▶ 확인 다이얼로그 ──(확인)──▶ 정산 후 창고·자금 갱신
탭 영역 ──(정보 아이콘)──▶ 앱 정보 ──(뒤로)──▶ 이전 탭
```

- 탭 전환은 `BottomNavigationBar` + `IndexedStack`, 화면 이동은 `Navigator.push` / `Navigator.pop`을 쓴다. 별도 라우팅 패키지는 쓰지 않는다.
- 데이터는 Firestore 변경을 따라 자동으로 갱신된다.

**사용자 이벤트 처리**

| 이벤트                 | 동작                                                                  |
| ---------------------- | --------------------------------------------------------------------- |
| 시세판 당겨서 새로고침 | API를 다시 조회 (최소 호출 간격 안에서는 캐시 사용)                   |
| 빈 밭 탭               | 품목 선택 시트 표시, 선택하면 파종비 차감 후 파종, 자금 부족이면 안내 |
| 수확 가능 밭 탭        | 수확 처리, 창고에 입고                                                |
| 출하 버튼              | 현재 시세·신선도로 예상 대금 표시 → 확인하면 정산                     |
| 데모 모드 스위치       | 성장 시간 배속 변경 (발표 시연용)                                     |
| 탭 전환                | 해당 화면 표시, 상태 유지                                             |

**반응형**

- `LayoutBuilder`/`MediaQuery`로 화면 폭에 맞춰 밭 격자의 열 수와 카드 폭을 조정하고, 세로·가로 전환에서도 레이아웃이 깨지지 않게 한다.

### 1-8. 발표 시연 시나리오

1. 시세판에서 실제 경매 시세와 기준 시각 확인
2. 농장에서 데모 모드를 켜고 작물 파종
3. 짧은 시간 뒤 수확 알림이 도착하는 것을 시연 (로컬 예약 알림)
4. 수확해 창고에 입고하고, 현재 시세 기준 예상 대금 확인 후 출하
5. 거래 기록에 정산 내역이 남는 것 확인 (Firebase 콘솔의 Firestore 데이터와 함께)
6. Firebase 콘솔에서 FCM 테스트 메시지를 보내 수신 시연 (포그라운드·백그라운드)
7. 테스트 실행 결과와 App Distribution으로 배포한 APK 설치 화면 제시

시연은 Android Studio 에뮬레이터 또는 실기기로 한다. 알림·FCM 수신은 실기기에서 먼저 확인한다.

---

## 2. 개발일정 (2026-10-01 ~ 2026-10-22)

**필수 기능을 10/16(금)까지 끝내고, 이후는 선택 기능·정리·발표 준비·버퍼로 쓴다.** 10/1~10/5에 이미 끝낸 작업이 있으면 체크리스트에서 체크하고 그만큼 일정을 앞당긴다.

기간 중 남은 공휴일은 10/9(금) 한글날이다.

### 주차별 목표

| 주차  | 기간                  | 목표                                                                       |
| ----- | --------------------- | -------------------------------------------------------------------------- |
| 1주차 | 10/1(목) ~ 10/7(수)   | 주제 확정, API 활용신청, 환경 구축, API 응답·품목 코드 확인, Firebase 연동 |
| 2주차 | 10/8(목) ~ 10/14(수)  | 시세판, 농장, 창고·출하·정산, 알림(로컬·FCM)                               |
| 3주차 | 10/15(목) ~ 10/22(목) | 테스트, APK 배포, 통합 테스트, 선택 기능, 발표 준비                        |

### 우선순위 규칙

- **일정이 밀리면 선택 기능부터 버린다.** 순서는 랜덤 이벤트 → 목표 가격 알림 → 시세 추이 차트 → 통합 테스트다.
- **필수 기능은 10/16까지 끝내는 것을 목표로 한다.** 10/17~19는 버퍼 겸 선택 기능 기간이다.
- `game_rules.dart`는 만들 때 바로 단위 테스트를 같이 쓴다. 테스트를 10/15에 몰아서 쓰지 않는다.
- 각 주차가 끝날 때 `flutter analyze` 오류가 0인지 확인하고, 기능 단위로 커밋한다.
- 하루 이상 막히는 항목(예: API 응답 포맷, 단위 환산)은 우회 방법(Fake 데이터)을 먼저 정하고 넘어간다.

### 리스크와 대응

| 리스크                                             | 대응                                                                                                  |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 경매 시간대가 아니면 조회 결과가 비어 있을 수 있음 | 마지막 성공 시세를 저장해 쓰고, 날짜를 하루 전으로 바꿔 재조회. 실제 동작은 키 발급 후 가장 먼저 확인 |
| 경매 건마다 단위·포장이 달라 kg 환산이 어려움      | 환산 함수를 분리해 단위 테스트. 환산 불가 건은 계산에서 제외                                          |
| 응답 건수가 많아 한도(일 10,000건)를 소진          | 도매시장·품목 코드로 조회 범위를 좁히고, 앱 안에서 일정 시간 캐시. 새로고침 최소 간격 적용            |
| 품목 코드를 모름                                   | 농축수산물 표준코드 API로 확인 (별도 활용신청이 필요할 수 있음). 안 되면 명세서의 코드표 사용         |
| 구버전 예제와 응답 필드명이 다름                   | 같은 제공기관의 다른 API에 컬럼 변경 안내가 있으므로, 첨부된 최신 명세서 기준으로 모델을 만든다       |
| API가 JSON이 아닌 XML로 응답                       | 키 발급 직후 가장 먼저 확인하고, XML이면 파싱 패키지 사용                                             |
| API 키 활성화 지연                                 | 지연되면 Fake 데이터로 UI·게임 규칙·테스트부터 진행                                                   |
| 릴리스 빌드에서 네트워크 실패                      | `https` 사용, `INTERNET` 권한 확인                                                                    |
| 알림이 기기·OS에 따라 동작하지 않음                | `POST_NOTIFICATIONS` 권한 요청, 비정확(inexact) 예약 사용, 실기기로 확인                              |
| 게임 밸런스를 맞추느라 시간 소모                   | 숫자는 설정 파일 한 곳에 모으고, 10/12 이후에는 조정하지 않는다                                       |

---

## 3. 기술 스택

| 영역      | 사용 기술                                                                       | 비용                       |
| --------- | ------------------------------------------------------------------------------- | -------------------------- |
| UI        | Flutter / Dart                                                                  | 무료                       |
| 상태 관리 | Riverpod (`AsyncNotifier`를 ViewModel로 사용)                                   | 무료                       |
| 저장소    | Cloud Firestore, Firebase Auth (익명)                                           | Spark(무료) 플랜           |
| 푸시      | Firebase Cloud Messaging                                                        | 무료                       |
| 로컬 알림 | flutter_local_notifications, timezone                                           | 무료                       |
| 시세 캐시 | shared_preferences (마지막 성공 시세 저장)                                      | 무료                       |
| 외부 API  | 한국농수산식품유통공사 전국 공영도매시장 실시간 경매정보 (공공데이터포털, REST) | 무료, 개발계정 일 10,000건 |
| 배포      | Firebase App Distribution                                                       | 무료                       |
| 선택      | 차트 패키지(fl_chart 등)                                                        | 무료                       |

- 패키지 버전은 `pubspec.yaml`을 기준으로 한다.
- Firebase는 Spark 플랜 그대로 쓰고 결제 수단을 등록하지 않는다. Cloud Functions는 Blaze(유료) 플랜이 필요하므로 쓰지 않는다.
- 무료 한도는 바뀔 수 있으므로 착수 전에 각 콘솔과 공식 문서에서 확인한다.

---

## 4. 시작하기

### Prerequisites

- Flutter SDK (stable), Android Studio 또는 Android SDK
- Node.js (Firebase CLI용)
- Firebase 프로젝트 1개 (Firestore, Authentication, Cloud Messaging 활성화)
- 공공데이터포털 전국 공영도매시장 실시간 경매정보 API 인증키

### 경매정보 API 키 확인

1. [공공데이터포털](https://www.data.go.kr)에 로그인한다. (활용신청은 완료한 상태)
2. 마이페이지에서 인증키와 승인 상태를 확인한다. 신청 직후에는 키가 활성화되기까지 시간이 걸릴 수 있다.
3. 상세 페이지에 첨부된 **API 명세서**를 내려받아 요청 주소, 요청 변수, 응답 필드를 확인한다.
4. 품목·도매시장 코드가 필요하므로 "한국농수산식품유통공사\_농축수산물 표준코드"도 필요하면 활용신청한다.

### Setup

```bash
# 1. 프로젝트 생성 후 의존성 설치
flutter create sise_nongbu
cd sise_nongbu
flutter pub get

# 2. Firebase CLI / FlutterFire CLI
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login

# 3. Firebase 연동 (lib/firebase_options.dart 생성)
flutterfire configure
```

Firebase 콘솔에서 다음을 켠다.

1. Authentication → 익명 로그인 사용 설정
2. Firestore Database 생성 후 아래 보안 규칙 적용
3. Cloud Messaging 확인 (Android 앱 등록 후 사용 가능)

### Environment

API 키는 코드에 넣지 않고 `--dart-define`으로 주입한다. **README나 코드에 실제 키를 적지 않는다.**

```bash
flutter run --dart-define=AUCTION_API_KEY=<공공데이터포털_인증키>
```

```dart
const auctionApiKey = String.fromEnvironment('AUCTION_API_KEY');
```

키가 들어 있는 파일은 커밋하지 않는다.

### Firestore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

### Commands

| 목적             | 명령                                                            |
| ---------------- | --------------------------------------------------------------- |
| 실행             | `flutter run --dart-define=AUCTION_API_KEY=...`                 |
| 정적 분석        | `flutter analyze`                                               |
| 포맷             | `dart format .`                                                 |
| 단위·위젯 테스트 | `flutter test`                                                  |
| 통합 테스트      | `flutter test integration_test`                                 |
| APK 빌드         | `flutter build apk --release --dart-define=AUCTION_API_KEY=...` |

---

## 5. 설계

### Architecture

MVVM. 각 계층은 바로 아래 계층만 안다.

```
View → ViewModel → Repository → Service → Firestore / REST API / FCM / 로컬 알림
```

| 계층       | 책임                                                   | 금지                           |
| ---------- | ------------------------------------------------------ | ------------------------------ |
| View       | 화면 표시, 사용자 입력 전달 (`ConsumerWidget`)         | Repository, Firebase 직접 사용 |
| ViewModel  | 상태 관리, 게임 규칙 호출(`game_rules`), 입력 검증     | Repository 외 계층 사용        |
| Repository | 데이터 창구, 출처 은닉, 모델 변환, 시세 캐시 정책      | Firebase·HTTP 직접 호출        |
| Service    | Firestore, HTTP, FCM, 알림 API 직접 호출 (유일한 계층) | 상태 보관                      |

`game_rules.dart`는 Flutter·Firebase에 의존하지 않는 순수 Dart 함수 모음이다. (파종비 계산, 수확 시각, 신선도 계수, 출하 대금, 단위 환산)

### Directory

```
lib/
├── main.dart                          # ProviderScope
├── firebase_options.dart              # flutterfire configure로 생성
├── core/
│   └── game_rules.dart                # 순수 Dart 게임 규칙, 설정값
├── models/
│   ├── auction_price.dart             # 품목별 kg당 시세
│   ├── crop.dart                      # 품목 정의(파종비, 수확량, 성장 시간)
│   ├── plot.dart
│   ├── inventory_lot.dart
│   └── trade.dart
├── services/
│   ├── auction_api_service.dart       # 경매정보 API 호출
│   ├── firestore_game_service.dart
│   └── notification_service.dart      # 로컬 알림 + FCM
├── repositories/
│   ├── market_repository.dart         # 시세 조회, 환산, 캐시
│   └── farm_repository.dart
├── providers/                         # 의존성 연결 (service → repository → viewmodel)
├── viewmodels/
│   ├── market_view_model.dart
│   ├── farm_view_model.dart
│   ├── inventory_view_model.dart
│   └── trade_view_model.dart
└── views/
    ├── home_shell.dart                # 하단 탭
    ├── market_page.dart
    ├── farm_page.dart
    ├── inventory_page.dart
    ├── trade_history_page.dart
    └── about_page.dart
test/
integration_test/
```

### Dependency Wiring

```dart
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final gameServiceProvider =
    Provider((ref) => FirestoreGameService(ref.watch(firestoreProvider)));
final farmRepositoryProvider =
    Provider((ref) => FarmRepository(ref.watch(gameServiceProvider)));
```

테스트에서는 필요한 계층의 Provider만 override한다.

### Data Model

경로: `users/{uid}`와 그 하위 컬렉션

**`users/{uid}`**

| 필드        | 타입      | 설명      |
| ----------- | --------- | --------- |
| money       | number    | 현재 자금 |
| totalProfit | number    | 누적 수익 |
| createdAt   | timestamp | 생성 시각 |
| updatedAt   | timestamp | 수정 시각 |

**`users/{uid}/plots/{plotId}`**

| 필드      | 타입       | 설명                          |
| --------- | ---------- | ----------------------------- |
| cropCode  | string?    | 품목 코드 (빈 밭이면 null)    |
| status    | string     | `empty` / `growing` / `ready` |
| plantedAt | timestamp? | 파종 시각                     |
| readyAt   | timestamp? | 수확 가능 시각                |

**`users/{uid}/inventory/{lotId}`**

| 필드        | 타입      | 설명                         |
| ----------- | --------- | ---------------------------- |
| cropCode    | string    | 품목 코드                    |
| quantityKg  | number    | 수량                         |
| harvestedAt | timestamp | 입고 시각 (신선도 계산 기준) |

**`users/{uid}/trades/{tradeId}`**

| 필드       | 타입      | 설명                |
| ---------- | --------- | ------------------- |
| cropCode   | string    | 품목 코드           |
| quantityKg | number    | 출하 수량           |
| unitPrice  | number    | 정산에 쓴 kg당 시세 |
| freshness  | number    | 신선도 계수         |
| amount     | number    | 정산 금액           |
| priceAsOf  | timestamp | 시세 기준 시각      |
| createdAt  | timestamp | 출하 시각           |

- 출하는 자금 증가, 입고분 삭제, 거래 기록 추가를 **한 번의 트랜잭션(또는 batch)** 으로 처리한다.
- 시세는 Firestore에 저장하지 않고 메모리 캐시와 `shared_preferences`(마지막 성공 시세)에만 둔다.

---

## 6. 연동

### 전국 공영도매시장 실시간 경매정보 API (필수)

**선정 이유**: 한국농수산식품유통공사가 전국 공영도매시장과 공판장에서 실시간으로 거래되는 농수산물의 품목, 거래량, 가격, 정산일자 등을 제공한다. 게임의 출하 대금을 코드로 정한 가짜 값이 아니라 실제 시장 시세로 정하려고 이 API를 선택했다.

공공데이터포털의 REST API이며 데이터 포맷은 JSON과 XML을 지원한다.

- 비용은 무료이고, 개발계정은 자동승인에 일 10,000건까지 호출할 수 있다. (포털 표기 기준)
- 일자 관련 요청 변수는 `YYYY-MM-DD` 형식으로 넣어야 정상 처리된다.
- 도매시장, 법인, 단위, 크기, 산지, 포장, 등급, 품목(대·중·소분류)은 코드값으로 요청·응답하고, 코드 목록은 표준코드 API로 조회한다.

```
GET
https://apis.data.go.kr/<기관코드>/<서비스경로>/<오퍼레이션>
    ?serviceKey=<인증키>&<조회일자>=YYYY-MM-DD&<도매시장코드>=...&<품목코드>=...&_type=json
```

- 요청 주소, 오퍼레이션 이름, 요청 변수명, 응답 필드명은 **첨부된 API 명세서로 확인하고 확정**한다. 위 주소는 형식 예시이며 실제 값이 아니다.
- 키 발급 후 JSON으로 응답하는지 먼저 호출해 확인하고, 오지 않으면 XML을 파싱한다.
- 응답의 `item`은 결과가 1건이면 객체, 여러 건이면 배열, 0건이면 없을 수 있으므로 모두 처리한다.
- 경매 건의 가격은 포장·단위 기준이므로 kg당 가격으로 환산한 뒤 거래량 가중평균으로 품목 시세를 만든다. 환산할 수 없는 건은 제외한다.
- 호출 한도를 지키기 위해 시세는 앱 안에서 일정 시간 캐시하고, 새로고침에도 최소 간격을 둔다.
- 호출 실패나 빈 응답이면 마지막 성공 시세를 쓰고 기준 시각을 표시한다. 게임 진행은 막지 않는다.
- 평문 `http`는 Android 릴리스 빌드에서 막힐 수 있으므로 `https`를 우선 쓴다.

### 알림 (필수)

푸시 알림은 두 가지를 모두 구현한다.

**로컬 예약 알림 (수확)**

- 파종하면 `flutter_local_notifications`의 예약 알림을 수확 가능 시각에 맞춰 등록한다 (`timezone` 패키지 필요, 기준은 `Asia/Seoul`).
- Android 13 이상은 알림 권한(`POST_NOTIFICATIONS`)을 런타임에 요청한다.
- 정확한 시각 알람은 별도 권한이 필요하므로 기본은 비정확(inexact) 예약을 쓴다.
- 수확하거나 데모 모드로 성장 시간이 바뀌면 기존 예약을 취소하고 다시 등록한다.

**FCM 푸시**

- `NotificationService`에서 FCM 토큰을 발급받고, 개발 중에는 터미널 로그(`FCM 토큰: ...`)에만 표시한다. (앱 화면에는 보이지 않음)
- Firebase 콘솔의 테스트 메시지로 수신을 확인한다. 포그라운드, 백그라운드, 종료 상태를 각각 시연할 수 있게 한다.
- 백그라운드 메시지 핸들러는 최상위 함수로 등록한다.
- 앱이 켜져 있는 동안(포그라운드) 받은 FCM 메시지는 Android가 알림을 자동으로 띄우지 않으므로, 앱에서 로컬 알림이나 스낵바로 표시한다.
- 서버 예약 푸시는 Cloud Functions(유료)가 필요하므로 범위 밖이다.

### 목표 가격 알림 (선택)

- 품목별 목표 가격을 정해 두고, 앱이 켜져 시세를 갱신할 때 목표를 넘으면 로컬 알림을 띄운다.
- 앱이 꺼진 상태에서 시세를 감시하려면 서버나 백그라운드 작업이 필요하므로 이번 범위에서는 하지 않는다.

---

## 7. 테스트

| 층          | 대상                                                                                         | 방법                            |
| ----------- | -------------------------------------------------------------------------------------------- | ------------------------------- |
| 정적 분석   | 전체                                                                                         | `flutter analyze` 오류 0        |
| 단위        | `game_rules` (파종비 차감, 수확 시각, 신선도, 출하 대금), 단위 환산, 응답 파싱(1건·배열·0건) | Fake Repository, 고정 입력값    |
| 단위        | ViewModel (자금 부족 파종 거부, 수확, 출하 정산)                                             | Fake Repository                 |
| 위젯        | 시세판(로딩·오류·정상), 밭 칸 상태 표시, 출하 확인 다이얼로그                                | Provider override               |
| 통합 (권장) | 파종 → 수확 → 출하 → 자금 반영                                                               | `flutter test integration_test` |
| 실측        | API 시세 조회, Firestore 저장, FCM 수신, 로컬 알림                                           | 실제 기기, Firebase 콘솔        |

- 단위·위젯 테스트에서는 실제 Firebase와 외부 API를 호출하지 않는다.
- 테스트가 실패하면 테스트가 아니라 코드를 고친다.
- 테스트 데이터는 더미만 쓴다. (실제 응답을 참고한 가짜 JSON)

---

## 8. 배포

Firebase App Distribution으로 Android APK를 배포한다. Google Play 출시는 하지 않는다. 스토어 출시 대신 APK 빌드와 테스터 배포로 배포 과정을 경험한다.

```bash
flutter build apk --release --dart-define=AUCTION_API_KEY=...

firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app <FIREBASE_ANDROID_APP_ID> \
  --groups "testers"
```

- 테스터 그룹은 Firebase 콘솔의 App Distribution에서 만든다.
- 릴리스 빌드에서 인터넷 권한(`INTERNET`)과 알림 권한이 매니페스트에 들어 있는지 확인한다.
- 배포 후에는 실제 기기에서 APK를 설치해 시세 조회, Firestore 저장, 알림 수신이 되는지 확인한다.
- 앱에 들어간 API 키는 APK에서 추출될 수 있으므로, 공유 범위를 테스터로 제한하고 필요하면 키를 재발급한다.

---

## 9. 규칙

- 코드를 고친 뒤에는 `flutter analyze` 오류가 0인지 확인한다.
- Firestore, HTTP, FCM, 알림 호출은 Service 밖에서 하지 않는다.
- 게임 규칙 계산은 `game_rules.dart`에만 둔다. 화면과 ViewModel에 계산식을 흩어 쓰지 않는다.
- 커밋은 기능 단위로 하고, 메시지는 `feat:`, `fix:`, `test:`, `docs:`, `refactor:` 접두사를 쓴다.
- API 키, 인증키는 저장소와 문서에 올리지 않는다.

---

## 10. 진행 체크리스트

**필수**

- [ ] 경매정보 API 키 확인, 명세서 확인, JSON 응답 여부와 품목·도매시장 코드 확인 (10/6~10/7)
- [ ] 프로젝트 생성, Firebase 연동 (Firestore, 익명 인증) (10/7)
- [ ] 시세 조회, 단위 환산, 시세판 화면 (10/8~10/9)
- [ ] 농장: 파종·성장·수확, `game_rules` 단위 테스트 (10/10~10/11)
- [ ] 창고·출하·정산, 거래 기록 (10/12)
- [ ] 수확 로컬 예약 알림 (10/13)
- [ ] FCM 토큰 발급, 포그라운드·백그라운드 수신 확인 (10/14)
- [ ] 단위·위젯 테스트 보강 (10/15)
- [ ] APK 빌드, App Distribution 배포 (10/16)

**권장**

- [ ] 통합 테스트 (10/17)

**선택**

- [ ] 시세 추이 미니 차트 (10/18)
- [ ] 목표 가격 도달 알림 (10/18)
- [ ] 랜덤 이벤트 (10/19)

**마무리**

- [ ] 발표 자료, 시연 시나리오, README 최종 정리 (10/20)
- [ ] 리허설 (10/21)
- [ ] 최종 제출 (10/22)

---

## 11. 출처

| 구분         | 내용                                                                                          |
| ------------ | --------------------------------------------------------------------------------------------- |
| 외부 데이터  | 한국농수산식품유통공사\_전국 공영도매시장 실시간 경매정보 (공공데이터포털)                    |
| 제공기관     | 한국농수산식품유통공사                                                                        |
| 주소         | https://www.data.go.kr/data/15141808/openapi.do                                               |
| 보조 데이터  | 한국농수산식품유통공사\_농축수산물 표준코드 (https://www.data.go.kr/data/15141818/openapi.do) |
| 이용허락범위 | 제한 없음 (포털 표기 기준, 활용신청 시 다시 확인)                                             |
| 용도         | 품목별 시세 표시, 출하 대금 정산                                                              |

- 앱이 보여주는 시세 정보는 위 API에서 조회한 데이터이며, 앱 정보 화면과 README에 출처를 표기한다.
- 과제 요건: 프로젝트학습계획서 (영진직업전문학교)
- 기술 문서: [Flutter](https://docs.flutter.dev), [Firebase](https://firebase.google.com/docs)
