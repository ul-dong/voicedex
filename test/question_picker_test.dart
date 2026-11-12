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

  group('도감 미보유 우선 출제기', () {
    /// 스테이지를 끝낼 때마다 출제된 종이 도감에 열린다고 보고, 다 찰 때까지 몇 스테이지 걸리는지.
    int stagesToFill(Random rnd, Set<String> met, {int minUnmet = 2}) {
      var stages = 0;
      while (met.length < pool.length) {
        final picker = QuestionPicker.dexAware(
          random: rnd,
          isMet: (s) => met.contains(s.id),
          minUnmet: minUnmet,
        );
        final q = picker.pick(pool, 6);
        expect(q.map((s) => s.id).toSet().length, 6);
        final unmetBefore = pool.length - met.length;
        final newly = q.where((s) => !met.contains(s.id)).length;
        // 보장: 미보유가 남아 있으면 최소 min(남은 수, minUnmet)개는 반드시 나온다.
        expect(newly, greaterThanOrEqualTo(min(unmetBefore, minUnmet)));
        met.addAll(q.map((s) => s.id));
        stages++;
        if (stages > 100) fail('끝나지 않음');
      }
      return stages;
    }

    test('빈 도감에서 시작하면 첫 스테이지는 전부 새 종, 최대 4스테이지 안에 12종이 다 찬다', () {
      for (var seed = 0; seed < 2000; seed++) {
        final n = stagesToFill(Random(seed), <String>{});
        // 1스테이지 6종 + 이후 매번 최소 2종 → 1 + ceil(6/2) = 4
        expect(n, lessThanOrEqualTo(4), reason: 'seed $seed');
        expect(n, greaterThanOrEqualTo(2));
      }
    });

    test('어떤 중간 상태에서 시작해도 ceil(남은 수 / 2) 스테이지 안에 다 찬다', () {
      final rnd = Random(11);
      for (var trial = 0; trial < 2000; trial++) {
        final met = {
          for (final s in pool)
            if (rnd.nextBool()) s.id,
        };
        final left = pool.length - met.length;
        final n = stagesToFill(rnd, met);
        expect(n, lessThanOrEqualTo((left / 2).ceil()));
      }
    });

    test('미보유가 1종만 남아도 다음 스테이지에 반드시 나온다', () {
      for (var seed = 0; seed < 500; seed++) {
        final last = pool[seed % pool.length];
        final q = QuestionPicker.dexAware(
          random: Random(seed),
          isMet: (s) => s.id != last.id,
        ).pick(pool, 6);
        expect(q, contains(last));
      }
    });

    test('체감은 랜덤: 새 종이 늘 맨 앞에 오지 않고, 보유 종도 섞여 나온다', () {
      final met = {for (final s in pool.take(9)) s.id}; // 미보유 3종
      final firstPositions = <int>{};
      var metAppear = 0;
      for (var seed = 0; seed < 300; seed++) {
        final q = QuestionPicker.dexAware(
          random: Random(seed),
          isMet: (s) => met.contains(s.id),
        ).pick(pool, 6);
        final idx = q.indexWhere((s) => !met.contains(s.id));
        firstPositions.add(idx);
        metAppear += q.where((s) => met.contains(s.id)).length;
      }
      expect(firstPositions.length, greaterThan(2));
      expect(metAppear, greaterThan(0));
    });

    test('도감이 다 차면 균등 출제', () {
      final rnd = Random(5);
      final counts = <String, int>{};
      for (var i = 0; i < 2000; i++) {
        final q = QuestionPicker.dexAware(
          random: rnd,
          isMet: (_) => true,
        ).pick(pool, 6);
        for (final s in q) {
          counts[s.id] = (counts[s.id] ?? 0) + 1;
        }
      }
      for (final c in counts.values) {
        expect(c, inInclusiveRange(850, 1150));
      }
    });
  });
}
