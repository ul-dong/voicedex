/// 이번에 추가한 대사 키(문장은 `assets/data/voice_lines_ko.json`).
/// 기존 키(`VoiceKeys`, lib/services/voice/voice_line.dart)와 같은 표를 쓴다.
class LineKeys {
  LineKeys._();

  /// 오답 1번째: 특징 힌트(종별, `{feature}`).
  static const hintFeature = 'hint.feature';

  /// 오답 3번째부터: 정답을 들려주고 따라 하게(종별, `{name}`).
  static const hintSayAndRepeat = 'hint.say_and_repeat';

  /// 따라 말하기로 맞혔을 때(종별, `{name}`).
  static const correctAfterRepeat = 'correct.after_repeat';

  /// 스테이지 끝 도감 찍힘: 새 종이 열렸을 때 / 이미 만난 종만일 때.
  static const rewardNewFriends = 'reward.new_friends';
  static const rewardDexStamped = 'reward.dex_stamped';

  /// 메인 화면.
  static const homeWelcome = 'home.welcome';
  static const homeDex = 'home.dex';

  /// 월드 입구 버튼 이름: `home.world.<world id>`.
  static String homeWorld(String worldId) => 'home.world.$worldId';

  /// 도감 칸: 못 만난 종(이름 공개 안 함) / 만난 종(종별, `{name:이야/야}`).
  static const dexUnknown = 'dex.unknown';
  static const dexKnown = 'dex.known';

  /// 돌아가기(집) 버튼.
  static const dexHome = 'dex.home';

  static final all = [
    hintFeature,
    hintSayAndRepeat,
    correctAfterRepeat,
    rewardNewFriends,
    rewardDexStamped,
    homeWelcome,
    homeDex,
    homeWorld('animals'),
    dexUnknown,
    dexKnown,
    dexHome,
  ];
}

/// 효과음 이름. `SoundEffects`(lib/services/sfx/)가 이 이름으로 소리를 찾는다. 없으면 조용히 넘어간다.
class SfxNames {
  SfxNames._();

  static const correct = 'correct';
  static const tryAgain = 'try_again';
  static const tap = 'tap';
  static const fanfare = 'fanfare';
  static const stamp = 'stamp';
  static const unlock = 'unlock';

  static const all = [correct, tryAgain, tap, fanfare, stamp, unlock];
}
