import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../platform/web_audio.dart';
import 'voice_choice.dart';
import 'voice_engines.dart';

/// 브라우저 speechSynthesis로 말한다(녹음이 없는 문장의 대체).
///
/// - 끝(onend)·오류/중단(onerror)·안전 시간([speakGuard]) 중 먼저 오는 것에서 돌아온다
///   (사파리는 가끔 둘 다 알리지 않는다. 사용자 제스처 전 차단도 마찬가지).
/// - iOS 사파리는 사용자 제스처 안에서 한 번 말해야 소리가 풀린다 → `web/index.html`이 첫 탭에서 빈 문장을 말한다.
/// - 음성 고르기: 기기 내 음성(localService) 먼저 — 크롬 "Google 한국의"·엣지 "Online" 같은 원격 음성은
///   문장을 서버로 보낸다. 같은 조건이면 [voiceScore](여성·neural 우선, 남성 회피), 그다음 ko-KR 정확 일치.
/// - flutter_tts 웹 대신 직접 쓴다(flutter_tts 웹은 속도 단위가 다르고 중단·오류 때 완료를 알리지 않는다).
class WebTtsSpeaker implements TextSpeaker {
  WebTtsSpeaker({this.locale = 'ko-KR'});

  final String locale;

  web.SpeechSynthesisVoice? _voice;
  // 크롬은 말하는 중인 utterance가 GC되면 onend가 오지 않는다 → 참조를 붙잡아 둔다.
  web.SpeechSynthesisUtterance? _current;
  Completer<void>? _done;
  Timer? _guard;

  bool get _supported => webSpeechSynthesisSupported;
  web.SpeechSynthesis get _synth => web.window.speechSynthesis;
  String get _lang => locale.replaceAll('_', '-');

  @override
  String get debugDescription =>
      'web speechSynthesis(${_voice?.name ?? 'default'}, '
      'local=${_voice?.localService})';

  @override
  Future<void> initialize() async {
    if (!_supported) {
      debugPrint('[voice] web: speechSynthesis not supported');
      return;
    }
    _pickVoice();
    // 크롬은 음성 목록을 비동기로 채운다.
    _synth.addEventListener(
      'voiceschanged',
      ((web.Event _) => _pickVoice()).toJS,
    );
  }

  void _pickVoice() {
    final want = _lang.toLowerCase();
    final prefix = want.split('-').first;
    String norm(web.SpeechSynthesisVoice v) =>
        v.lang.toLowerCase().replaceAll('_', '-');
    final ko = _synth
        .getVoices()
        .toDart
        .where((v) => norm(v).startsWith(prefix))
        .toList();
    if (ko.isEmpty) return;
    int score(web.SpeechSynthesisVoice v) =>
        (v.localService ? 10000 : 0) +
        voiceScore(v.name) * 10 +
        (norm(v) == want ? 1 : 0);
    ko.sort((a, b) => score(b) - score(a));
    if (_voice?.name != ko.first.name) {
      _voice = ko.first;
      debugPrint(
        '[voice] web voice: ${ko.first.name} (${ko.first.lang}, '
        'local=${ko.first.localService}) of ${ko.length}',
      );
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_supported || text.trim().isEmpty) return;
    await stop();
    if (_voice == null) _pickVoice();
    final tone = ttsTone(web: true);
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = _voice?.lang ?? _lang
      ..rate = tone.rate
      ..pitch = tone.pitch
      ..volume = 1;
    final v = _voice;
    if (v != null) u.voice = v;

    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    u.onend = ((web.Event _) => finish()).toJS;
    u.onerror = ((web.SpeechSynthesisErrorEvent e) {
      debugPrint('[voice] web speak error: ${e.error}');
      finish();
    }).toJS;

    _current = u;
    _done = done;
    _guard = Timer(speakGuard(text), () {
      debugPrint('[voice] web speak guard timeout');
      finish();
    });
    _synth.speak(u);
    await done.future;
    if (identical(_current, u)) {
      _guard?.cancel();
      _current = null;
      _done = null;
    }
  }

  @override
  Future<void> stop() async {
    _guard?.cancel();
    final d = _done;
    _done = null;
    _current = null;
    if (_supported && (_synth.speaking || _synth.pending)) _synth.cancel();
    if (d != null && !d.isCompleted) d.complete();
  }
}
