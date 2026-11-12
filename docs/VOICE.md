# 목소리·효과음 (voicedex)

안내 목소리는 **미리 녹음한 통문장 MP3를 우선** 틀고, 녹음이 없는 문장만 **기기 TTS로 대신** 말한다.
방식은 같은 제작자의 다른 앱 "알록달록 꼬마 놀이터"를 따랐다(같은 음성 모델·같은 설정·같은 seed → 같은 목소리).
단, 알록달록이 쓰던 "조각 이어 붙이기"는 이음새에서 억양이 끊겨 쓰지 않는다. **문장 하나 = 녹음 하나**다.

## 구조

```
assets/data/voice_lines_ko.json   대사 키 → 문장 틀({name}, {hint}, {feature}, {name:이/가} …)
lib/content/line_template.dart    문장 틀 채우기·조사 규칙(LineTemplate) — 앱 재생과 녹음 대본이 같은 함수를 쓴다
lib/services/voice/
  voice_output.dart               VoiceOutput 인터페이스(say/stop)
  voice_lines.dart                VoiceLines: 대사 → 문장(render = LineTemplate.expand)
  voice_pack.dart                 VoicePack: assets/voice/manifest.json(문장 → vNNNN.mp3) 조회
  pack_voice_output.dart          PackVoiceOutput: 녹음 우선 → 없거나 실패하면 TTS, 끼어들기(번호표)
  voice_engines.dart              ClipPlayer(녹음 재생)·TextSpeaker(TTS) 인터페이스 — 테스트는 가짜로 바꾼다
  clip_players.dart               AudioplayersClipPlayer(앱) / WebAudioClipPlayer(웹)
  flutter_tts_speaker.dart        앱 TTS(flutter_tts)
  web_tts_speaker*.dart           웹 TTS(speechSynthesis 직접, 조건부 import)
  voice_choice.dart               voiceScore(음성 고르기)·ttsTone(속도·음높이)·speakGuard(안전 시간)
  audio_session.dart              앱 오디오 세션(iOS 범주·Android 포커스) 한곳에서
  voice_sentences.dart            allVoiceSentences: 앱이 말하는 모든 통문장(녹음 대본)
  create_voice_output.dart        조립(앱: audioplayers+flutter_tts, 웹: Web Audio+speechSynthesis)
lib/services/sfx/
  sound_effects.dart              SoundEffects 인터페이스(play(name)), Sfx 목록, 기록용 구현
  audio_sound_effects.dart        AudioSoundEffects(앱: audioplayers, 웹: Web Audio)
lib/platform/web_audio_web.dart   WebAudioEngine(웹 전용): 첫 터치 잠금 해제, fetch→decode→재생, 효과음 별도 gain
assets/voice/                     manifest.json + v0001.mp3 … (mono 24kHz 40kbps, -16 LUFS)
assets/audio/sfx/                 효과음 wav 9개
tools/voice/                      녹음 생성(gen_voice.command, gen_voice.py, child_voice.py, export_lines_test.dart, check_voice.py)
tools/generate_sfx.py             효과음 합성
```

### 재생 흐름 (`PackVoiceOutput.say`)

1. 대사 → 문장 (`VoiceLines.render`, 예: `correct.say_name` + 곰 → "맞아! 곰!").
2. 번호표 `_token`을 올리고 앞의 말(녹음·TTS)을 멈춘다. 앞의 `say`는 바로 돌아온다.
3. 매니페스트에서 **문장 그대로** 찾는다(앞뒤·겹친 띄어쓰기만 무시, 문장부호는 구별). 있으면 녹음을 끝까지 튼다.
4. 녹음이 없거나 재생 실패(파일 없음, 웹에서 소리 잠김 등)면 같은 문장을 TTS로 말한다.
5. TTS는 **끝 / 오류 / 안전 시간(3초 + 글자당 0.25초) 중 먼저 오는 것**에서 돌아온다. `stop()`이면 즉시.

