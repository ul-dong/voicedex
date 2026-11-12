import 'species.dart';

/// 대사 템플릿 규칙(`assets/data/voice_lines_ko.json`의 `template_rules`와 같다).
///
/// - `{name}` 종 이름, `{hint}` 앞글자 힌트, `{feature}` 특징 힌트 문장
/// - `{name:A/B}` 이름 + 조사: 마지막 글자에 받침이 있으면 A, 없으면 B
///   (예: `{name:이/가}` → 곰이 / 코끼리가, `{name:이야/야}` → 곰이야 / 코끼리야)
/// - `{name:으로/로}`만 예외: 받침 없음·ㄹ 받침 → 로, 그 밖의 받침 → 으로
///
/// 녹음 대본은 [expand]로 종마다 펼친 통문장을 쓴다([expandAll]).
class LineTemplate {
  LineTemplate._();

  static final RegExp _token = RegExp(
    r'\{(name|hint|feature)(?::([^/{}]+)/([^/{}]+))?\}',
  );

  /// 템플릿에 종에 따라 달라지는 자리가 있는가.
  static bool isSpeciesDependent(String template) => _token.hasMatch(template);

  static String expand(String template, Species? species) =>
      template.replaceAllMapped(_token, (m) {
        final field = m[1]!;
        final value = switch (field) {
          'name' => species?.name ?? '',
          'hint' => species?.hint ?? '',
          _ => species?.featureHint ?? '',
        };
        final withBatchim = m[2];
        final without = m[3];
        if (withBatchim == null || without == null) return value;
        return value + particle(value, withBatchim, without);
      });

  /// [word] 뒤에 붙일 조사. [withBatchim]/[without]은 받침 있을 때/없을 때 형태.
  static String particle(String word, String withBatchim, String without) {
    final jong = finalConsonantIndex(word);
    if (withBatchim == '으로' && without == '로') {
      return (jong == 0 || jong == 8) ? without : withBatchim; // 8 = ㄹ
    }
    return jong > 0 ? withBatchim : without;
  }

  /// 마지막 글자의 종성 번호(0 = 받침 없음, 8 = ㄹ). 한글 음절이 아니면 0.
  static int finalConsonantIndex(String word) {
    if (word.isEmpty) return 0;
    final code = word.runes.last;
    if (code < 0xAC00 || code > 0xD7A3) return 0;
    return (code - 0xAC00) % 28;
  }

  /// 받침을 뺀 음절(곰 → 고). 한 음절 이름의 앞글자 힌트 규칙에 쓴다.
  static String withoutFinalConsonant(String syllable) {
    if (syllable.isEmpty) return syllable;
    final code = syllable.runes.first;
    if (code < 0xAC00 || code > 0xD7A3) return syllable;
    return String.fromCharCode(code - (code - 0xAC00) % 28);
  }

  /// 녹음 대본: 키 → (종 id 또는 null → 통문장). 종에 따라 달라지는 키는 종마다 하나씩 펼친다.
  static Map<String, Map<String?, String>> expandAll(
    Map<String, String> lines,
    List<Species> species,
  ) => {
    for (final e in lines.entries)
      e.key: isSpeciesDependent(e.value)
          ? {for (final s in species) s.id: expand(e.value, s)}
          : {null: e.value},
  };
}
