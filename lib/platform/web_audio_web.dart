import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_audio_stub.dart' show MicPermission;

export 'web_audio_stub.dart' show MicPermission;

bool get webSpeechRecognitionSupported =>
    web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
    web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

bool get webSpeechSynthesisSupported =>
    web.window.hasProperty('speechSynthesis'.toJS).toDart;

/// 재생 버튼을 누른 그 순간(사용자 제스처 안)에 마이크 권한 창을 띄운다.
/// 허용되면 스트림은 바로 닫는다(녹음하지 않음). 실제 인식은 Web Speech API가 따로 마이크를 연다.
Future<MicPermission> requestWebMicrophone() async {
  try {
    final nav = web.window.navigator;
    if (!nav.hasProperty('mediaDevices'.toJS).toDart) {
      return MicPermission.unknown; // http(비보안 출처) 등
    }
    final stream = await nav.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart
        // 권한 창에 답하지 않거나 창이 뜨지 않는 환경(내장 브라우저 등)에서 시작 화면에 갇히지 않게.
        .timeout(const Duration(seconds: 12));
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
    return MicPermission.granted;
  } on TimeoutException {
    debugPrint('[web] getUserMedia: no answer, continuing');
    return MicPermission.unknown;
  } catch (e) {
    debugPrint('[web] getUserMedia failed: $e');
    final s = e.toString();
    if (s.contains('NotAllowed') ||
        s.contains('Permission') ||
        s.contains('NotFound') ||
        s.contains('denied')) {
      return MicPermission.denied;
    }
    return MicPermission.unknown;
  }
}

/// 웹(특히 아이폰·아이패드 사파리)용 소리 엔진. 알록달록 `web_audio.dart` 방식.
///
/// 사파리는 화면을 누른 직후가 아니면 `<audio>` 재생을 막는다. Web Audio는 첫 터치 한 번으로
/// AudioContext를 "잠금 해제"하면 그 뒤로는 언제든 재생할 수 있다. 녹음 파일은 fetch → decode 해
/// 캐시해 두고 AudioBufferSourceNode로 튼다. 효과음도 같은 엔진(별도 gain)으로 틀어 목소리를 끊지 않는다.
///
/// `navigator.audioSession.type`은 **설정하지 않는다**(기본 'auto'). 알록달록은 'playback'으로 바꿔
/// 무음 스위치를 무시했지만, voicedex는 같은 페이지에서 마이크(음성 인식)를 쓴다. 'playback'은
/// 녹음이 없는 재생 전용 세션이라 마이크 캡처와 맞지 않고(WebKit은 캡처 중이면 'play-and-record'가
/// 필요하다), 듣기 전후로 타입을 바꾸면 경로 전환·끊김이 생길 수 있다. 'auto'는 마이크를 쓰는 동안
/// 브라우저가 알아서 play-and-record로 올린다. 대가: 아이폰 무음 스위치가 켜져 있으면 마이크를
/// 쓰기 전까지 Web Audio 소리가 안 날 수 있다(docs/VOICE.md 실기기 확인 항목).
class WebAudioEngine {
  WebAudioEngine._();
  static final WebAudioEngine instance = WebAudioEngine._();

  web.AudioContext? _ctx;
  web.GainNode? _voiceGain;
  web.GainNode? _sfxGain;
  final Map<String, Future<web.AudioBuffer?>> _cache = {};
  web.AudioBufferSourceNode? _voiceNode;
  Completer<bool>? _voiceDone;
  Timer? _voiceGuard;
  int _token = 0;
  bool _inited = false;
  Future<void>? _resuming;

  bool get supported => true;
  bool get unlocked => _ctx != null && _ctx!.state == 'running';

  /// 첫 터치 때 오디오를 깨우도록 이벤트를 건다(캡처 단계라 Flutter보다 먼저 받는다).
  void init() {
    if (_inited) return;
    _inited = true;
    void unlock(web.Event _) => _unlock();
    for (final type in ['pointerdown', 'touchend', 'keydown', 'click']) {
      web.document.addEventListener(type, unlock.toJS, true.toJS);
    }
  }

  web.AudioContext _context() {
    var ctx = _ctx;
    if (ctx == null) {
      ctx = web.AudioContext();
      _ctx = ctx;
      _voiceGain = ctx.createGain()..connect(ctx.destination);
      _sfxGain = ctx.createGain()..connect(ctx.destination);
    }
    return ctx;
  }

