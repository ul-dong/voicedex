import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../platform/web_audio.dart';
import 'audio_session.dart';
import 'voice_engines.dart';
import 'voice_pack.dart';

/// 앱(iOS·Android): audioplayers로 녹음 MP3를 튼다. 플레이어 하나를 돌려 쓴다.
class AudioplayersClipPlayer implements ClipPlayer {
  AudioplayersClipPlayer();

  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  Completer<bool>? _done;
  Timer? _guard;

  @override
  Future<void> initialize() async {
    await applyAppAudioContext();
    final p = _player = AudioPlayer(playerId: 'voice');
    await p.setReleaseMode(ReleaseMode.stop);
    _completeSub = p.onPlayerComplete.listen((_) => _finish(true));
  }

  void _finish(bool ok) {
    _guard?.cancel();
    _guard = null;
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete(ok);
  }

  @override
  Future<bool> play(String file) async {
    final p = _player;
    if (p == null) return false;
    _finish(true);
    final done = _done = Completer<bool>();
    try {
      // AssetSource는 'assets/' 아래 경로를 받는다.
      await p.play(AssetSource('voice/$file'), volume: 1.0);
    } catch (e) {
      debugPrint('[voice] clip play $file: $e');
      if (identical(_done, done)) _finish(false);
      return done.future;
    }
    if (!identical(_done, done)) return done.future; // 그 사이 멈춤
    // 끝 알림이 오지 않는 경우를 대비한 안전 시간(길이 + 여유, 길이를 모르면 15초)
    Duration? d;
    try {
      d = await p.getDuration();
    } catch (_) {}
    if (identical(_done, done) && !done.isCompleted) {
      _guard = Timer(
        (d ?? const Duration(seconds: 14)) + const Duration(seconds: 1),
        () {
          debugPrint('[voice] clip guard timeout $file');
          _finish(true);
        },
      );
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    _finish(true);
    final p = _player;
    if (p != null && p.state == PlayerState.playing) await p.stop();
  }

  Future<void> dispose() async {
    await _completeSub?.cancel();
    await _player?.dispose();
  }
}

/// 웹: Web Audio(AudioContext)로 녹음을 튼다(lib/platform/web_audio_web.dart).
/// 첫 터치로 잠금이 풀리지 않았으면 false → TTS로 대신 말한다.
class WebAudioClipPlayer implements ClipPlayer {
  WebAudioClipPlayer(this._pack);

  final VoicePack _pack;
  WebAudioEngine get _engine => WebAudioEngine.instance;

  @override
  Future<void> initialize() async {
    _engine.init();
    if (!_pack.isEmpty) {
      // 놀이를 시작하기 전에 녹음을 조금씩 미리 받아 둔다.
      unawaited(
        _engine.preload(_pack.files.map(VoicePack.assetKey).toList()),
      );
    }
  }

  @override
  Future<bool> play(String file) => _engine.playVoice(VoicePack.assetKey(file));

  @override
  Future<void> stop() async => _engine.stopVoice();
}
