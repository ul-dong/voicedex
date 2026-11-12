import '../../content/line_template.dart';
import '../../content/species.dart';
import 'voice_lines.dart';

/// 앱이 실제로 말하는 모든 통문장(녹음할 목록).
///
/// - 종과 무관한 대사는 그대로 한 번.
/// - 종에 따라 바뀌는 대사(`{name}`·`{hint}`·`{feature}`·`{name:이/가}` …)는 모든 종으로 펼친다
///   ([LineTemplate.expand] — 앱이 말할 때와 같은 함수).
/// - 같은 문장은 한 번만(예: 코끼리·코뿔소의 힌트 "코...").
///
/// 순서는 대사 표 순서 → 종 순서. 녹음 번호는 매니페스트가 정하므로 순서가 바뀌어도 기존 번호는 그대로다.
List<String> allVoiceSentences(VoiceLines lines, List<Species> species) {
  final out = <String>[];
  final seen = <String>{};
  void add(String s) {
    if (s.trim().isEmpty) return;
    if (seen.add(s)) out.add(s);
  }

  for (final template in lines.lines.values) {
    if (LineTemplate.isSpeciesDependent(template)) {
      for (final s in species) {
        add(LineTemplate.expand(template, s));
      }
    } else {
      add(template);
    }
  }
  return out;
}

/// 채우지 못하고 남은 자리 표시(`{...}`). 녹음 대본에는 없어야 한다.
final unfilledPlaceholder = RegExp(r'\{[^{}]*\}');
