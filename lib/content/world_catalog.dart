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
    this.coverSpecies = const [],
    this.color = 0xFF8DBE8A,
  });

  final String id;

  /// 종 목록 데이터 파일.
  final String dataAsset;

  /// 무료 여부 (false면 과금·페어런탈 게이트 대상, 아직 미구현).
  final bool free;

  final List<StageKind> stages;

  /// 메인 화면 입구 그림에 세울 종 id(앞에서부터 가운데·왼쪽·오른쪽).
  final List<String> coverSpecies;

  /// 입구 그림 바탕색(ARGB).
  final int color;
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
    coverSpecies: ['elephant', 'giraffe', 'lion'],
    color: 0xFF9ED39A,
  );

  // 탈것·공룡 월드는 데이터와 그림이 준비되면 같은 형식으로 추가한다.
  // static const vehicles = WorldDef(id: 'vehicles', dataAsset: 'assets/data/vehicles.json', free: false);
  // static const dinosaurs = WorldDef(id: 'dinosaurs', dataAsset: 'assets/data/dinosaurs.json', free: false);

  static const List<WorldDef> ordered = [animals];

  /// 아이 화면(메인)에 보이는 월드. 잠긴/유료 월드는 아이 화면에 보이지 않는다(절대 제약).
  /// 구매가 생기면 [unlocked]에 산 월드 id를 넘긴다(구매 화면은 페어런탈 게이트 뒤, 아이 화면 밖).
  static List<WorldDef> visibleToChild({Set<String> unlocked = const {}}) => [
    for (final w in ordered)
      if (w.free || unlocked.contains(w.id)) w,
  ];
}
