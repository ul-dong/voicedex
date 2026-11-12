import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_choice.dart';
import 'voice_engines.dart';

/// 앱(iOS·Android) 기기 TTS. 기기 내장 엔진이며 앱이 네트워크로 보내는 것은 없다.
///
/// - 한국어 음성 중 [voiceScore]가 가장 높은 것(여성·neural 우선, 남성 회피).
/// - 속도 0.44, 음높이 1.0(올리지 않음), `awaitSpeakCompletion(true)`.
/// - [speak]는 끝·취소·오류 알림 또는 안전 시간 중 먼저 오는 것에서 돌아온다
///   (flutter_tts iOS는 취소 때 speak 완료를 알리지 않아, speak 결과만 기다리면 멈출 수 있다).
class FlutterTtsSpeaker implements TextSpeaker {
  FlutterTtsSpeaker({FlutterTts? tts, this.locale = 'ko-KR'})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final String locale;
  String? _voiceName;
  Completer<void>? _done;
  Timer? _guard;

  @override
  String get debugDescription => 'flutter_tts(${_voiceName ?? 'default'})';

  @override
  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      // 음성 인식·녹음 재생과 같은 범주(audio_session.dart). 듣기 후에도 스피커로 크게 나온다.
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    await _tts.setLanguage(locale);
    await _pickVoice();
    final tone = ttsTone(web: false);
    await _tts.setSpeechRate(tone.rate);
    await _tts.setPitch(tone.pitch);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(_finish);
    // 취소 알림은 [stop]이 부른 것이므로(이미 _finish 됨) 무시한다. 늦게 도착한 앞 문장의 취소
    // 알림이 다음 문장을 끝내 버리지 않게. 시스템이 끊은 경우는 안전 시간이 맡는다.
    _tts.setErrorHandler((msg) {
      debugPrint('[voice] tts error: $msg');
      _finish();
    });
  }

  Future<void> _pickVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final prefix = locale.split(RegExp('[-_]')).first.toLowerCase();
      final voices = [
        for (final v in raw)
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
      ].where((v) => (v['locale'] ?? '').toLowerCase().startsWith(prefix));
      final sorted = voices.toList()
        ..sort(
          (a, b) => voiceScore(b['name'] ?? '')
              .compareTo(voiceScore(a['name'] ?? '')),
        );
      if (sorted.isEmpty) return;
      final best = sorted.first;
      await _tts.setVoice({'name': best['name']!, 'locale': best['locale']!});
      _voiceName = best['name'];
      debugPrint('[voice] tts voice: $_voiceName of ${sorted.length}');
    } catch (e) {
      debugPrint('[voice] tts voice pick: $e');
    }
  }

  void _finish() {
    _guard?.cancel();
    _guard = null;
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _finish();
    final done = _done = Completer<void>();
    _guard = Timer(speakGuard(text), () {
      debugPrint('[voice] tts guard timeout');
      _finish();
    });
    unawaited(
      _tts.speak(text).then((_) {
        if (identical(_done, done)) _finish();
      }, onError: (Object e) {
        debugPrint('[voice] tts speak: $e');
        if (identical(_done, done)) _finish();
      }),
    );
    await done.future;
  }

  @override
  Future<void> stop() async {
    final speaking = _done != null;
    _finish();
    if (speaking) await _tts.stop();
  }
}
