# 말하는 도감 (voicedex)

유아(3~6세)가 그림을 보고 이름을 소리 내어 말해 맞히는 퀴즈 앱. Flutter + Flame, iOS/Android.
앱보다 먼저 확인하려고 **내부 테스트용 웹 빌드**를 둔다: https://ul-dong.github.io/voicedex/ (출시 대상 아님, 아래 "웹 버전" 참고).
사양의 기준 문서는 `docs/MASTER_PROMPT.md`, 그림체는 `docs/STYLE_GUIDE.md`.

현재 범위: 메인 화면, **동물 월드 1단계(색칠 그림 보고 이름 말하기)**, 도감(보상 2·3층, 기기 로컬 저장). 2·3단계 퀴즈, 과금, 페어런탈 게이트는 아직 없다(도감의 테두리·금테 표시는 데이터·화면은 있고 개발자 모드로 확인).

## 실행

Flutter 3.47.7 (Dart 3.13.5) 기준.

```sh
flutter pub get
flutter test                      # 단위 테스트
dart analyze                      # 정적 분석 (아래 "알려진 문제" 참고)
flutter run                       # 연결된 기기/시뮬레이터
flutter build ios --simulator     # iOS 시뮬레이터용 .app
flutter build apk --debug         # Android
```

### 디버그 기능 (debug 빌드 전용, release에서는 코드상 꺼짐 — 웹 테스트 빌드만 예외로 `?debug=1` URL 파라미터, 아래 "웹 버전")

| 기능 | 켜는 법 |
|---|---|
| 개발자 오버레이 (인식된 문자열, 판정 결과, 진행 단계) | 퀴즈 화면 **오른쪽 위 구석을 길게 누르기**(켜기/끄기), 또는 `flutter run --dart-define=VOICEDEX_DEBUG_OVERLAY=true` |
| 가짜 음성 입력 (마이크 없는 시뮬레이터용) | `--dart-define=VOICEDEX_FAKE_SPEECH=true` → 오버레이의 `correct / wrong / none / error` 버튼으로 답을 넣는다 |
| 가짜 음성 대본 (자동 진행) | `--dart-define=VOICEDEX_FAKE_SCRIPT=none,wrong,error,correct,correct,correct,correct,correct,correct` — 듣기마다 하나씩 자동 응답(1.2초 뒤). 대본이 끝나면 버튼 입력을 기다린다 |

기본값은 모두 꺼짐이고, 이때 아이 화면에는 글자가 하나도 없다. (`MaterialApp`의 DEBUG 배너도 꺼 두었다.)

## 웹 버전 (내부 테스트 전용, 출시 대상 아님)

- 주소: https://ul-dong.github.io/voicedex/ (GitHub Pages, `gh-pages` 브랜치)
- **개인정보 주의:** 웹 버전의 음성 인식은 브라우저 Web Speech API다. **크롬(데스크톱·Android)은 음성을 Google 서버로 보내 인식한다**(사파리는 Apple 서버). 앱 버전의 "기기 내 인식만" 원칙(`AppConfig.onDeviceRecognitionOnly`)은 웹에 적용되지 않는다. 그래서 웹 버전은 개발자·가족 내부 테스트용으로만 쓰고, 아이에게 배포하거나 출시하지 않는다.
- 빌드·배포:
  ```sh
  flutter build web --release --base-href /voicedex/
  tools/deploy_web.sh        # 빌드 + gh-pages 브랜치로 푸시(작업 트리는 건드리지 않음, git worktree 사용)
  ```
  GitHub Actions는 쓰지 않는다(로컬 빌드 결과를 `gh-pages` 고아 브랜치에 `.nojekyll`과 함께 올린다).
- 로컬 확인: `build/web`을 `/voicedex/` 경로로 서빙한다. 예: 빈 폴더에 `ln -s <프로젝트>/build/web voicedex` 후 그 폴더에서 `python3 -m http.server 8765` → http://127.0.0.1:8765/voicedex/

### 웹 디버그 (URL 파라미터, 기본 꺼짐)

