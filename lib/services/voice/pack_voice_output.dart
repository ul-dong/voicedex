import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_engines.dart';
import 'voice_line.dart';
import 'voice_lines.dart';
import 'voice_output.dart';
import 'voice_pack.dart';

/// 어디서 소리가 났는지(테스트·개발자 표시용).
enum VoiceSource { pack, tts, none }

/// 녹음 팩 우선 + 없으면 TTS 대체.
///
/// - 대사를 문장으로 바꾼 뒤 **문장 그대로** 매니페스트에서 녹음을 찾는다(통문장 단위, 이어 붙이기 없음).
/// - 녹음이 없거나 재생에 실패하면 같은 문장을 TTS로 말한다.
/// - 끼어들기: 말하는 중에 새 [say]나 [stop]이 오면 앞의 말은 바로 멈추고 앞의 [say]도 바로 돌아온다
///   (번호표 [_token]로 구별해, 늦게 끝난 앞의 재생이 뒤의 말을 건드리지 않는다).
class PackVoiceOutput implements VoiceOutput {
  PackVoiceOutput({
    required this.lines,
    required this.pack,
    required this.clips,
    required this.tts,
  });

  final VoiceLines lines;
  final VoicePack pack;
  final ClipPlayer clips;
  final TextSpeaker tts;

  int _token = 0;
  Completer<void>? _interrupt;

  VoiceSource _lastSource = VoiceSource.none;
  VoiceSource get lastSource => _lastSource;

  @override
  Future<void> initialize() async {
    await Future.wait([
      _safe('clips init', clips.initialize),
      _safe('tts init', tts.initialize),
    ]);
    debugPrint(
      '[voice] pack ${pack.length} sentences, tts ${tts.debugDescription}',
    );
  }

  @override
  Future<void> say(VoiceLine line) async {
    final text = lines.render(line);
    final token = ++_token;
    _signalInterrupt();
    final interrupt = _interrupt = Completer<void>();
    await _stopEngines();
    if (token != _token) return;

    final file = pack.lookup(text);
    debugPrint('[voice] say ${line.key}: $text (${file ?? 'tts'})');
    if (file != null) {
      _lastSource = VoiceSource.pack;
      final ok = await Future.any<bool>([
        clips.play(file).catchError((Object e) {
          debugPrint('[voice] clip $file failed: $e');
          return false;
        }),
        interrupt.future.then((_) => true),
      ]);
      if (ok || token != _token) return;
      debugPrint('[voice] clip $file not played -> tts');
    }
    _lastSource = VoiceSource.tts;
    await Future.any<void>([
      tts.speak(text).catchError((Object e) {
        debugPrint('[voice] tts failed: $e');
      }),
      interrupt.future,
    ]);
  }

  @override
  Future<void> stop() async {
    _token++;
    _signalInterrupt();
    await _stopEngines();
  }

  void _signalInterrupt() {
    final c = _interrupt;
    _interrupt = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> _stopEngines() => Future.wait([
    _safe('clips stop', clips.stop),
    _safe('tts stop', tts.stop),
  ]);

  static Future<void> _safe(String what, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('[voice] $what: $e');
    }
  }
}
