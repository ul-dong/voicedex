/// 녹음 재생기·TTS 엔진 인터페이스. [PackVoiceOutput]이 둘을 묶는다(테스트에서는 가짜로 바꾼다).
library;

/// 녹음 파일 하나를 끝까지 튼다.
abstract class ClipPlayer {
  Future<void> initialize();

  /// [file](`assets/voice/` 안의 파일 이름)을 끝까지 틀고 true.
  /// 파일이 없거나 재생할 수 없으면 false(→ TTS로 대신 말한다). [stop]되면 바로 true로 돌아온다.
  Future<bool> play(String file);

  Future<void> stop();
}

/// 문장을 기기 음성으로 말한다.
abstract class TextSpeaker {
  Future<void> initialize();

  /// 끝까지 말하고 돌아온다(끝·오류·안전 시간 중 먼저 오는 것). [stop]되면 바로 돌아온다.
  Future<void> speak(String text);

  Future<void> stop();

  /// 개발자 표시용(고른 음성 이름 등).
  String get debugDescription;
}
