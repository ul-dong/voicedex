import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/quiz/answer_judge.dart';
import 'package:voicedex/services/speech/speech_input.dart';

import 'test_data.dart';

void main() {
  final animals = loadAnimals();
  const judge = AnswerJudge();

  Verdict v(String id, List<String> heard) =>
      judge.judge(SpeechOutcome.recognized(heard), byId(animals, id)).verdict;

  group('정규화', () {
    test('공백·문장부호 제거', () {
      expect(AnswerJudge.normalize(' 코 끼리! '), '코끼리');
      expect(AnswerJudge.normalize('펭귄이?!.'), '펭귄이');
      expect(AnswerJudge.normalize('사자, 사자~'), '사자사자');
      expect(AnswerJudge.normalize('...'), '');
    });
  });

  group('정답(부분 일치)', () {
    test('정식 이름', () {
      for (final s in animals.species) {
        expect(v(s.id, [s.name]), Verdict.correct, reason: s.id);
      }
    });

    test('아이가 흔히 쓰는 말', () {
      expect(v('elephant', ['코끼리야']), Verdict.correct);
      expect(v('monkey', ['원숭']), Verdict.correct);
      expect(v('penguin', ['펭귄이']), Verdict.correct);
      expect(v('lion', ['이건 사자예요']), Verdict.correct);
      expect(v('rabbit', ['토끼다!']), Verdict.correct);
      expect(v('bear', ['곰돌이']), Verdict.correct);
      expect(v('kangaroo', ['캥거']), Verdict.correct);
      expect(v('rhino', ['코뿔']), Verdict.correct);
      expect(v('camel', ['낙타야']), Verdict.correct);
    });

    test('공백·문장부호가 섞여도 정답', () {
      expect(v('elephant', ['코 끼 리 !']), Verdict.correct);
      expect(v('crocodile', ['악, 어.']), Verdict.correct);
      expect(v('hippo', ['하 마?']), Verdict.correct);
    });

    test('유사 발음 허용', () {
      expect(v('bear', ['공']), Verdict.correct);
      expect(v('bear', ['공이야']), Verdict.correct);
      expect(v('elephant', ['꼬끼리']), Verdict.correct);
      expect(v('rabbit', ['도끼']), Verdict.correct);
      expect(v('penguin', ['팽귄']), Verdict.correct);
      expect(v('kangaroo', ['캉가루']), Verdict.correct);
    });

    test('여러 후보 중 하나라도 맞으면 정답', () {
      expect(v('bear', ['검', '곰']), Verdict.correct);
    });
  });

  group('오답', () {
    test('다른 종 이름은 오답', () {
      for (final target in animals.species) {
        for (final other in animals.species) {
          if (other.id == target.id) continue;
          expect(
            v(target.id, [other.name]),
            Verdict.wrong,
            reason: '${target.id} <- "${other.name}"',
          );
        }
      }
    });

    test('엉뚱한 말은 오답', () {
      expect(v('elephant', ['몰라']), Verdict.wrong);
      expect(v('elephant', ['코']), Verdict.wrong); // 첫 음절만으로는 정답 아님
      expect(v('giraffe', ['강아지']), Verdict.wrong);
    });
  });

  group('인식 실패는 오답과 구분', () {
    final s = byId(animals, 'lion');
    test('무응답', () {
      expect(
        judge.judge(const SpeechOutcome.noSpeech(), s).verdict,
        Verdict.notRecognized,
      );
    });
    test('에러', () {
      expect(
        judge.judge(const SpeechOutcome.error('error_network'), s).verdict,
        Verdict.notRecognized,
      );
      expect(
        judge
            .judge(const SpeechOutcome.unavailable('error_permission'), s)
            .verdict,
        Verdict.notRecognized,
      );
    });
    test('빈 문자열·문장부호만', () {
      expect(
        judge.judge(const SpeechOutcome.recognized(['']), s).verdict,
        Verdict.notRecognized,
      );
      expect(
        judge.judge(const SpeechOutcome.recognized([' ', '?!']), s).verdict,
        Verdict.notRecognized,
      );
      expect(
        judge.judge(const SpeechOutcome.recognized([]), s).verdict,
        Verdict.notRecognized,
      );
    });
  });
}
