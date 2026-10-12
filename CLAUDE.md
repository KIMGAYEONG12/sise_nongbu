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
- 하우스: 몇 채든 구매(20,000원부터 10,000원씩↑), 5채까지 10%씩·이후 4%씩 단축(최대 70%), 지을 때마다 커지고 이름 변경(비닐하우스 → … → AI 퀀텀 팜 → … → 우주 문명 농장), 11단계 이후 첨단 장치(위성 등)
- 작물 매칭: 같은 작물 짝 맞추기, 작물 3~6종 고르기, 저장하고 나가기/이어서 하기
- 레벨업 창(시안 그림 사용)과 보상(레벨이 높을수록 증가), 나의 칭호(레벨마다 단계 상승)
- 업적·미션 "전체 받기", MY 화면(보유 포인트/금액, 칭호, 메뉴)
- AI 도우미: 글·사진·음성 질문, 추천 질문 옆으로 밀기

## 주요 파일
- `lib/core/` 순수 규칙(작물 `game_rules.dart`, 진행·하우스·보상 `progress_rules.dart`, 매칭 `match_logic.dart`)
- `lib/views/` 화면, `lib/widgets/` 공용 그림(`greenhouse_art.dart`, `farm_life.dart`, `pond_fish.dart` …)
- `lib/services/firestore_game_service.dart` 저장 규칙(거래·구매·보상은 트랜잭션)
- `test/` 테스트 약 110개: `flutter test`, 점검: `flutter analyze`

## 알아둘 점
- 새 작물의 씨앗값·수확량은 임의로 정한 값이다(시세 코드는 실제 가락시장 품목코드).
- 에뮬레이터에서는 카메라 앱·한국어 음성 팩이 없어 사진(카메라)·음성이 안 될 수 있다. 실제 폰에서 확인한다.
- 레벨업 일러스트(`assets/images/levelup_card.png`)는 시안에서 오려 낸 작은 그림이라 약간 흐리다. 더 선명한 원본이 있으면 교체한다.
- 학교 PC에서 Claude에게 작업을 시킬 때는 이 파일을 읽으라고 말하면 처음부터 설명하지 않아도 된다.