| 주소 | 동작 |
|---|---|
| `…/voicedex/` | 아이 화면 그대로(글자 없음) |
| `…/voicedex/?debug=1` | 개발자 오버레이 켜짐(인식된 문자열·판정). 오른쪽 위 구석 길게 눌러 끄기/켜기 |
| `…/voicedex/?debug=1&fake=1` | 가짜 음성 입력(오버레이의 `correct / wrong / none / error` 버튼) |
| `…/voicedex/?debug=1&script=none,wrong,correct,correct,correct,correct,correct,correct` | 가짜 음성 대본(자동 진행) |
| `…/voicedex/?debug=1&dex=empty\|some\|mixed\|border\|gold` | 시작할 때 도감 상태를 강제로 바꿈(저장됨). debug 빌드는 `--dart-define=VOICEDEX_DEX=mixed` |
| `…/voicedex/?debug=1&overlay=0` | 개발자 패널을 꺼진 채 시작(아이 화면 그대로 확인). 오른쪽 위 구석 길게 눌러 켜기 |

도감 화면의 개발자 패널(debug 빌드 / `?debug=1`, 오른쪽 위 길게 누르기): `empty / some / mixed / border / gold` 프리셋, `edit`(켜면 칸을 누를 때마다 그림자→칸→테두리→금테 순으로 바뀜).

### 브라우저별 지원 (조사 결과, 2026-11)

| 브라우저 | 음성 인식 | 음성 출력(TTS) |
|---|---|---|
| 크롬/엣지 데스크톱 | 됨(`webkitSpeechRecognition`, Google 서버 인식) | 됨(OS 음성, macOS는 "유나" 등 기기 내 음성 우선) |
| 크롬 Android | 됨(Google 서버 인식) | 됨(기기 TTS 엔진) |
| 사파리 macOS / iOS 14.5+ | 대체로 됨(`webkitSpeechRecognition`, Siri·받아쓰기 켜져 있어야 함, Apple 서버 인식). iOS의 크롬·파이어폭스도 WebKit이라 같음 | 됨. 단 **사용자 제스처 안에서 한 번 말해야 소리가 풀린다** |
| 파이어폭스 데스크톱 | 없음 → 마이크 버튼 기다림 상태(앱은 계속 동작) | 됨 |
| 삼성 인터넷 등 기타 | 기기마다 다름(없으면 기다림 상태) | 대체로 됨 |

웹 대응 구현:
- `lib/services/speech/device_speech_input.dart`: 웹에서 언어 코드 `ko-KR`, 지원 여부 확인, 재생 버튼 탭(사용자 제스처) 때 `getUserMedia`로 마이크 권한을 먼저 받는다(거부·마이크 없음 → "사용 불가" → 마이크 버튼 기다림, 12초 응답 없으면 그냥 진행). 웹 오류 코드(`no-speech`, `not-allowed`, `audio-capture` 등)를 무응답/사용 불가로 나눈다. 웹 플러그인은 최종 결과 대신 듣기 시간이 끝난 뒤 결과를 넘겨준다.
- 목소리: 웹도 앱과 같은 `PackVoiceOutput`(녹음 MP3 우선 → 없으면 TTS)을 쓴다. 녹음·효과음은 `lib/platform/web_audio_web.dart`의 `WebAudioEngine`(Web Audio, 첫 터치에 잠금 해제, fetch→decode→재생, 효과음은 별도 gain)으로 튼다.
- `lib/services/voice/web_tts_speaker_web.dart`: 녹음이 없는 문장의 웹 TTS는 `flutter_tts` 대신 `speechSynthesis`를 직접 쓴다(`flutter_tts` 웹은 속도 단위가 달라 매우 느리고, 중단·오류 때 완료를 알리지 않아 진행이 멈출 수 있음). 끝·오류·안전 시간 중 먼저 오는 것에 돌아온다. 기기 내(localService) 한국어 음성을 우선 고른다.
- `web/index.html`: 첫 탭(=재생 버튼)에서 소리 없는 빈 문장을 말해 iOS 사파리의 TTS 잠금을 푼다.
- `lib/platform/web_audio*.dart`, `web_tts_speaker*.dart`: 웹 전용 코드는 조건부 import로 분리(앱 빌드·테스트에 영향 없음).

## 구조