효과음은 목소리와 다른 플레이어(웹은 다른 gain)로 겹쳐 틀어서 **목소리를 끊지 않는다.** `play()`는 재생을 시작하면 돌아온다.

## 녹음 만들기·추가하기

```sh
tools/voice/gen_voice.command          # 새 문장만 녹음(증분). 대사를 추가한 뒤 이것만 돌리면 된다
tools/voice/gen_voice.command --all    # 전부 다시(목소리 설정을 바꿨을 때만)
VOICEDEX_NONINTERACTIVE=1 tools/voice/gen_voice.command   # 끝에 Enter를 기다리지 않음
```

하는 일:
1. `flutter test tools/voice/export_lines_test.dart` → `tools/voice/lines.json`
   - `voice_lines_ko.json`의 모든 대사. 종에 따라 바뀌는 대사는 `WorldCatalog.ordered`의 **모든 월드·모든 종**으로 펼친다(조사 포함).
   - 같은 문장은 한 번(코끼리·코뿔소 힌트 "코..."). 채우지 못한 `{…}`이 남으면 실패.
   - 이미 녹음된 문장은 매니페스트의 파일 이름을 그대로, **새 문장만 다음 번호**(번호는 영구, 예전 번호를 다시 쓰지 않는다).
2. `~/alokdev/melo-venv`(알록달록과 공유, 없으면 Homebrew python@3.10으로 생성·설치)에서 `gen_voice.py`:
   파일이 없는 문장만 MeloTTS 한국어(seed 1234, speed 0.82, sdp 0.5, noise 0.65/0.9) → `child_voice.py`
   (Praat 피치 +5반음·포먼트 ×1.12, 서울 말투 억양, 말끝 늘이기, 따뜻한 EQ, -16 LUFS / 최대 -1.5 dBFS) →
   ffmpeg mono 24kHz 40kbps MP3. 매니페스트는 지우지 않고 합친다(대사에서 빠진 문장의 녹음도 남는다).
3. `check_voice.py`: 모든 문장이 매니페스트에 있는지, 길이 0.3~10초, 음량 -16±2 LUFS, 무음 아님을 ffmpeg로 확인.
4. 확인: `flutter test` — `test/voice_pack_test.dart`가 녹음 없는 문장을 알려 준다(앱은 그 문장을 TTS로 말한다).

알록달록 스크립트와의 차이(목소리 설정은 동일):
- 경로(`tools/voice/`, 대사는 `voice_lines_ko.json`에서), Homebrew·venv는 이미 있으면 건너뜀, 녹음 확인 단계 추가.
- `gen_voice.py`의 `say_text`: 모델에 넣을 때만 "..."를 "…"로 바꾼다. "기...", "원..."에서 MeloTTS가 끝에
  소리 조각을 하나 더 붙이는 것을 확인했다(ffmpeg 무음 구간 분석). 매니페스트 키는 원래 문장 그대로.
- 같은 seed라도 실행마다 MP3 바이트가 조금 다를 수 있다(부동소수 연산 순서). 들리는 목소리는 같다.

자리 표시 규칙(`template_rules`): `{name}` 이름, `{hint}` 앞글자, `{feature}` 특징 문장,
`{name:A/B}` 받침 있으면 A·없으면 B, `{name:으로/로}`는 ㄹ 받침도 "로". 새 자리 표시를 만들면
`LineTemplate`에 넣어야 녹음 대본에도 펼쳐진다(안 넣으면 export 테스트가 실패한다).

## 기기 음성(TTS) 규칙

| | 앱(iOS·Android, flutter_tts) | 웹(speechSynthesis) |
|---|---|---|
| 음성 고르기 | 한국어 음성 중 `voiceScore` 최고 | 기기 내 음성(localService) 먼저 → `voiceScore` → ko-KR 정확 일치 |
| 속도 | 0.44 (0.5가 보통) | 0.9 (1.0이 보통) |
| 음높이 | 1.0 | 1.0 |
| 끝 기다리기 | `awaitSpeakCompletion(true)` + 완료·오류 알림 + 안전 시간 | onend·onerror + 안전 시간 |

