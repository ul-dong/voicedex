// 녹음할 통문장 목록을 tools/voice/lines.json 으로 내보낸다.
// 실행: flutter test tools/voice/export_lines_test.dart   (tools/voice/gen_voice.command 가 부른다)
//
// 문장 = assets/data/voice_lines_ko.json 의 모든 대사, 종에 따라 바뀌는 대사는 모든 월드의 모든 종으로 펼친 것
// (lib/services/voice/voice_sentences.dart — 앱이 말할 때와 같은 함수).
// 이미 녹음한 문장은 assets/voice/manifest.json 의 파일 이름을 그대로 쓰고,
// 새 문장만 다음 번호를 받는다(번호가 밀려 엉뚱한 녹음이 나오지 않게, 번호는 영구).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/content/species.dart';
import 'package:voicedex/content/world_catalog.dart';
import 'package:voicedex/services/voice/voice_lines.dart';
import 'package:voicedex/services/voice/voice_sentences.dart';

void main() {
  test('export voice lines', () {
    final lines = VoiceLines.fromJson(
      jsonDecode(File(VoiceLines.defaultAsset).readAsStringSync())
          as Map<String, dynamic>,
    );
    final species = <Species>[
      for (final w in WorldCatalog.ordered)
        ...WorldContent.fromJson(
          jsonDecode(File(w.dataAsset).readAsStringSync())
              as Map<String, dynamic>,
        ).species,
    ];
    final sentences = allVoiceSentences(lines, species);

    final bad = sentences.where(unfilledPlaceholder.hasMatch).toList();
    expect(bad, isEmpty, reason: '채우지 못한 자리 표시가 있는 문장');

    final manifestFile = File('assets/voice/manifest.json');
    final old = manifestFile.existsSync()
        ? (jsonDecode(manifestFile.readAsStringSync()) as Map)
              .cast<String, String>()
        : <String, String>{};
    var next = old.values
        .map((f) => int.tryParse(RegExp(r'(\d+)').firstMatch(f)?[1] ?? '') ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final out = [
      for (final text in sentences)
        {
          'file': old[text] ?? 'v${(++next).toString().padLeft(4, '0')}.mp3',
          'text': text,
        },
    ];
    File('tools/voice/lines.json').writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(out)}\n',
    );
    final fresh = out.where((e) => !old.containsKey(e['text'])).length;
    // ignore: avoid_print
    print('문장 ${out.length}개 (새 문장 $fresh개) → tools/voice/lines.json');
    expect(sentences.toSet().length, sentences.length);
    expect(out.map((e) => e['file']).toSet().length, out.length);
  });
}