```
lib/
  main.dart                      앱 시작, 서비스 생성
  app/app_config.dart            dart-define 설정(디버그 오버레이·가짜 음성), 기기 내 인식 정책
  app/app_services.dart          음성 출력·음성 입력·효과음·데이터 묶음
  content/species.dart           종 데이터 모델 (JSON → Species)
  content/world_catalog.dart     월드(동물→탈것→공룡) / 단계 종류(StageKind) / StageSpec(6문항)
  content/content_repository.dart  월드 데이터 로드
  quiz/answer_judge.dart         정답 판정기(정규화 + 부분 일치, 인식 실패 vs 오답)
  content/line_template.dart     대사 템플릿 규칙({name}, {hint}, {feature}, {name:이/가} 조사) — 녹음 대본 펼치기
  content/line_keys.dart         새 대사 키(LineKeys), 효과음 이름(SfxNames)
  progress/dex_progress.dart     도감 진행 모델·규칙(2층 열림, 3층 단계 표시, 힌트 문항 제외)
  progress/progress_store.dart   진행 저장(shared_preferences, 웹은 localStorage), ProgressController
  quiz/hint_ladder.dart          단계식 힌트 상태(특징 → 앞글자 → 따라 말하기)
  quiz/question_picker.dart      출제기(중복 없는 가중치 추출 + 도감 미보유 우선 보장 QuestionPicker.dexAware)
  quiz/stage_view.dart           화면 쪽 인터페이스(그림 표시·정답 연출·축하)
  quiz/name_stage_controller.dart  "그림 보고 이름 말하기" 진행기(1단계, 3단계에서 재사용 예정)
  services/voice/                VoiceOutput 인터페이스, PackVoiceOutput(녹음 팩 우선 → TTS 대체), 녹음 재생기·TTS 구현, 대사 키(VoiceKeys)·대사 표(VoiceLines) — 자세한 구조는 docs/VOICE.md
  services/speech/               SpeechInput 인터페이스, 기기 인식기 구현, 디버그용 가짜 입력
  services/sfx/                  효과음(SoundEffects 인터페이스, AudioSoundEffects: 앱 audioplayers / 웹 Web Audio)
  game/quiz_game.dart            Flame 장면(QuizStageView 구현): 등장·정답 튀어오름·축하
  game/components/               SVG 그림 컴포넌트, 반짝이·색종이 파티클
  game/svg_picture_cache.dart    SVG 파싱 캐시
  game/svg_clip_fix.dart         flutter_svg clipPath 버그 우회(아래 참고)
  ui/                            시작 화면, 메인 화면(home_screen), 도감(dex_screen, dex_grid), 스테이지 끝 도감 찍힘(stamp_overlay), 퀴즈 화면, 개발자 오버레이
  platform/web_audio*.dart       웹 전용: 음성 기능 지원 확인, 마이크 권한, Web Audio 재생(조건부 import)
web/                             웹 진입점(index.html: iOS 사파리 TTS 잠금 해제)
tools/deploy_web.sh              웹 빌드 → gh-pages 배포
tools/voice/                     녹음 음성 생성(gen_voice.command 증분 녹음, MeloTTS) — docs/VOICE.md
tools/generate_sfx.py            효과음 합성
assets/data/animals.json         동물 12종: id, 이름, 정답 후보, 유사 발음, 앞글자 힌트(hint), 특징 힌트(feature_hint), 그림 경로
assets/data/voice_lines_ko.json  대사 키 → 문장 틀
assets/voice/                    녹음 음성 팩: manifest.json(문장 → vNNNN.mp3) + mp3
assets/audio/sfx/                효과음 wav
test/                            판정기·데이터·출제기·진행기·대사·힌트·도감 진행·녹음 팩·SVG 렌더 테스트
```

그림은 원본 폴더 `assets/draft_silhouettes/cute/`를 pubspec에 그대로 등록해 쓴다(복사하지 않음, 폴더 구조 유지).

### 진행 흐름 (1단계)

