import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/quiz/question_picker.dart';

import 'test_data.dart';

void main() {
  final pool = loadAnimals().species;

  test('12종 풀에서 6문항, 중복 없음, 모두 풀 안', () {
    for (var seed = 0; seed < 500; seed++) {
      final q = QuestionPicker(random: Random(seed)).pick(pool, 6);
      expect(q.length, 6);
      expect(q.map((s) => s.id).toSet().length, 6, reason: 'seed $seed');
      expect(pool.toSet().containsAll(q), isTrue);
    }
  });

  test('여러 번 출제하면 12종이 모두 나온다(균등)', () {
    final rnd = Random(42);
    final counts = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      for (final s in QuestionPicker(random: rnd).pick(pool, 6)) {
        counts[s.id] = (counts[s.id] ?? 0) + 1;
      }
    }
    expect(counts.length, 12);
    // 기대값 1000 (2000×6/12)
    for (final c in counts.values) {
      expect(c, inInclusiveRange(850, 1150));
    }
  });

  test('가중치 함수 자리: 가중치 높은 종이 더 자주 나온다', () {
    final rnd = Random(7);
    final favored = {'camel', 'crocodile'};
    final picker = QuestionPicker(
      random: rnd,
      weight: (s) => favored.contains(s.id) ? 5.0 : 1.0,
    );
    final counts = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      for (final s in picker.pick(pool, 6)) {
        counts[s.id] = (counts[s.id] ?? 0) + 1;
      }
    }
    expect(counts['camel']!, greaterThan(counts['elephant']! * 1.3));
  });

  test('가중치 0인 종은 다른 종이 충분하면 뽑히지 않는다', () {
    final picker = QuestionPicker(
      random: Random(1),
      weight: (s) => s.id == 'lion' ? 0 : 1,
    );
    for (var i = 0; i < 300; i++) {
      expect(picker.pick(pool, 6).any((s) => s.id == 'lion'), isFalse);
    }
  });

  test('풀보다 많이 뽑으면 에러', () {
    expect(() => QuestionPicker().pick(pool, 13), throwsArgumentError);
  });
}
