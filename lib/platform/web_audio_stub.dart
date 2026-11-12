/// 마이크 권한 요청 결과.
enum MicPermission { granted, denied, unknown }

/// 브라우저에 음성 인식(Web Speech API)이 있는가. 웹이 아니면 false.
bool get webSpeechRecognitionSupported => false;

/// 브라우저에 음성 합성(speechSynthesis)이 있는가. 웹이 아니면 false.
bool get webSpeechSynthesisSupported => false;

/// 마이크 권한을 미리 요청한다(웹 전용). 웹이 아니면 [MicPermission.unknown].
Future<MicPermission> requestWebMicrophone() async => MicPermission.unknown;

/// 웹 전용 소리 엔진(Web Audio). 앱(iOS·Android)에서는 audioplayers를 쓰므로 아무것도 하지 않는다.
class WebAudioEngine {
  WebAudioEngine._();
  static final WebAudioEngine instance = WebAudioEngine._();

  bool get supported => false;
  bool get unlocked => false;
  void init() {}
  Future<void> preload(List<String> assetKeys) async {}
  Future<bool> playVoice(String assetKey) async => false;
  void stopVoice() {}
  Future<void> playSfx(String assetKey, {double volume = 1}) async {}
}