시작 화면(재생 버튼, 마이크 권한) → 메인 화면("안녕! 오늘은 누구를 만나 볼까?") → 동물 나라 입구 → 문제마다: 그림 등장 → "이 동물은 누구일까?" → 자동 듣기(마이크 빨갛게, 퍼지는 고리 + 음량 고리) → 판정
- 정답: 그림이 웅크렸다 튀어오르며 흔들림 + 반짝이 + 정답 효과음 + "맞아! 코끼리!" → 다음 문제
- 오답(단계식 힌트, 횟수 제한 없음): 1번째 특징 "코가 아주아주 길어!" → 2번째 앞글자 "코..." → 3번째부터 "코끼리! 따라 해 볼까?" → 따라 말하면 정답("그래, 코끼리! 잘 따라 했어!")
- 인식 실패(무응답·결과 없음·에러): "다시 말해줄래?" → 다시 듣기. 오답으로 세지 않고 힌트도 없음. **3번 이어지면 자동 듣기를 멈추고** 마이크 버튼이 주황색으로 숨쉬며 누르기를 기다린다(아이가 자리를 떴을 때 무한 반복 방지). 권한 없음·마이크 없음은 바로 기다림 상태.
- 그림을 누르면 문제를 다시 말하고 다시 듣는다. 마이크를 누르면 바로 다시 듣는다.
- 6문항 후: 만난 6종이 두 줄로 서서 차례로 콩콩 뛰고 색종이 + "와, 다 맞혔어! 정말 잘했어!" → 도감 12칸이 나타나고 맞힌 종이 차례로 칸으로 날아가 찍힘(새 종은 크게 + 반짝, "새 친구가 도감에 들어왔어!") → 메인 화면.
- 출제: 도감 미보유 종 우선(스테이지마다 최소 2종 보장) → 빈 도감에서 최대 4스테이지면 12종이 다 찬다.

### 2·3단계를 붙일 자리

- `StageKind.matchShadow`, `StageKind.nameFromShadow`가 정의되어 있고, `NameStageController`는 질문 대사 키만 바꾸면 3단계에 재사용할 수 있다(`_askKey`). 그림자 그림 경로는 이미 `shadow_image`에 있다.
- 탈것·공룡 월드는 `assets/data/vehicles.json` 등을 같은 형식으로 만들고 `WorldCatalog`에 추가한다(공룡 단축형은 `answers`에 넣는다).
- 2·3단계 스테이지 결과도 같은 `StageResult`(world, kind, 문항별 힌트 사용 여부)로 `ProgressController.applyStage`에 넘기면 테두리·금테가 붙는다.

## 정답 판정

- 정규화: 한글·영문·숫자 외(공백·문장부호·기호) 제거, 소문자.
- 인식기의 후보 문자열(Android는 최대 10개, iOS는 전사 후보) 중 하나라도 `answers + similar`의 어떤 문자열을 **포함**하면 정답.
  - "코끼리야", "펭귄이", "이건 사자예요"는 정식 이름이 포함되어 정답. "원숭", "캥거", "코뿔"처럼 이름 일부는 `answers`에 넣어 인정한다.
  - 첫 음절 한 글자("코")는 정답 후보에 넣지 않는다(코끼리/코뿔소 혼동).
- 테스트가 "한 종의 정답 후보가 다른 종 이름 안에 들어 있지 않음"을 확인한다(교차 오인 방지).
- 듣는 중 중간 결과가 이미 정답이면 바로 끝내고 넘어간다.

## 음성 인식과 개인정보 (조사 결과)

사용 플러그인: `speech_to_text 7.5.0` (iOS: Apple `SFSpeechRecognizer`, Android: 플랫폼 `SpeechRecognizer`). 플러그인 소스를 직접 확인한 내용이다.

### iOS
- 앱은 `onDevice: true`로 듣는다 → 플러그인이 `SFSpeechAudioBufferRecognitionRequest.requiresOnDeviceRecognition = true`를 설정한다. Apple 문서상 이 경우 **음성이 기기 밖(Apple 서버)으로 전송되지 않는다.**
- 기기가 ko-KR 기기 내 인식을 지원하지 않으면 플러그인이 `onDeviceError`를 돌려주고 **서버 인식으로 넘어가지 않는다**(인식이 안 될 뿐). 앱은 이를 "사용 불가"로 처리해 마이크 버튼을 기다림 상태로 둔다.
  - 참고: 이 경우 플러그인(7.5.0)은 에러를 돌려준 뒤에도 `return` 하지 않고 듣기 준비를 계속하는 코드 결함이 있으나, 요청에 `requiresOnDeviceRecognition`이 설정되므로 서버 전송은 일어나지 않는다.
