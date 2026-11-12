import 'dart:math';

import '../content/species.dart';

/// 종별 출제 가중치. 0보다 커야 뽑힌다. 기본은 모두 1(균등).
///
/// 도감 구현 후: 미보유 종에 더 큰 값(예: 3.0)을 돌려주도록 바꾼다.
typedef SpeciesWeight = double Function(Species species);

double uniformWeight(Species _) => 1.0;

/// 스테이지 출제기. 한 스테이지 안에서 중복 없이 [count]개를 가중치 비복원 추출한다.
class QuestionPicker {
  QuestionPicker({Random? random, this.weight = uniformWeight})
    : _random = random ?? Random();

  final Random _random;
  final SpeciesWeight weight;

  List<Species> pick(List<Species> pool, int count) {
    if (count > pool.length) {
      throw ArgumentError('count $count > pool ${pool.length}');
    }
    final remaining = [...pool];
    final picked = <Species>[];
    while (picked.length < count) {
      final weights = remaining.map((s) => max(0.0, weight(s))).toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      int index;
      if (total <= 0) {
        index = _random.nextInt(remaining.length);
      } else {
        var r = _random.nextDouble() * total;
        index = weights.lastIndexWhere((w) => w > 0);
        for (var i = 0; i < remaining.length; i++) {
          r -= weights[i];
          if (r < 0 && weights[i] > 0) {
            index = i;
            break;
          }
        }
      }
      picked.add(remaining.removeAt(index));
    }
    return picked;
  }
}
