import 'dart:async';

/// 한 번 듣기의 결과 종류.
enum SpeechOutcomeKind {
  /// 무언가 받아 적었다(정답인지 오답인지는 판정기가 정한다).
  recognized,

  /// 아무 말도 없었거나 인식 결과가 없다.
  noSpeech,

  /// 인식 중 일시적 에러.
  error,

  /// 권한 거부·인식기 없음 등, 다시 들어도 소용없는 상태.
  unavailable,
}

class SpeechOutcome {
  const SpeechOutcome._(this.kind, this.alternatives, this.errorCode);

  const SpeechOutcome.recognized(List<String> alternatives)
    : this._(SpeechOutcomeKind.recognized, alternatives, null);

  const SpeechOutcome.noSpeech()
    : this._(SpeechOutcomeKind.noSpeech, const [], null);

  const SpeechOutcome.error(String code)
    : this._(SpeechOutcomeKind.error, const [], code);

  const SpeechOutcome.unavailable(String code)
    : this._(SpeechOutcomeKind.unavailable, const [], code);

  final SpeechOutcomeKind kind;

  /// 인식기 후보 문자열(첫 번째가 가장 유력).
  final List<String> alternatives;
  final String? errorCode;

  @override
  String toString() =>
      'SpeechOutcome(${kind.name}${alternatives.isEmpty ? '' : ' $alternatives'}'
      '${errorCode == null ? '' : ' $errorCode'})';
}

/// 음성 입력. 기기 인식기와 디버그용 가짜 입력이 이 인터페이스를 구현한다.
abstract class SpeechInput {
  /// 권한 요청과 인식기 준비. false면 사용할 수 없다.
  Future<bool> initialize();

  /// 한 번 듣고 결과를 돌려준다.
  ///
  /// [acceptPartial]이 중간 결과에 대해 true를 돌려주면 그 자리에서 듣기를 끝낸다.
  Future<SpeechOutcome> listenOnce({
    bool Function(List<String> partial)? acceptPartial,
  });

  /// 듣는 중이면 멈춘다. 진행 중인 [listenOnce]는 noSpeech로 끝난다.
  Future<void> cancel();

  /// 입력 음량(0~1). 마이크 아이콘 반응에 쓴다.
  Stream<double> get soundLevel;

  /// 개발자 표시용 설명.
  String get debugDescription;
}