  void _unlock() {
    final ctx = _context();
    if (ctx.state == 'running') return;
    // iOS: 터치 안에서 아주 짧은 무음을 한 번 틀어야 완전히 열린다
    try {
      final silent = ctx.createBuffer(1, 1, 22050);
      final src = ctx.createBufferSource()..buffer = silent;
      src.connect(ctx.destination);
      src.start();
    } catch (_) {}
    _resuming ??= ctx.resume().toDart.then(
      (_) => _resuming = null,
      onError: (_) => _resuming = null,
    );
  }

  /// 지금 바로 소리를 낼 수 있으면 true. 막 깨우는 중이면 잠깐 기다린다.
  Future<bool> _ready() async {
    final ctx = _context();
    if (ctx.state == 'running') return true;
    final r = _resuming;
    if (r != null) {
      try {
        await r.timeout(const Duration(milliseconds: 600));
      } catch (_) {}
    }
    return ctx.state == 'running';
  }

  /// 에셋 키(예: `assets/voice/v0001.mp3`) → 배포 경로(base href 반영).
  static String _url(String assetKey) =>
      ui_web.assetManager.getAssetUrl(assetKey);

  Future<web.AudioBuffer?> _load(String assetKey) =>
      _cache[assetKey] ??= _fetch(assetKey);

  Future<web.AudioBuffer?> _fetch(String assetKey) async {
    try {
      final ctx = _context();
      final res = await web.window.fetch(_url(assetKey).toJS).toDart;
      if (!res.ok) {
        _cache.remove(assetKey);
        return null;
      }
      final bytes = await res.arrayBuffer().toDart;
      return await ctx.decodeAudioData(bytes).toDart;
    } catch (e) {
      debugPrint('[web audio] load $assetKey failed: $e');
      _cache.remove(assetKey);
      return null;
    }
  }

  /// 녹음·효과음을 미리 받아 둔다(조금씩, 놀이를 방해하지 않게). 잠금 해제 전에도 디코드는 된다.
  Future<void> preload(List<String> assetKeys) async {
    for (var i = 0; i < assetKeys.length; i += 6) {
      await Future.wait(assetKeys.skip(i).take(6).map(_load));
    }
  }

  /// 녹음 하나를 끝까지 튼다. 끝나거나 [stopVoice]되면 true.
  /// 파일을 못 불러오거나 소리가 잠겨 있으면 false(→ 호출 쪽이 TTS로 대신 말한다).
  Future<bool> playVoice(String assetKey) async {
    final token = ++_token;
    _stopVoiceNode();
    if (!await _ready()) return false;
    final buf = await _load(assetKey);
    if (token != _token) return true; // 그 사이 다른 말이 시작되거나 멈춤
    if (buf == null) return false;
    final ctx = _context();
    final src = ctx.createBufferSource()..buffer = buf;
    src.connect(_voiceGain!);
    final done = Completer<bool>();
    void finish() {
      if (!done.isCompleted) done.complete(true);
    }

    src.onended = ((web.Event _) => finish()).toJS;
    _voiceNode = src;
    _voiceDone = done;
    // onended가 오지 않는 경우(탭 숨김 등)를 대비한 안전 시간
    _voiceGuard = Timer(
      Duration(milliseconds: (buf.duration * 1000).round() + 800),
      finish,
    );
    src.start();
    final ok = await done.future;
    if (identical(_voiceNode, src)) {
      _voiceGuard?.cancel();
      _voiceNode = null;
      _voiceDone = null;
    }
    return ok;
  }

  void _stopVoiceNode() {
    _voiceGuard?.cancel();
    _voiceGuard = null;
    final n = _voiceNode;
    final d = _voiceDone;
    _voiceNode = null;
    _voiceDone = null;
    if (n != null) {
      try {
        n.stop();
      } catch (_) {}
    }
    if (d != null && !d.isCompleted) d.complete(true);
  }

  void stopVoice() {
    _token++;
    _stopVoiceNode();
  }

  /// 효과음: 목소리와 별개로 겹쳐 튼다(목소리를 끊지 않는다). 잠겨 있으면 그냥 건너뛴다.
  Future<void> playSfx(String assetKey, {double volume = 1}) async {
    if (!await _ready()) return;
    final buf = await _load(assetKey);
    if (buf == null) return;
    final ctx = _context();
    final g = ctx.createGain()..connect(_sfxGain!);
    g.gain.value = volume;
    final src = ctx.createBufferSource()..buffer = buf;
    src.connect(g);
    src.start();
  }
}
