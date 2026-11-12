import '../../content/species.dart';

/// 대사 키. 실제 문장은 `assets/data/voice_lines_ko.json`에 있다.
/// 녹음 파일로 바꿀 때도 이 키로 파일을 찾는다(README 참고).
class VoiceKeys {
  VoiceKeys._();

  static const askNameFromColor = 'ask.name_from_color';
  static const retryListen = 'listen.retry';
  static const hintFirstSyllable = 'hint.first_syllable';
  static const correctSayName = 'correct.say_name';
  static const stageClear = 'stage.clear';

  static const all = [
    askNameFromColor,
    retryListen,
    hintFirstSyllable,
    correctSayName,
    stageClear,
  ];
}

/// 말할 대사 하나: 키 + (종에 따라 달라지는 대사라면) 종.
class VoiceLine {
  const VoiceLine(this.key, {this.species});

  final String key;

  /// `{name}`, `{hint}` 자리를 채울 종.
  final Species? species;

  @override
  String toString() => species == null ? key : '$key(${species!.id})';
}
