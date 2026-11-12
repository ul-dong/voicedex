import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/services/voice/voice_line.dart';
import 'package:voicedex/services/voice/voice_lines.dart';

import 'test_data.dart';

void main() {
  final lines = VoiceLines.fromJson(
    jsonDecode(File(VoiceLines.defaultAsset).readAsStringSync())
        as Map<String, dynamic>,
  );
  final animals = loadAnimals();

  test('모든 대사 키가 데이터에 있다', () {
    expect(lines.locale, 'ko-KR');
    for (final k in VoiceKeys.all) {
      expect(lines.lines.containsKey(k), isTrue, reason: k);
    }
  });

  test('힌트는 첫 음절만 말한다', () {
    final e = byId(animals, 'elephant');
    expect(
      lines.render(VoiceLine(VoiceKeys.hintFirstSyllable, species: e)),
      '코...',
    );
    expect(
      lines.render(VoiceLine(VoiceKeys.hintFirstSyllable, species: e)),
      isNot(contains('코끼리')),
    );
  });

  test('정답 대사에 이름이 들어간다', () {
    final s = byId(animals, 'penguin');
    expect(
      lines.render(VoiceLine(VoiceKeys.correctSayName, species: s)),
      contains('펭귄'),
    );
  });
}