`voiceScore`(알록달록과 같음): SunHi(엣지) > Google 한국의(크롬) > Yuna(iOS·macOS) > ko-kr-x-ism/kob(Android 구글 여성)
> Heami > female·Sora·Jimin·Seoyeon > natural/neural(20) > 기타(0) > 남성(InJoon, Hyunsu, Bongjin, Gookmin,
ko-kr-x-koc/kod, male: -10).
**음높이는 올리지 않는다** — TTS 음높이를 올리면 기계음이 일그러져 아이에게 무섭게 들린다(알록달록의 교훈).
웹에서 기기 내 음성을 먼저 고르는 것은 원격 음성(크롬 "Google 한국의", 엣지 "Online")이 문장을 서버로 보내기 때문이다.

flutter_tts iOS는 `stop()` 때 speak 완료를 알리지 않는다. 그래서 취소 알림은 무시하고(늦게 온 앞 문장의 취소가
다음 문장을 끝내지 않게) 자체 완료 신호·안전 시간으로 돌아온다.

## 오디오 세션 (목소리 ↔ 마이크)

진행 순서는 "말하기 → 듣기 → 말하기"로 겹치지 않는다(`NameStageController`). 그래도 세션이 바뀌며 소리가 작아지거나
듣기가 실패하지 않도록 다음처럼 정했다.

### 앱 (iOS)
- **모든 소리가 같은 범주**: `playAndRecord` + `defaultToSpeaker` + `allowBluetooth` + `allowBluetoothA2DP` + `mixWithOthers`.
  - audioplayers: `AudioPlayer.global.setAudioContext(appAudioContext)` (iOS는 전역 하나뿐).
  - flutter_tts: `setSharedInstance(true)` + 같은 범주.
  - speech_to_text 7.5.0(소스 확인): 듣기 시작 때 지금 범주를 기억 → `playAndRecord`+같은 옵션으로 설정 → 끝나면
    기억한 범주로 되돌리고 `setActive(false)`. 우리 범주와 같으므로 듣기 전후로 범주가 실제로 바뀌지 않는다.
  - `defaultToSpeaker`가 없으면 playAndRecord에서 소리가 수화기로 가서 듣기 후 소리가 작아진다(그래서 필수).
- audioplayers(darwin 6.5)는 재생이 모두 끝나면 `setActive(false)`를 부른다. 듣는 중에 효과음이 끝나면 iOS가
  "사용 중"으로 거절하고 로그만 남는다(녹음은 계속돼야 함 — 실기기 확인).
- 무음 스위치: playAndRecord는 무음 스위치를 무시한다(소리가 난다).

### 앱 (Android)
- 오디오 포커스를 요청하지 않는다(`AndroidAudioFocus.none`). 목소리·효과음이 서로를 멈추지 않고, 음성 인식 서비스와 다투지 않는다.

### 웹
- Web Audio(AudioContext)로 녹음·효과음을 튼다. 첫 터치(캡처 단계 `pointerdown/touchend/keydown/click`)에서
  잠금 해제 + 1샘플 무음 재생(iOS). 매니페스트의 녹음은 시작하자마자 6개씩 미리 받아 디코드해 둔다.
- 잠금이 안 풀렸으면(제스처 전) 녹음 대신 TTS로 넘어간다(`web/index.html`이 첫 탭에서 TTS도 풀어 둔다).
- **`navigator.audioSession.type`은 설정하지 않는다(기본 'auto').** 알록달록은 무음 스위치를 무시하려고 `'playback'`으로
  바꿨지만, `'playback'`은 재생 전용 세션이라 같은 페이지의 마이크 캡처(getUserMedia·음성 인식)와 맞지 않는다.
  듣기 전후로 타입을 바꾸는 방법도 경로 전환·끊김 위험이 있어 택하지 않았다. 'auto'면 마이크를 쓰는 동안 브라우저가
  알아서 play-and-record로 올린다. 대가: 아이폰 무음 스위치가 켜져 있으면 마이크를 쓰기 전 Web Audio 소리가 안 날 수 있다.
  웹은 내부 테스트용이라 이 대가를 받아들였다.

