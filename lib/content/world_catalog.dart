/// 월드·단계 정의. 순서는 MASTER_PROMPT §3을 따른다.
library;

/// 월드 안의 단계 종류.
enum StageKind {
  /// 1단계: 색칠된 그림을 보고 이름 말하기. (구현됨)
  nameFromColor,

  /// 2단계: 그림자와 그림을 드래그해 짝맞추기. (미구현)
  matchShadow,

  /// 3단계: 그림자만 보고 이름 말하기. (미구현)
  nameFromShadow,
}

class WorldDef {
  const WorldDef({
    required this.id,
    required this.dataAsset,
    required this.free,
    this.stages = StageKind.values,
  });

  final String id;

  /// 종 목록 데이터 파일.
  final String dataAsset;

  /// 무료 여부 (false면 과금·페어런탈 게이트 대상, 아직 미구현).
  final bool free;

  final List<StageKind> stages;
}

/// 스테이지 하나의 출제 규칙.
class StageSpec {
  const StageSpec({
    required this.world,
    required this.kind,
    this.questionCount = 6,
  });

  final WorldDef world;
  final StageKind kind;
  final int questionCount;
}

class WorldCatalog {
  WorldCatalog._();

  static const animals = WorldDef(
    id: 'animals',
    dataAsset: 'assets/data/animals.json',
    free: true,
  );

  // 탈것·공룡 월드는 데이터와 그림이 준비되면 같은 형식으로 추가한다.
  // static const vehicles = WorldDef(id: 'vehicles', dataAsset: 'assets/data/vehicles.json', free: false);
  // static const dinosaurs = WorldDef(id: 'dinosaurs', dataAsset: 'assets/data/dinosaurs.json', free: false);

  static const List<WorldDef> ordered = [animals];
}
