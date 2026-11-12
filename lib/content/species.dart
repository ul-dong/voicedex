/// 한 종(동물·탈것·공룡 공통)의 데이터. 값은 전부 `assets/data/<world>.json`에서 온다.
class Species {
  const Species({
    required this.id,
    required this.no,
    required this.name,
    required this.answers,
    required this.similar,
    required this.hint,
    required this.colorImage,
    required this.shadowImage,
  });

  /// 영문 id (그림 파일 이름과 같다).
  final String id;

  /// 도감 번호.
  final int no;

  /// 표시용 이름(부모·개발자 화면, 음성 대사에만 쓴다. 아이 화면에는 띄우지 않는다).
  final String name;

  /// 정답 후보: 정식 이름·단축형·동의어. 인식 문자열에 포함되면 정답.
  final List<String> answers;

  /// 인식기가 비슷하게 받아 적는 유사 발음. 정답과 같이 취급한다.
  final List<String> similar;

  /// 오답일 때 들려줄 첫 음절.
  final String hint;

  /// 색칠 그림 SVG 에셋 경로.
  final String colorImage;

  /// 그림자 SVG 에셋 경로 (2·3단계용).
  final String shadowImage;

  /// 정답으로 인정하는 모든 문자열.
  List<String> get acceptable => [...answers, ...similar];

  factory Species.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<String>();
    return Species(
      id: json['id'] as String,
      no: json['no'] as int,
      name: json['name'] as String,
      answers: strings('answers'),
      similar: strings('similar'),
      hint: json['hint'] as String,
      colorImage: json['color_image'] as String,
      shadowImage: json['shadow_image'] as String,
    );
  }

  @override
  String toString() => 'Species($id)';
}

/// 한 월드의 종 목록 데이터.
class WorldContent {
  const WorldContent({required this.worldId, required this.species});

  final String worldId;
  final List<Species> species;

  factory WorldContent.fromJson(Map<String, dynamic> json) => WorldContent(
    worldId: json['world'] as String,
    species: (json['species'] as List<dynamic>)
        .map((e) => Species.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}
