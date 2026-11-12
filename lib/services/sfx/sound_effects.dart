import '../../content/species.dart';

/// 정답 효과음(동물 울음소리 등) 자리.
abstract class SoundEffects {
  /// 해당 종의 정답 효과음이 있으면 재생하고 true, 없으면 false.
  Future<bool> playCorrect(Species species);
}

/// 효과음 파일이 아직 없어 아무것도 하지 않는다.
// TODO(sfx): 종별 효과음(assets/sfx/<id>_correct.m4a 등)과 재생 패키지를 정하면 구현한다.
// false를 돌려주면 정답 연출에서 TTS로 동물 이름을 대신 말한다.
class NoSoundEffects implements SoundEffects {
  const NoSoundEffects();

  @override
  Future<bool> playCorrect(Species species) async => false;
}
