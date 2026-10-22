# 시세 농부 (sise_nongbu) 프로젝트 설명서

실제 공영도매시장(서울가락) 경매 시세로 움직이는 **농장 시뮬레이션 게임**. Flutter 앱(Android 중심) + Firebase.
학교 PC에서 이어서 작업할 때 이 파일을 먼저 읽는다. **API 키는 이 파일에 적지 않는다.**

## 기술
- Flutter 3.x / Dart, 상태관리 Riverpod, Firebase(Auth·Firestore·Messaging), 로컬 알림
- 시세: 공공데이터포털 "전국 공영도매시장 실시간 경매정보" API (`lib/services/auction_api_service.dart`)
  - 서버 시세는 GitHub Actions(`.github/workflows/prices.yml`, `tools/update_prices.mjs`)가 Firestore `market/prices`에 저장
- AI 도우미: Gemini (글·사진), 음성 입력은 기기 음성 인식(`speech_to_text`), 사진은 `image_picker`

## 실행 방법
```bash
flutter pub get
flutter run --dart-define-from-file=.env.local
```
- `.env.local`(깃허브에 올리지 않음)에 `AUCTION_API_KEY`, `GEMINI_API_KEY`가 들어 있다. 키는 USB/개인 메모로 따로 옮긴다.
- 그냥 `flutter run`만 하면 키가 없어서 시세는 샘플, AI 도우미는 오프라인 규칙 도우미로 동작한다.
- 이 노트북(램 6GB)은 첫 빌드가 오래 걸린다(20분 가까이). 에뮬레이터는 810×1755, 밀도 360이 부드럽다. 학교 PC는 1080×2340, 밀도 440도 가능.
- `flutter clean`은 이상한 오류가 날 때만 하고, 한 뒤에는 `flutter pub get`을 꼭 한다.

## APK 만들기·탭에 설치
```bash
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=.env.local
```
- 결과: `build/app/outputs/flutter-apk/app-release.apk`(약 38MB). release도 debug 키로 서명돼서 바로 설치되고, 그 PC의 SHA-1이 Firebase에 등록돼 있으면 구글 로그인도 된다.
- 기기: 가영의 Galaxy Tab S6 Lite(SM-P610, arm64). 개발자 옵션·USB 디버깅을 켜 두었다. 연결하면 `adb install -r <apk>`로 바로 설치된다(처음 연결한 PC는 탭에서 "USB 디버깅 허용"을 눌러야 한다).
- 케이블은 데이터가 되는 것이어야 한다(충전 전용 케이블은 PC에 안 뜬다).
- 다른 PC에서 만든 APK는 서명 키가 달라서 덮어 설치가 안 된다. 탭의 앱을 지우고 설치한다(게스트 데이터는 사라지니 계정 연결을 먼저).
- 이 노트북 D 드라이브는 전체 5GB라 빌드 중 "디스크 공간이 부족합니다"가 날 수 있다. 그때는 `flutter clean` 후 다시 빌드한다.
- 구글 로그인은 `google_sign_in`(앱 안 계정 고르기)으로 한다. 브라우저 방식(`signInWithProvider`)은 크롬에 "missing initial state" 오류 창이 남아서 바꿨다.

## 플레이 스토어(내부 테스트)에 새 버전 올리기
1. `pubspec.yaml`의 `version: 1.0.0+N`에서 `+N`을 1 올린다 (같은 번호는 다시 못 올림)
2. `flutter build appbundle --release --dart-define-from-file=.env.local` (업로드 키로 서명됨)
3. `node tools/upload_play.mjs "출시 노트 한 줄" "두 번째 줄"` → 내부 테스트 트랙에 바로 출시, 탭의 플레이 스토어에서 업데이트
- 필요한 파일(깃허브에 없음, USB로 옮김): `android/key.properties`, `android/app/upload-keystore.jks`(업로드 키), `android/play-service-account.json`(업로드 전용 서비스 계정 `play-upload@sise-nongbu.iam.gserviceaccount.com` 키, Play Console에서 이 앱의 '테스트 트랙 출시' 권한만 있음)
- 처음 한 번 `cd tools && npm install --no-save googleapis@144`
- 패키지 이름 `com.sise_nongbu`, 앱 이름 "하루 농장:시세 농부 게임". 플레이 앱 서명 키 SHA-1과 업로드 키 SHA-1은 Firebase에 등록돼 있다.

