import 'dart:math';

import '../content/species.dart';

/// 종별 출제 가중치. 0보다 커야 뽑힌다. 기본은 모두 1(균등).
typedef SpeciesWeight = double Function(Species species);

double uniformWeight(Species _) => 1.0;

/// 스테이지 출제기. 한 스테이지 안에서 중복 없이 [count]개를 가중치 비복원 추출한다.
///
/// [isPriority]와 [minPriority]를 주면 우선 종(도감 미보유 종)을 스테이지마다 최소
/// `min(우선 종 수, minPriority)`개 반드시 넣는다. 나머지 자리는 [weight]로 뽑고, 순서는 섞는다.
/// → 스테이지를 끝낼 때마다 미보유 종이 최소 minPriority개(남은 게 그보다 적으면 남은 전부)씩 줄어들므로,
///   N종 도감은 최대 ceil(N / minPriority) 스테이지 안에 반드시 다 채워진다(체감은 랜덤).
class QuestionPicker {
  QuestionPicker({
    Random? random,
    this.weight = uniformWeight,
    this.isPriority,
    this.minPriority = 0,
  }) : _random = random ?? Random();

  /// 도감 미보유 종 우선 출제기.
  /// - 미보유 종 가중치 [unmetWeight](보유 종은 1) → 남는 자리에도 미보유 종이 더 자주 나온다.
  /// - 스테이지마다 미보유 종 최소 [minUnmet]개 보장.
  factory QuestionPicker.dexAware({
    Random? random,
    required bool Function(Species species) isMet,
    double unmetWeight = 3.0,
    int minUnmet = 2,
  }) => QuestionPicker(
    random: random,
    weight: (s) => isMet(s) ? 1.0 : unmetWeight,
    isPriority: (s) => !isMet(s),
    minPriority: minUnmet,
  );

  final Random _random;
  final SpeciesWeight weight;
  final bool Function(Species species)? isPriority;
  final int minPriority;

  List<Species> pick(List<Species> pool, int count) {
    if (count > pool.length) {
      throw ArgumentError('count $count > pool ${pool.length}');
    }
    final prio = isPriority;
    if (prio == null || minPriority <= 0) {
      return _weighted([...pool], count);
    }
    final candidates = pool.where(prio).toList();
    final guaranteed = _weighted(
      candidates,
      min(min(candidates.length, minPriority), count),
    );
    final rest = pool.where((s) => !guaranteed.contains(s)).toList();
    final picked = [
      ...guaranteed,
      ..._weighted(rest, count - guaranteed.length),
    ]..shuffle(_random);
    return picked;
  }

  /// [remaining]에서 가중치 비복원 추출로 [count]개.
  List<Species> _weighted(List<Species> remaining, int count) {
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
