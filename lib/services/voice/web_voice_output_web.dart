import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../platform/web_audio.dart';
import 'voice_line.dart';
import 'voice_lines.dart';
import 'voice_output.dart';

/// 브라우저 speechSynthesis(ko-KR)로 대사를 말한다.
///
/// - 말이 끝나거나(onend) 오류·중단(onerror)이면 [say]가 돌아온다. 브라우저가 어느 쪽도 알리지 않는
///   경우(사파리에서 가끔, 사용자 제스처 전 차단)를 대비해 문장 길이에 비례한 안전 시간 뒤에도 돌아온다.
/// - iOS 사파리는 사용자 제스처 안에서 한 번 말해야 소리가 풀린다 → `web/index.html`이 첫 탭에서
///   빈 문장을 말해 둔다(재생 버튼 탭이 그 첫 탭이 된다).
/// - 크롬의 "Google 한국의" 같은 원격 음성은 문장을 Google로 보내므로 기기 내 음성(localService)을 우선한다.
class WebVoiceOutput implements VoiceOutput {
  WebVoiceOutput(this._lines, {this.rate = 0.9, this.pitch = 1.1});

  final VoiceLines _lines;

  /// 웹 단위(1.0이 보통 속도). 아이용으로 조금 느리게.
  final double rate;
  final double pitch;

  web.SpeechSynthesisVoice? _voice;
  // 크롬은 말하는 중인 utterance가 GC되면 onend가 오지 않는다 → 참조를 붙잡아 둔다.
  web.SpeechSynthesisUtterance? _current;
  Completer<void>? _done;
  Timer? _guard;

  bool get _supported => webSpeechSynthesisSupported;
  web.SpeechSynthesis get _synth => web.window.speechSynthesis;

  String get _lang => _lines.locale.replaceAll('_', '-');

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
    final voices = _synth.getVoices().toDart;
    final ko = voices
        .where(
          (v) => v.lang.toLowerCase().replaceAll('_', '-').startsWith(prefix),
        )
        .toList();
    if (ko.isEmpty) return;
    ko.sort((a, b) {
      int score(web.SpeechSynthesisVoice v) =>
          (v.localService ? 2 : 0) +
          (v.lang.toLowerCase().replaceAll('_', '-') == want ? 1 : 0);
      return score(b) - score(a);
    });
    if (_voice?.name != ko.first.name) {
      _voice = ko.first;
      debugPrint(
        '[voice] web voice: ${ko.first.name} (${ko.first.lang}, '
        'local=${ko.first.localService}) of ${ko.length}',
      );
    }
  }

  @override
  Future<void> say(VoiceLine line) async {
    final text = _lines.render(line);
    debugPrint('[voice] say ${line.key}: $text');
    if (!_supported || text.trim().isEmpty) return;
    await stop();
    if (_voice == null) _pickVoice();

    final u = web.SpeechSynthesisUtterance(text)
      ..lang = _voice?.lang ?? _lang
      ..rate = rate
      ..pitch = pitch
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
    _guard = Timer(Duration(milliseconds: 3000 + 250 * text.length), () {
      debugPrint('[voice] web speak guard timeout');
      finish();
    });
    _synth.speak(u);
    await done.future;
    _guard?.cancel();
    if (identical(_current, u)) {
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
