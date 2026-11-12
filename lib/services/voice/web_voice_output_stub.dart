import 'voice_line.dart';
import 'voice_lines.dart';
import 'voice_output.dart';

/// 웹 전용([WebVoiceOutput]의 웹 구현은 `web_voice_output_web.dart`). 다른 플랫폼에서 만들면 예외.
class WebVoiceOutput implements VoiceOutput {
  WebVoiceOutput(VoiceLines lines) {
    throw UnsupportedError('WebVoiceOutput is web only');
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> say(VoiceLine line) async {}

  @override
  Future<void> stop() async {}
}
