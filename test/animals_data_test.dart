import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/quiz/answer_judge.dart';

import 'test_data.dart';

void main() {
  final animals = loadAnimals();

  test('동물 12종, MASTER_PROMPT 순서와 id', () {
    expect(animals.worldId, 'animals');
    expect(animals.species.map((s) => s.id).toList(), [
      'elephant',
      'giraffe',
      'lion',
      'rabbit',
      'penguin',
      'bear',
      'hippo',
      'monkey',
      'crocodile',
      'rhino',
      'kangaroo',
      'camel',
    ]);
    expect(
      animals.species.map((s) => s.no).toList(),
      List.generate(12, (i) => i + 1),
    );
  });

  test('필수 필드와 그림 파일이 있다', () {
    for (final s in animals.species) {
      expect(s.name, isNotEmpty);
      expect(
        s.answers,
        contains(s.name),
        reason: '${s.id}: 정식 이름이 정답 후보에 있어야 함',
      );
      expect(File(s.colorImage).existsSync(), isTrue, reason: s.colorImage);
      expect(File(s.shadowImage).existsSync(), isTrue, reason: s.shadowImage);
    }
  });

  test('첫 음절 힌트 = 이름의 첫 글자', () {
    for (final s in animals.species) {
      expect(s.hint, s.name.substring(0, 1), reason: s.id);
    }
    expect(byId(animals, 'elephant').hint, '코');
  });

  test('곰은 유사 발음 "공"을 포함', () {
    expect(byId(animals, 'bear').similar, contains('공'));
  });

  test('한 종의 정답 후보가 다른 종 이름·후보 안에 들어 있지 않다(교차 오인 방지)', () {
    for (final a in animals.species) {
      for (final b in animals.species) {
        if (a.id == b.id) continue;
        for (final ca in a.acceptable.map(AnswerJudge.normalize)) {
          for (final cb in [b.name, ...b.answers].map(AnswerJudge.normalize)) {
            expect(
              cb.contains(ca),
              isFalse,
              reason: '${a.id}의 "$ca"가 ${b.id}의 "$cb" 안에 있음',
            );
          }
        }
      }
    }
  });
}
