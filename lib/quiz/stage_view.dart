import '../content/species.dart';

/// 스테이지 화면(그림·연출) 쪽 인터페이스. Flame 게임이 구현하고, 테스트에서는 가짜로 바꾼다.
abstract class QuizStageView {
  /// 새 문제 그림을 보여 준다(등장 연출이 끝나면 돌아온다).
  Future<void> showQuestion(Species species, int index, int total);

  /// 정답 연출: 그림이 한 번 튀어오르며 흔들린다.
  Future<void> playCorrect(Species species);

  /// 스테이지 끝 축하 연출.
  Future<void> celebrate(List<Species> met);
}
