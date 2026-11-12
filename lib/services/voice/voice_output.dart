import 'voice_line.dart';

/// 안내 음성 출력. 지금은 TTS 구현([TtsVoiceOutput])을 쓰고,
/// 녹음 파일이 준비되면 같은 인터페이스로 녹음 재생 구현을 만들어 바꿔 끼운다.
abstract class VoiceOutput {
  Future<void> initialize();

  /// 대사를 끝까지 말하고 돌아온다. [stop]이 불리면 바로 돌아온다.
  Future<void> say(VoiceLine line);

  Future<void> stop();
}
