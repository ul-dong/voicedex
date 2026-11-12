/// 도감 진행(보상 2·3층, MASTER_PROMPT §6). 기기 로컬에만 저장한다(계정·네트워크 없음).
///
/// - 2층: 스테이지를 끝내면 그 스테이지에서 맞힌 종이 도감에 열린다(힌트를 썼어도 똑같이 열림).
/// - 3층: 단계별 표시. 1단계 → 칸(색칠 그림), 2단계 → 테두리, 3단계 → 금테.
///   단계 표시는 그 단계에서 **힌트 없이** 맞힌 종에만 붙는다. 힌트를 쓴 문항은 "아직 안 받은 상태"로 남을 뿐,
///   실패 표시는 하지 않는다(데이터에도 실패 기록 없음).
library;

import '../content/world_catalog.dart';

/// 도감 칸 표시 단계.
enum DexTier {
  /// 아직 못 만남 → 그림자.
  hidden,

  /// 만남 → 색칠 그림.
  open,

  /// 2단계 표시 → 테두리.
  border,

  /// 3단계 표시 → 금테.
  gold,
}

/// 한 종의 도감 기록.
class DexEntry {
  DexEntry({this.met = false, Set<StageKind>? marks})
    : marks = marks ?? <StageKind>{};

  /// 도감에 열렸는가(2층).
  bool met;

  /// 힌트 없이 맞혀 받은 단계 표시(3층).
  final Set<StageKind> marks;

  DexTier get tier {
    if (!met) return DexTier.hidden;
    if (marks.contains(StageKind.nameFromShadow)) return DexTier.gold;
    if (marks.contains(StageKind.matchShadow)) return DexTier.border;
    return DexTier.open;
  }

  DexEntry copy() => DexEntry(met: met, marks: {...marks});

  Map<String, dynamic> toJson() => {
    'met': met,
    'marks': [
      for (final k in StageKind.values)
        if (marks.contains(k)) k.name,
    ],
  };

  factory DexEntry.fromJson(Map<String, dynamic> json) => DexEntry(
    met: json['met'] as bool? ?? false,
    marks: {
      for (final n in (json['marks'] as List<dynamic>? ?? const []))
        for (final k in StageKind.values)
          if (k.name == n) k,
    },
  );
}

/// 한 문항의 결과(스테이지 안에서는 모든 문항이 결국 맞혀서 끝난다).
class QuestionResult {
  const QuestionResult(this.speciesId, {required this.usedHint});

  final String speciesId;

  /// 특징·앞글자·따라 말하기 힌트 중 하나라도 받았는가.
  final bool usedHint;

  @override
  String toString() => '$speciesId${usedHint ? '(hint)' : ''}';
}

class StageResult {
  const StageResult({
    required this.worldId,
    required this.kind,
    required this.results,
  });

  final String worldId;
  final StageKind kind;
  final List<QuestionResult> results;
}

/// 스테이지 결과를 도감에 반영한 변화(찍힘 연출용).
class StampChange {
  const StampChange(this.speciesId, this.before, this.after);

  final String speciesId;
  final DexTier before;
  final DexTier after;

  /// 이번에 처음 열린 종(더 크게 강조).
  bool get isNew => before == DexTier.hidden;

  bool get upgraded => after.index > before.index;

  @override
  String toString() => '$speciesId ${before.name}->${after.name}';
}

class DexProgress {
  DexProgress([Map<String, Map<String, DexEntry>>? worlds])
    : _worlds = worlds ?? {};

  static const int version = 1;

  final Map<String, Map<String, DexEntry>> _worlds;

  /// 기록이 없으면 빈 기록(못 만남).
  DexEntry entry(String worldId, String speciesId) =>
      _worlds[worldId]?[speciesId] ?? DexEntry();

  bool isMet(String worldId, String speciesId) => entry(worldId, speciesId).met;

  DexTier tier(String worldId, String speciesId) =>
      entry(worldId, speciesId).tier;

  int metCount(String worldId) =>
      _worlds[worldId]?.values.where((e) => e.met).length ?? 0;

  DexEntry _mutable(String worldId, String speciesId) =>
      (_worlds[worldId] ??= {})[speciesId] ??= DexEntry();

  /// 스테이지 결과 반영. 맞힌 종은 모두 열리고, 힌트 없이 맞힌 종에만 그 단계 표시가 붙는다.
  /// 이미 받은 표시는 없어지지 않는다(나중에 힌트를 써도 내려가지 않음).
  List<StampChange> apply(StageResult result) {
    final changes = <StampChange>[];
    final seen = <String>{};
    for (final q in result.results) {
      if (!seen.add(q.speciesId)) continue;
      final e = _mutable(result.worldId, q.speciesId);
      final before = e.tier;
      e.met = true;
      if (!q.usedHint) e.marks.add(result.kind);
      changes.add(StampChange(q.speciesId, before, e.tier));
    }
    return changes;
  }

  /// 개발자 모드: 칸 표시를 강제로 바꾼다.
  void debugSetTier(String worldId, String speciesId, DexTier tier) {
    final e = _mutable(worldId, speciesId);
    e.marks.clear();
    e.met = tier != DexTier.hidden;
    if (tier.index >= DexTier.open.index) e.marks.add(StageKind.nameFromColor);
    if (tier.index >= DexTier.border.index) e.marks.add(StageKind.matchShadow);
    if (tier.index >= DexTier.gold.index) e.marks.add(StageKind.nameFromShadow);
  }

  void clear() => _worlds.clear();

  DexProgress copy() => DexProgress({
    for (final w in _worlds.entries)
      w.key: {for (final s in w.value.entries) s.key: s.value.copy()},
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'worlds': {
      for (final w in _worlds.entries)
        w.key: {for (final s in w.value.entries) s.key: s.value.toJson()},
    },
  };

  /// 모르는 형식이면 빈 기록(앱이 멈추지 않게).
  factory DexProgress.fromJson(Map<String, dynamic> json) {
    final worlds = json['worlds'];
    if (worlds is! Map<String, dynamic>) return DexProgress();
    return DexProgress({
      for (final w in worlds.entries)
        if (w.value is Map<String, dynamic>)
          w.key: {
            for (final s in (w.value as Map<String, dynamic>).entries)
              if (s.value is Map<String, dynamic>)
                s.key: DexEntry.fromJson(s.value as Map<String, dynamic>),
          },
    });
  }
}
