import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../content/species.dart';
import '../../platform/web_audio.dart';
import '../voice/audio_session.dart';
import 'sound_effects.dart';

/// 효과음 재생.
///
/// - 앱: audioplayers. 소리마다 플레이어를 따로 두어(목소리 플레이어와도 별개) 서로 끊지 않는다.
///   오디오 포커스·세션은 audio_session.dart(포커스 요청 없음, iOS mixWithOthers).
/// - 웹: Web Audio(목소리와 같은 AudioContext, 다른 gain) — 사파리 자동 재생 제한을 함께 푼다.
/// - 크기: 파일 자체가 -18~-25 LUFS(목소리 -16보다 작게)로 맞춰져 있고, 여기서 [volume]을 한 번 더 곱한다.
class AudioSoundEffects implements SoundEffects {
  AudioSoundEffects({this.volume = 0.8});

  final double volume;
  final Map<Sfx, AudioPlayer> _players = {};
  bool enabled = true;

  Future<void> initialize() async {
    if (kIsWeb) {
      final engine = WebAudioEngine.instance..init();
      unawaited(engine.preload([for (final s in Sfx.values) s.asset]));
      return;
    }
    await applyAppAudioContext();
  }

  @override
  Future<bool> playCorrect(Species species) async => false;

  @override
  Future<void> play(String name) async {
    if (!enabled) return;
    final sfx = Sfx.byFile(name);
    if (sfx == null) {
      debugPrint('[sfx] unknown sound "$name"');
      return;
    }
    try {
      if (kIsWeb) {
        await WebAudioEngine.instance.playSfx(sfx.asset, volume: volume);
        return;
      }
      final p = _players[sfx] ??= AudioPlayer(playerId: 'sfx_${sfx.file}');
      await p.stop();
      await p.setReleaseMode(ReleaseMode.stop);
      // AssetSource는 'assets/' 아래 경로를 받는다.
      await p.play(AssetSource('audio/sfx/${sfx.file}.wav'), volume: volume);
    } catch (e) {
      debugPrint('[sfx] ${sfx.file}: $e');
    }
  }
}
