import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/quiz/hint_ladder.dart';

void main() {
  test('오답1 → 특징, 오답2 → 앞글자, 오답3부터 → 정답 듣고 따라 하기', () {
    final h = HintLadder();
    expect(h.step, HintStep.none);
    expect(h.usedHint, isFalse);
    expect(h.onWrong(), HintStep.feature);
    expect(h.usedHint, isTrue);
    expect(h.onWrong(), HintStep.firstSyllable);
    expect(h.onWrong(), HintStep.sayAndRepeat);
    expect(h.onWrong(), HintStep.sayAndRepeat);
    expect(h.onWrong(), HintStep.sayAndRepeat);
    expect(h.wrongCount, 5);
  });

  test('인식 실패는 단계를 올리지 않는다', () {
    final h = HintLadder();
    h.onNotRecognized();
    h.onNotRecognized();
    expect(h.step, HintStep.none);
    expect(h.usedHint, isFalse);
    h.onWrong();
    h.onNotRecognized();
    h.onNotRecognized();
    expect(h.step, HintStep.feature);
    expect(h.onWrong(), HintStep.firstSyllable);
  });

  test('reset → 처음으로', () {
    final h = HintLadder()
      ..onWrong()
      ..onWrong();
    h.reset();
    expect(h.step, HintStep.none);
    expect(h.usedHint, isFalse);
  });
}
