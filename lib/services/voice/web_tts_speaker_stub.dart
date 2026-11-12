import 'voice_engines.dart';

/// 웹 전용(웹 구현은 `web_tts_speaker_web.dart`). 다른 플랫폼에서 만들면 예외.
class WebTtsSpeaker implements TextSpeaker {
  WebTtsSpeaker({String locale = 'ko-KR'}) {
    throw UnsupportedError('WebTtsSpeaker is web only');
  }

  @override
  String get debugDescription => 'web tts (unsupported)';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
