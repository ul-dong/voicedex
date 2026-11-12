import 'package:flutter/foundation.dart';

import '../content/content_repository.dart';
import '../content/world_catalog.dart';
import '../services/sfx/sound_effects.dart';
import '../services/speech/device_speech_input.dart';
import '../services/speech/fake_speech_input.dart';
import '../services/speech/speech_input.dart';
import '../services/voice/tts_voice_output.dart';
import '../services/voice/voice_lines.dart';
import '../services/voice/voice_output.dart';
import '../services/voice/web_voice_output.dart';
import 'app_config.dart';

/// 앱 전역 서비스 묶음.
class AppServices {
  AppServices({
    required this.content,
    required this.voice,
    required this.speech,
    required this.sfx,
  });

  final ContentRepository content;
  final VoiceOutput voice;
  final SpeechInput speech;
  final SoundEffects sfx;

  bool _speechReady = false;
  bool get speechReady => _speechReady;

  static Future<AppServices> create() async {
    final content = ContentRepository();
    final lines = await VoiceLines.load();
    final animals = await content.load(WorldCatalog.animals);
    final SpeechInput speech;
    if (AppConfig.useFakeSpeech) {
      debugPrint('[app] using FakeSpeechInput script=${AppConfig.fakeScript}');
      speech = FakeSpeechInput(script: AppConfig.fakeScript);
    } else {
      speech = DeviceSpeechInput(
        localeId: AppConfig.speechLocaleForPlatform,
        onDeviceOnly: AppConfig.onDeviceRecognitionOnly,
        contextualPhrases: animals.species.map((s) => s.name).toList(),
      );
    }
    // 웹은 flutter_tts 웹 구현 대신 speechSynthesis를 직접 쓴다
    // (flutter_tts 웹은 속도 단위가 다르고, 오류·중단 때 speak 완료를 알리지 않아 멈출 수 있다).
    final VoiceOutput voice = kIsWeb
        ? WebVoiceOutput(lines)
        : TtsVoiceOutput(lines);
    try {
      await voice.initialize();
    } catch (e) {
      debugPrint('[app] tts init failed: $e');
    }
    return AppServices(
      content: content,
      voice: voice,
      speech: speech,
      sfx: const NoSoundEffects(),
    );
  }

  /// 첫 놀이 시작 때 한 번: 마이크·음성 인식 권한 요청.
  Future<bool> ensureSpeech() async {
    if (_speechReady) return true;
    _speechReady = await speech.initialize();
    return _speechReady;
  }
}