- **주의(부모에게 보이는 문구):** iOS의 음성 인식 권한 창에는 앱 문구와 별개로 시스템 기본 문장 "사용자의 요청을 처리하기 위해 이 앱의 음성 데이터가 Apple에 전송됩니다…"가 항상 함께 표시된다(시뮬레이터에서 확인). 이 앱은 기기 내 인식만 쓰지만 이 시스템 문장은 앱이 바꿀 수 없다. 앱 문구는 "이 기기 안에서만 처리"라고 적었다 — 출시 전 문구를 법무/개인정보처리방침과 맞출 것.
- `AppConfig.onDeviceRecognitionOnly = true`가 이 정책 스위치다. false로 바꾸면 Apple 서버 인식이 허용된다(권장하지 않음).

### Android
- 앱은 `onDevice: true`로 듣는다. 플러그인 동작:
  1. Android 12(API 31)+ 이고 `SpeechRecognizer.isOnDeviceRecognitionAvailable()`가 true면 `createOnDeviceSpeechRecognizer()` → **기기 내 인식**.
  2. 그렇지 않으면 `createSpeechRecognizer()` = **기기의 기본 음성 인식 서비스**(대부분 Google 앱, 삼성 기기는 설정에 따라 Samsung). 이 서비스는 별도 앱이며 **음성을 자기 서버로 보낼 수 있다.** 이 앱이 막을 수 없다.
  3. 플러그인은 이때 `EXTRA_PREFER_OFFLINE`(오프라인 선호 힌트)을 넣으려 하지만, 7.5.0 코드에서는 인식기 생성 시 같은 언어·옵션으로 인텐트를 먼저 만들어 두기 때문에(`onDevice=false`로) 기기 기본 언어가 ko-KR인 경우 **오프라인 선호 힌트가 실제로는 빠질 수 있다**(소스 확인, 실기기 미검증). 또한 이 값은 힌트일 뿐 강제가 아니다.
  4. Korean 기기 내 인식 지원 여부는 기기·Google 앱 버전·언어팩 다운로드 여부에 따라 다르다.
- 앱 자체는 **release 빌드에 `INTERNET` 권한이 없다**(debug/profile 빌드에는 Flutter 개발 도구용으로 들어감). 따라서 앱 코드가 직접 네트워크로 보내는 것은 없다. 인식 서비스 앱의 네트워크 사용은 그 앱의 권한이다.
- Android 권한 창에는 앱이 문구를 넣을 수 없다(시스템 기본 "오디오 녹음" 문구). 매니페스트에 부모 대상 설명을 주석으로 남겼고, 출시 시 스토어 설명·개인정보처리방침·(필요하면) 권한 요청 전 부모용 안내 화면으로 보완해야 한다.
- 출시 전 결정 필요: 기기 내 인식이 없는 Android 기기에서 (a) 기본 인식기 사용을 허용할지, (b) 막고 음성 기능을 끌지. 현재 코드는 (a)다. (b)로 하려면 플러그인이 기기 내 인식 가능 여부를 노출하지 않으므로 소형 플랫폼 채널(`SpeechRecognizer.isOnDeviceRecognitionAvailable`)을 추가해야 한다.

### TTS
- 안내 목소리는 앱에 들어 있는 녹음 파일이 우선이고, 녹음이 없는 문장만 TTS로 말한다.
- `flutter_tts 4.2.5` → iOS `AVSpeechSynthesizer`, Android 기본 TTS 엔진. 기기 내 합성이며 앱이 보내는 데이터는 없다. (Android 엔진이 네트워크 음성을 쓰도록 사용자가 설정한 경우는 엔진 동작이다.)

### 저장
- 인식된 음성·문자열은 저장하지 않는다(디버그 오버레이의 최근 기록은 메모리에만, debug 빌드 전용). 광고 SDK·분석 도구·계정 없음.

## 가제 교체 지점 (출시 전)

