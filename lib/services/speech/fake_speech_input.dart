import 'dart:async';

import 'speech_input.dart';

/// 디버그 빌드 전용 가짜 음성 입력. 시뮬레이터처럼 마이크가 없는 환경에서
/// 정답/오답/인식 실패 흐름을 확인하는 데 쓴다.
///
/// - 대본([script]): 듣기마다 앞에서부터 하나씩 꺼내 자동으로 답한다.
///   `correct`(정답 이름), `wrong`(다른 이름), `none`(무응답), `error`(에러),
///   그 밖의 문자열은 그대로 인식된 말로 취급한다.
/// - 대본이 비면 [inject]가 불릴 때까지(디버그 패널 버튼) 기다리고, [autoTimeout] 뒤에는 무응답.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput({
    List<String> script = const [],
    this.answerDelay = const Duration(milliseconds: 1200),
    this.autoTimeout = const Duration(seconds: 30),
  }) : _script = [...script];

  final List<String> _script;
  final Duration answerDelay;
  final Duration autoTimeout;

  /// 현재 문제의 정답·오답 문자열을 알려주는 함수(컨트롤러가 설정).
  String Function()? correctText;
  String Function()? wrongText;

  final _levels = StreamController<double>.broadcast();
  Completer<SpeechOutcome>? _pending;
  Timer? _timer;
  Timer? _levelTimer;

  bool get isListening => _pending != null;

  @override
  Stream<double> get soundLevel => _levels.stream;

  @override
  String get debugDescription => 'fake(script left: ${_script.length})';

  @override
  Future<bool> initialize() async => true;

  @override
  Future<SpeechOutcome> listenOnce({
    bool Function(List<String> partial)? acceptPartial,
  }) {
    _finish(const SpeechOutcome.noSpeech());
    final c = Completer<SpeechOutcome>();
    _pending = c;
    var t = 0;
    _levelTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      t++;
      _levels.add((t % 5) / 5);
    });
    if (_script.isNotEmpty) {
      final token = _script.removeAt(0);
      _timer = Timer(answerDelay, () => inject(token));
    } else {
      _timer = Timer(
        autoTimeout,
        () => _finish(const SpeechOutcome.noSpeech()),
      );
    }
    return c.future;
  }

  /// 디버그 패널에서 직접 답을 넣는다.
  void inject(String token) {
    switch (token) {
      case 'correct':
        _finish(SpeechOutcome.recognized([correctText?.call() ?? '']));
      case 'wrong':
        _finish(SpeechOutcome.recognized([wrongText?.call() ?? '모르겠어']));
      case 'none':
        _finish(const SpeechOutcome.noSpeech());
      case 'error':
        _finish(const SpeechOutcome.error('fake_error'));
      default:
        _finish(SpeechOutcome.recognized([token]));
    }
  }

  void _finish(SpeechOutcome outcome) {
    _timer?.cancel();
    _levelTimer?.cancel();
    _levels.add(0);
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(outcome);
  }

  @override
  Future<void> cancel() async => _finish(const SpeechOutcome.noSpeech());
}
