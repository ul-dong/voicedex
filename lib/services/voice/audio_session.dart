import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 앱(iOS·Android) 오디오 세션 설정. 녹음 목소리·효과음(audioplayers)·TTS(flutter_tts)·음성 인식
/// (speech_to_text)이 **같은 iOS 범주**를 쓰게 해서, 듣기 전후로 범주가 바뀌며 소리가 작아지거나
/// 듣기가 실패하는 일이 없게 한다.
///
/// - iOS: `playAndRecord` + `defaultToSpeaker`(수화기 대신 스피커) + `allowBluetooth(A2DP)` +
///   `mixWithOthers`. speech_to_text 7.5.0은 듣기 시작 때 지금 범주를 기억했다가 같은 범주
///   (playAndRecord + 같은 옵션)로 바꾸고, 끝나면 기억한 범주로 되돌린다 → 우리 범주와 같으므로
///   실제로는 아무것도 바뀌지 않는다. flutter_tts도 같은 범주로 맞춘다(FlutterTtsSpeaker).
///   audioplayers(darwin 6.5)는 재생이 모두 끝나면 `setActive(false)`를 부르는데, 듣는 중이면 iOS가
///   "사용 중"으로 거절할 뿐 녹음은 계속된다(실기기 확인 항목, docs/VOICE.md).
/// - Android: 오디오 포커스를 요청하지 않는다(`none`). 목소리와 효과음이 서로를 멈추지 않고,
///   음성 인식기(별도 서비스)와도 다투지 않는다.
/// - 웹: 해당 없음(Web Audio, lib/platform/web_audio_web.dart).
final AudioContext appAudioContext = AudioContext(
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playAndRecord,
    options: const {
      AVAudioSessionOptions.defaultToSpeaker,
      AVAudioSessionOptions.allowBluetooth,
      AVAudioSessionOptions.allowBluetoothA2DP,
      AVAudioSessionOptions.mixWithOthers,
    },
  ),
  android: const AudioContextAndroid(
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.none,
  ),
);

bool _applied = false;

/// 앱 전체에 한 번 적용한다(웹은 아무것도 하지 않는다).
Future<void> applyAppAudioContext() async {
  if (kIsWeb || _applied) return;
  _applied = true;
  try {
    await AudioPlayer.global.setAudioContext(appAudioContext);
  } catch (e) {
    debugPrint('[audio] setAudioContext failed: $e');
  }
}
