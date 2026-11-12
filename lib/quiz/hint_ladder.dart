/// 단계식 힌트(MASTER_PROMPT §5 "힌트").
///
/// 오답(다른 이름이 인식됨)마다 한 칸씩 올라간다. 인식 실패는 칸을 올리지 않는다.
///   1번째 오답 → [HintStep.feature]     특징 힌트 ("코가 아주아주 길어!")
///   2번째 오답 → [HintStep.firstSyllable] 앞글자 ("코...", 곰은 "고...")
///   3번째 오답부터 → [HintStep.sayAndRepeat] 정답을 들려주고 따라 하게 ("코끼리! 따라 해 볼까?")
///     → 아이가 따라 말하면 정답으로 처리한다. 계속 다르게 말하면 이 칸을 반복한다(실패 판정 없음).
enum HintStep { none, feature, firstSyllable, sayAndRepeat }

/// 한 문항의 힌트 상태.
class HintLadder {
  int _wrong = 0;

  /// 지금까지의 오답 수(인식 실패 제외).
  int get wrongCount => _wrong;

  /// 지금 단계(마지막으로 준 힌트).
  HintStep get step => switch (_wrong) {
    0 => HintStep.none,
    1 => HintStep.feature,
    2 => HintStep.firstSyllable,
    _ => HintStep.sayAndRepeat,
  };

  /// 힌트를 한 번이라도 받았는가. 받은 문항은 도감 칸은 열리지만 3층(단계) 표시는 붙지 않는다.
  bool get usedHint => _wrong > 0;

  /// 오답이 나왔다 → 다음 힌트 단계를 돌려준다.
  HintStep onWrong() {
    _wrong++;
    return step;
  }

  /// 인식 실패는 힌트 단계를 바꾸지 않는다.
  void onNotRecognized() {}

  void reset() => _wrong = 0;
}