## 학교 PC에서 처음 할 일
1. 이 폴더를 받는다: `git clone https://github.com/KIMGAYEONG12/sise_nongbu.git` (비공개 저장소)
2. `.env.local` 복사해 넣기
3. **구글 로그인을 쓰려면 그 PC의 SHA-1을 Firebase 콘솔(프로젝트 `sise-nongbu` → 프로젝트 설정 → 내 앱 → 디지털 지문 추가)에 등록**하고 `google-services.json`을 다시 받아 `android/app/`에 덮어쓴다.
   - SHA-1은 `keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`의 결과를 SHA1로 바꿔 구한다(한글 Windows에서 `-list -v`는 오류가 난다).

## 저장·공유 (깃허브)
```bash
git add .
git commit -m "수정한 내용"
git push
```
저장소: https://github.com/KIMGAYEONG12/sise_nongbu (브랜치 `main`). 키·로그는 `.gitignore`로 올라가지 않는다.

## 지금까지 만든 것
- 농장 화면: 시안 그림 위에 날씨·프로필, 연못 물고기, 밭의 흔들리는 작물, 순찰 로봇, 하우스(눌러서 정보·더 짓기)
- 작물 25종(원래 6종 + 15종 추가), 도감, 상점, 창고, 판매(작물 그림 + "○○가 판매되었습니다!")
- 하우스: 몇 채든 구매(한 채 10,000으로 고정), 5채까지 10%씩·이후 4%씩 단축(최대 70%), 지을 때마다 커지고 이름 변경(비닐하우스 → … → AI 퀀텀 팜 → … → 우주 문명 농장), 11단계 이후 첨단 장치(위성 등)
- 작물 매칭: 같은 작물 짝 맞추기, 작물 3~6종 고르기, 저장하고 나가기/이어서 하기
- 레벨업 창(시안 그림 사용)과 보상(레벨이 높을수록 증가), 나의 칭호(레벨마다 단계 상승)
- 업적·미션 "전체 받기", MY 화면(보유 포인트/금액, 칭호, 메뉴)
- AI 도우미: 글·사진·음성 질문, 추천 질문 옆으로 밀기
- 재화 두 가지: 작물을 사고파는 돈은 **P**(포인트 상점), 미션·업적·레벨업·판매 보상은 **캐시**(클로버 금화, 특별 상점). 그림·표기는 `lib/widgets/cash_art.dart`(`cash()`, `CashCoin`, `CashPill`)
- 농장 하우스 → 아파트: 하우스 단계 1~4는 지붕 있는 농장 하우스, 5~10은 기본·중형·대형·프리미엄·럭셔리·스카이 아파트, 그 위는 "스카이 아파트 +n" (`lib/core/home_rules.dart`, 그림 `lib/widgets/home_art.dart`). 단계가 오를수록 농장에서 커진다
- 하우스 둘러보기(`lib/views/home_tour_page.dart`): 확대·이동·자동 둘러보기, 레벨별 미리보기, 안으로 들어가기(거실·주방·침실·발코니·유리 온실, 방 그림 `home_interior_art.dart`), 아파트 편의 시설
- 우체통 새 디자인(색은 고른 색 유지, 편지 오면 깃발+노란 빛줄기, 편지 창에는 문이 열린 우체통), 농장 첫 화면 아래 "작물 관리가 있어요" 스크롤 안내 알림창(`scroll_hint.dart`)

## 주요 파일
- `lib/core/` 순수 규칙(작물 `game_rules.dart`, 진행·하우스·보상 `progress_rules.dart`, 매칭 `match_logic.dart`)
- `lib/views/` 화면, `lib/widgets/` 공용 그림(`greenhouse_art.dart`, `farm_life.dart`, `pond_fish.dart` …)
- `lib/services/firestore_game_service.dart` 저장 규칙(거래·구매·보상은 트랜잭션)
- `test/` 테스트 약 110개: `flutter test`, 점검: `flutter analyze`
- `docs/design/` UI/UX 피그마 디자인: `시세농부_UIUX.fig`(피그마 홈에 끌어다 놓으면 열림), 공유 링크는 `피그마주소.txt`

## 알아둘 점
- 새 작물의 씨앗값·수확량은 임의로 정한 값이다(시세 코드는 실제 가락시장 품목코드).
- 에뮬레이터에서는 카메라 앱·한국어 음성 팩이 없어 사진(카메라)·음성이 안 될 수 있다. 실제 폰에서 확인한다.
- 레벨업 일러스트(`assets/images/levelup_card.png`)는 시안에서 오려 낸 작은 그림이라 약간 흐리다. 더 선명한 원본이 있으면 교체한다.
- 학교 PC에서 Claude에게 작업을 시킬 때는 이 파일을 읽으라고 말하면 처음부터 설명하지 않아도 된다.