### 실기기에서만 확인할 수 있는 항목
iOS 시뮬레이터는 이 Mac에서 마이크 입력이 없어 듣기를 확인할 수 없다. 출시 전 실기기(iPhone/iPad, Android)에서:
1. 녹음 재생 → 바로 듣기: 인식이 정상 시작되는가(`error_listen_failed` 없음).
2. 듣기 → 바로 녹음 재생: 소리가 스피커로 크게 나오는가(수화기로 작게 나오지 않는가).
3. 듣는 중 효과음(탭 등)이 끝날 때 녹음이 끊기지 않는가(audioplayers의 `setActive(false)` 거절 로그만 나야 함).
4. 블루투스 이어폰 연결 시 재생·듣기 모두 되는가.
5. 무음 스위치 켬: 앱은 소리가 나야 한다. 웹(사파리)은 첫 문장이 안 들릴 수 있음(위 결정).
6. TTS 대체(녹음 없는 문장)가 녹음과 이어서 자연스러운가, iOS에서 Yuna가 골라지는가.
7. 아이폰 사파리: 첫 탭 뒤 녹음이 나오는가, 음성 인식 후에도 녹음·효과음이 계속 나오는가.
8. Android: 음성 인식 시작음/종료음이 목소리와 겹치지 않는가.

## 효과음

| 이름(`SfxNames`/`Sfx`) | 소리 | 들리는 크기 |
|---|---|---|
| correct | 정답 "뾰로롱" 도-미-솔 실로폰 | -18 LUFS(M) |
| try_again | "음~ 다시?" 내려갔다 올라감(버저·단조 아님) | -21 |
| tap | 비눗방울 "뽁"(가장 작게) | -25 |
| fanfare | 한 판 완료 실로폰 노래 + 화음 | -18 |
| stamp | 도장 "쾅·퐁" | -21 |
| unlock | (voicedex 새 소리) 반짝이며 올라간 뒤 도-미-솔 종소리 | -19 |
| coin, buy, poke | 알록달록 소리(지금 화면에서는 안 씀) | -19/-19/-21 |

`python3 tools/generate_sfx.py`(numpy·scipy, 예: `~/alokdev/melo-venv/bin/python tools/generate_sfx.py`)로 다시 만든다.
알록달록과 같은 8개는 같은 생성기로 만들어 원본과 바이트까지 같다. 모르는 이름은 조용히 넘어간다. 재생 볼륨은 0.8배.
목소리(-16 LUFS)보다 작게 맞춰 두었다.

## 라이선스

- **MeloTTS**(myshell-ai, MIT, © 2024 MyShell.ai): 생성한 음성 파일에는 별도 조건이 없다. 앱에 모델·코드를 넣지 않는다
  (녹음 파일만 들어간다). MIT 고지는 생성 도구에 대한 것이므로 앱 고지 의무는 없지만, 오픈소스 고지 화면을 만들면 함께 적어도 된다.
- **Praat/parselmouth**(GPL): 개발 PC에서 음성 가공에만 쓰는 도구다. 결과 음성에는 조건이 없고 앱에 포함되지 않는다.
- **효과음**: 외부 음원 없이 numpy로 직접 합성(같은 제작자의 알록달록 생성기). 저작권 문제 없음.
- **audioplayers**(MIT), **flutter_tts**(MIT): 앱에 포함되는 패키지.

## 용량

| | 개수 | 용량 |
|---|---|---|
| 녹음(assets/voice) | 81문장(2026-11-12 기준) | 약 1.1 MB (문장당 평균 13 KB, 총 길이 약 213초) |
| 효과음(assets/audio/sfx) | 9개 wav | 약 308 KB |

종 하나를 더하면 종별 대사(지금 6개 틀) × 1종 ≈ 6문장 ≈ 80 KB 늘어난다.
