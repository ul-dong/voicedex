import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_line.dart';
import 'voice_lines.dart';
import 'voice_output.dart';

/// 기기 TTS(ko-KR)로 대사를 말한다. 기기 내장 음성 엔진을 쓰며 앱이 네트워크로 보내는 것은 없다.
class TtsVoiceOutput implements VoiceOutput {
  TtsVoiceOutput(this._lines, {FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final VoiceLines _lines;
  final FlutterTts _tts;

  @override
  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(true);
    if (!kIsWeb && Platform.isIOS) {
      await _tts.setSharedInstance(true);
      // 음성 인식(playAndRecord)과 같은 범주를 써서, 듣기 후에도 스피커로 크게 나오게 한다.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    await _tts.setLanguage(_lines.locale);
    // flutter_tts 기준 0.5가 보통 속도(iOS·Android 공통). 아이용으로 조금 느리게.
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.1);
    await _tts.setVolume(1.0);
  }

  @override
  Future<void> say(VoiceLine line) async {
    final text = _lines.render(line);
    debugPrint('[voice] say ${line.key}: $text');
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
