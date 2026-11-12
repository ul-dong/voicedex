import '../content/species.dart';
import '../services/speech/speech_input.dart';

enum Verdict {
  /// 정답.
  correct,

  /// 다른 말이 인식됨 → 힌트.
  wrong,

  /// 인식 실패(무응답·결과 없음·에러) → 다시 듣기. 오답으로 세지 않는다.
  notRecognized,
}

class Judgement {
  const Judgement(this.verdict, {this.matchedText, this.matchedCandidate});

  final Verdict verdict;

  /// 정답으로 인정된 인식 문자열과 그 안에서 찾은 정답 후보.
  final String? matchedText;
  final String? matchedCandidate;

  @override
  String toString() =>
      'Judgement(${verdict.name}'
      '${matchedCandidate == null ? '' : ' "$matchedText" ⊃ "$matchedCandidate"'})';
}

/// 정답 판정기. 부분 일치: 정규화한 인식 문자열에 정규화한 정답 후보가 들어 있으면 정답.
class AnswerJudge {
  const AnswerJudge();

  // 한글·영문·숫자만 남긴다(공백·문장부호·기호 제거).
  static final RegExp _strip = RegExp(r'[^0-9A-Za-z가-힣ㄱ-ㆎ]');

  static String normalize(String text) =>
      text.replaceAll(_strip, '').toLowerCase();

  Judgement judgeText(List<String> alternatives, Species target) {
    final heard = alternatives
        .map(normalize)
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (heard.isEmpty) return const Judgement(Verdict.notRecognized);
    final candidates = target.acceptable
        .map(normalize)
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    for (final text in heard) {
      for (final c in candidates) {
        if (text.contains(c)) {
          return Judgement(
            Verdict.correct,
            matchedText: text,
            matchedCandidate: c,
          );
        }
      }
    }
    return const Judgement(Verdict.wrong);
  }

  Judgement judge(SpeechOutcome outcome, Species target) {
    if (outcome.kind != SpeechOutcomeKind.recognized) {
      return const Judgement(Verdict.notRecognized);
    }
    return judgeText(outcome.alternatives, target);
  }
}
