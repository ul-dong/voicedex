import '../../content/species.dart';

/// 효과음 종류. 파일은 `assets/audio/sfx/<파일>.wav`, `tools/generate_sfx.py`로 다시 만든다
/// (외부 음원 없이 직접 합성, 알록달록과 같은 소리 + voicedex용 [unlock]).
enum Sfx {
  /// 정답 "뾰로롱" (도-미-솔 실로폰)
  correct('correct'),

  /// 다시 해 보기 "음~ 다시?" (버저·단조 아님)
  tryAgain('try_again'),

  /// 누르기 "뽁" (가장 작게)
  tap('tap'),

  /// 코인 "띠링"
  coin('coin'),

  /// 한 판 완료 팡파르
  fanfare('fanfare'),

  /// 사기·옷 입기 "샤라랑"
  buy('buy'),

  /// 도장 "쾅·퐁"
  stamp('stamp'),

  /// 콕 찌르기 "뽀잉"
  poke('poke'),

  /// 새로 열림(도감 등록·새 단계 열림) "반짝 짠!"
  unlock('unlock');

  const Sfx(this.file);

  /// 파일 이름(확장자 없음).
  final String file;

  /// 에셋 키.
  String get asset => 'assets/audio/sfx/$file.wav';

  /// 파일 이름으로 찾기('try_again' 등). 없으면 null.
  static Sfx? byFile(String file) {
    for (final s in values) {
      if (s.file == file) return s;
    }
    return null;
  }
}

/// 효과음. 목소리와 겹쳐 나며 목소리를 끊지 않는다.
abstract class SoundEffects {
  /// 해당 종의 정답 효과음(울음소리 등)이 있으면 재생하고 true, 없으면 false
  /// (false면 정답 연출에서 목소리로 이름을 말한다). 지금은 종별 소리가 없어 항상 false.
  Future<bool> playCorrect(Species species);

  /// 이름(`SfxNames`, lib/content/line_keys.dart — 'correct', 'try_again', 'tap', 'fanfare', 'stamp',
  /// 'unlock' …)으로 효과음을 튼다. 모르는 이름이면 조용히 넘어간다.
  /// 재생을 시작하면 돌아온다(소리가 끝날 때까지 기다리지 않는다).
  Future<void> play(String name);
}

extension SoundEffectsPlaySfx on SoundEffects {
  /// [Sfx]로 틀기.
  Future<void> playSfx(Sfx sfx) => play(sfx.file);
}

/// 아무 소리도 내지 않는다(테스트·기본값).
class NoSoundEffects implements SoundEffects {
  const NoSoundEffects();

  @override
  Future<bool> playCorrect(Species species) async => false;

  @override
  Future<void> play(String name) async {}
}

/// 테스트용: 무엇을 틀었는지 기록만 한다.
class RecordingSoundEffects implements SoundEffects {
  final List<String> played = [];

  @override
  Future<bool> playCorrect(Species species) async => false;

  @override
  Future<void> play(String name) async => played.add(name);
}
