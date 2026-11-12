import 'package:flutter/foundation.dart';

import '../content/content_repository.dart';
import '../content/world_catalog.dart';
import '../progress/progress_store.dart';
import '../services/sfx/audio_sound_effects.dart';
import '../services/sfx/sound_effects.dart';
import '../services/speech/device_speech_input.dart';
import '../services/speech/fake_speech_input.dart';
import '../services/speech/speech_input.dart';
import '../services/voice/create_voice_output.dart';
import '../services/voice/voice_lines.dart';
import '../services/voice/voice_output.dart';
import 'app_config.dart';

/// 앱 전역 서비스 묶음.
class AppServices {
  AppServices({
    required this.content,
    required this.voice,
    required this.speech,
    required this.sfx,
    required this.progress,
  });

  final ContentRepository content;
  final VoiceOutput voice;
  final SpeechInput speech;
  final SoundEffects sfx;

  /// 도감 진행(기기 로컬 저장).
  final ProgressController progress;

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
    // 녹음 팩 우선 + 없으면 TTS (lib/services/voice/create_voice_output.dart).
    final VoiceOutput voice = await createVoiceOutput(lines);
    try {
      await voice.initialize();
    } catch (e) {
      debugPrint('[app] tts init failed: $e');
    }
    // 효과음(assets/audio/sfx/, 목소리를 끊지 않게 따로 재생).
    final sfx = AudioSoundEffects();
    try {
      await sfx.initialize();
    } catch (e) {
      debugPrint('[app] sfx init failed: $e');
    }
    final progress = await ProgressController.open(SharedPrefsProgressStore());
    await AppConfig.applyDebugDexPreset(progress, animals.species);
    return AppServices(
      content: content,
      voice: voice,
      speech: speech,
      sfx: sfx,
      progress: progress,
    );
  }

  /// 첫 놀이 시작 때 한 번: 마이크·음성 인식 권한 요청.
  Future<bool> ensureSpeech() async {
    if (_speechReady) return true;
    _speechReady = await speech.initialize();
    return _speechReady;
  }
}
