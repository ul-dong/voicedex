import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../platform/web_audio.dart';
import 'speech_input.dart';

/// 기기 음성 인식기(speech_to_text: iOS SFSpeechRecognizer / Android SpeechRecognizer).
///
/// [onDeviceOnly]가 true면 iOS는 `requiresOnDeviceRecognition`을 켜서 음성이 기기 밖으로 나가지 않는다
/// (기기 내 인식을 지원하지 않으면 듣기가 실패한다). Android는 기기 내 인식기가 있으면 그것을 쓰고,
/// 없으면 기본 인식기(보통 Google 앱)로 넘어간다 — README의 개인정보 절 참고.
///
/// 웹: 브라우저 Web Speech API(`webkitSpeechRecognition`). [onDeviceOnly]는 적용되지 않는다
/// (크롬은 음성을 Google 서버로 보내 인식한다). 웹 버전은 내부 테스트 전용이다.
/// 지원하지 않는 브라우저(파이어폭스 등)나 권한 거부면 "사용 불가"를 돌려줘 마이크 버튼이 기다림 상태가 된다.
class DeviceSpeechInput implements SpeechInput {
  DeviceSpeechInput({
    this.localeId = 'ko_KR',
    this.onDeviceOnly = true,
    this.contextualPhrases = const [],
    this.listenFor = const Duration(seconds: 7),
    this.pauseFor = const Duration(milliseconds: 2200),
    SpeechToText? stt,
  }) : _stt = stt ?? SpeechToText();

  final String localeId;
  final bool onDeviceOnly;
  final List<String> contextualPhrases;
  final Duration listenFor;
  final Duration pauseFor;
  final SpeechToText _stt;

  final _levels = StreamController<double>.broadcast();
  Completer<SpeechOutcome>? _pending;
  List<String> _lastWords = const [];
  bool? _available;
  double _minLevel = double.infinity;
  double _maxLevel = double.negativeInfinity;
  DateTime? _lastCancelAt;

  @override
  Stream<double> get soundLevel => _levels.stream;

  @override
  String get debugDescription =>
      'device($localeId, onDeviceOnly=$onDeviceOnly, available=$_available)';

  @override
  Future<bool> initialize() async {
    if (_available == true) return true;
    if (kIsWeb) {
      if (!webSpeechRecognitionSupported) {
        debugPrint('[speech] web: SpeechRecognition not supported');
        return _available = false;
      }
      // 사용자 제스처(재생 버튼) 안에서 마이크 권한을 먼저 받는다.
      if (await requestWebMicrophone() == MicPermission.denied) {
        debugPrint('[speech] web: microphone denied');
        return _available = false;
      }
    }
    try {
      _available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );
    } catch (e) {
      debugPrint('[speech] initialize failed: $e');
      _available = false;
    }
    debugPrint('[speech] initialize -> $_available');
    return _available!;
  }

  @override
  Future<SpeechOutcome> listenOnce({
    bool Function(List<String> partial)? acceptPartial,
  }) async {
    if (_available != true && !await initialize()) {
      return const SpeechOutcome.unavailable('not_initialized');
    }
    if (_pending != null) await cancel();
    if (kIsWeb && _lastCancelAt != null) {
      // 웹: abort() 직후 바로 start()하면 InvalidStateError가 난다. 이전 세션이 끝날 틈을 준다.
      final since = DateTime.now().difference(_lastCancelAt!);
      const settle = Duration(milliseconds: 450);
      if (since < settle) await Future<void>.delayed(settle - since);
    }
    final completer = Completer<SpeechOutcome>();
    _pending = completer;
    _lastWords = const [];

    void onResult(SpeechRecognitionResult r) {
      final words = r.alternates
          .map((a) => a.recognizedWords)
          .where((w) => w.trim().isNotEmpty)
          .toList(growable: false);
      if (words.isNotEmpty) _lastWords = words;
      if (r.finalResult) {
        _finish(
          words.isEmpty
              ? const SpeechOutcome.noSpeech()
              : SpeechOutcome.recognized(words),
        );
      } else if (words.isNotEmpty &&
          acceptPartial != null &&
          acceptPartial(words)) {
        _finish(SpeechOutcome.recognized(words));
        unawaited(_stt.stop());
      }
    }

    try {
      await _stt.listen(
        onResult: onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          onDevice: onDeviceOnly,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          listenFor: listenFor,
          pauseFor: pauseFor,
          contextualPhrases: contextualPhrases.isEmpty
              ? null
              : contextualPhrases,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[speech] listen threw: $e');
      // iOS: onDeviceError = 이 기기는 ko-KR 기기 내 인식을 지원하지 않음 (서버 인식으로 넘어가지 않는다).
      _finish(
        e.code.toLowerCase().contains('ondevice')
            ? SpeechOutcome.unavailable('on_device_unsupported')
            : SpeechOutcome.error('listen_exception:${e.code}'),
      );
    } catch (e) {
      debugPrint('[speech] listen threw: $e');
      _finish(SpeechOutcome.error('listen_exception:$e'));
    }
    // 안전장치: 어떤 콜백도 오지 않을 때.
    return completer.future.timeout(
      listenFor + const Duration(seconds: 4),
      onTimeout: () {
        _finish(const SpeechOutcome.noSpeech());
        unawaited(_stt.cancel());
        return completer.future;
      },
    );
  }

  void _finish(SpeechOutcome outcome) {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    _pending = null;
    debugPrint('[speech] outcome $outcome');
    c.complete(outcome);
  }

  void _onStatus(String status) {
    debugPrint('[speech] status $status');
    if (status == SpeechToText.doneStatus) {
      // 최종 결과 없이 끝났으면, 중간 결과라도 있으면 그것으로, 없으면 무응답.
      final pending = _pending;
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!identical(_pending, pending)) return; // 그 사이 새 듣기가 시작됨
        _finish(
          _lastWords.isEmpty
              ? const SpeechOutcome.noSpeech()
              : SpeechOutcome.recognized(_lastWords),
        );
      });
    }
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('[speech] error ${e.errorMsg} permanent=${e.permanent}');
    switch (e.errorMsg) {
      case 'aborted': // 웹: 앱이 cancel()로 멈춘 것
        return;
      case 'error_no_match':
      case 'error_speech_timeout':
      case 'no-speech': // 웹
      case 'no-match': // 웹
        _finish(
          _lastWords.isEmpty
              ? const SpeechOutcome.noSpeech()
              : SpeechOutcome.recognized(_lastWords),
        );
      case 'error_listen_failed': // iOS: 마이크 입력 없음(시뮬레이터 등)·오디오 엔진 시작 실패
      case 'error_permission':
      case 'error_insufficient_permissions':
      case 'error_speech_recognizer_disabled':
      case 'error_language_not_supported':
      case 'error_language_unavailable':
      // 웹(Web Speech API) 오류 코드
      case 'not-allowed':
      case 'service-not-allowed':
      case 'audio-capture':
      case 'language-not-supported':
      case 'not supported':
        _finish(SpeechOutcome.unavailable(e.errorMsg));
      default:
        _finish(SpeechOutcome.error(e.errorMsg));
    }
  }

  void _onLevel(double level) {
    _minLevel = min(_minLevel, level);
    _maxLevel = max(_maxLevel, level);
    final span = _maxLevel - _minLevel;
    _levels.add(span < 1e-6 ? 0 : ((level - _minLevel) / span).clamp(0.0, 1.0));
  }

  @override
  Future<void> cancel() async {
    if (_stt.isListening) {
      _lastCancelAt = DateTime.now();
      await _stt.cancel();
    }
    _finish(const SpeechOutcome.noSpeech());
  }
}