| 항목 | 현재 값 | 바꿀 곳 |
|---|---|---|
| iOS 번들 ID | `com.example.voicedex` | `ios/Runner.xcodeproj/project.pbxproj`의 `PRODUCT_BUNDLE_IDENTIFIER` (Runner, RunnerTests 각 Debug/Release/Profile) |
| Android 패키지 | `com.example.voicedex` | `android/app/build.gradle.kts`의 `namespace`, `applicationId` + `android/app/src/main/kotlin/com/example/voicedex/MainActivity.kt`의 `package` 선언과 폴더 경로 |
| 앱 표시 이름 | 말하는 도감 | `ios/Runner/Info.plist`의 `CFBundleDisplayName`, `android/app/src/main/AndroidManifest.xml`의 `android:label`, `lib/ui/voicedex_app.dart`의 `title` |
| 권한 문구 | 부모 대상 한국어 | `ios/Runner/Info.plist`의 `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |

## 목소리·효과음

자세한 내용은 `docs/VOICE.md`.

- 안내 목소리는 `PackVoiceOutput`이 맡는다: 대사 → 통문장(`VoiceLines.render`, `LineTemplate`) → `assets/voice/manifest.json`에서 **문장 그대로** 찾아 녹음 MP3를 튼다. 녹음이 없거나 재생에 실패하면 같은 문장을 기기 TTS로 말한다(앱 `flutter_tts`, 웹 `speechSynthesis`). 새로 말하면 앞의 말은 끊긴다.
- 녹음은 무료 음성 모델 MeloTTS(한국어)로 만들어 어린이 느낌으로 처리한 통문장이다(문장 하나 = 녹음 하나).
- 대사를 추가·수정한 뒤 `tools/voice/gen_voice.command`를 돌리면 **새 문장만** 녹음해 매니페스트에 합친다(증분, 번호는 영구). 목소리 설정을 바꿨을 때만 `--all`. 음성 모델 venv는 저장소 밖(`~/alokdev/melo-venv`)에 둔다.
- `flutter test`의 `test/voice_pack_test.dart`가 녹음이 빠진 문장을 알려 준다.
- 효과음(`assets/audio/sfx/*.wav`, `tools/generate_sfx.py`로 합성)은 목소리와 다른 플레이어로 겹쳐 틀어 목소리를 끊지 않는다.
- iOS는 녹음 재생·TTS·음성 인식이 같은 오디오 세션(playAndRecord + defaultToSpeaker)을 쓴다(`audio_session.dart`).

## 그림(SVG) 렌더링

- `flutter_svg 2.3.4`(vector_graphics_compiler 1.3.6)로 렌더한다. 12종 모두 원본과 같게 나오는지 headless Chrome 렌더와 픽셀 비교했다(`test/svg_render_test.dart`가 `VOICEDEX_SVG_OUT=<폴더>`일 때 PNG를 쓴다).
- **발견한 문제:** vector_graphics_compiler는 `<clipPath>`의 자식 path들을 하나의 nonzero path로 이어 붙인다. 감는 방향이 반대인 부위가 겹치는 곳(다리-몸 등)은 클립에서 빠져, 음영 사본이 덮이지 않고 어두운 얼룩이 생겼다(원본 대비 2~4% 픽셀이 ~20 밝기 차이).
- **해결:** `lib/game/svg_clip_fix.dart`가 앱이 SVG를 읽을 때 clipPath 자식 path들의 감는 방향을 시계 방향으로 통일한다(원본 파일은 수정하지 않음). 수정 후 차이는 경계 안티앨리어싱 수준(픽셀의 0.1% 이하)이다.
  `Q` 명령, `transform="translate(...)"`, `opacity`, stroke 선은 문제없이 렌더된다.
- 그림 파이프라인(`tools/cute/`)에서 clipPath 자식 방향을 통일해 내보내면 이 우회는 필요 없어진다. 더 확실히 하려면 PNG 사전 렌더도 가능하다.

## 알려진 문제

- **`flutter analyze`가 이 폴더에서 분석 서버 오류로 죽는다**(경로의 한글·공백 때문에 LSP 메시지 길이 계산이 틀림: `FormatException: Unterminated string`). `dart analyze`는 정상 동작하며 경고 0이다. ASCII 경로로 복사하면 `flutter analyze`도 동작한다.
- iOS 시뮬레이터는 이 Mac 환경에서 마이크 입력이 없어(`Not enough available inputs`) 실제 음성 인식을 확인할 수 없었다 → 가짜 음성 입력으로 흐름을 검증했다.
- `flutter_tts`는 iOS Swift Package Manager 미지원(CocoaPods로 빌드됨), Android는 Kotlin Gradle Plugin 경고가 난다. 둘 다 현재 빌드는 성공.
