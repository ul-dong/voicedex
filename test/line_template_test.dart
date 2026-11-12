import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/content/line_keys.dart';
import 'package:voicedex/content/line_template.dart';

import 'test_data.dart';

void main() {
  final animals = loadAnimals();
  final json = jsonDecode(
    File('assets/data/voice_lines_ko.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final lines = (json['lines'] as Map<String, dynamic>).cast<String, String>();

  test('새 대사 키가 모두 데이터에 있다', () {
    for (final k in LineKeys.all) {
      expect(lines.containsKey(k), isTrue, reason: k);
    }
    expect(json['template_rules'], isA<Map<String, dynamic>>());
  });

  test('조사: 받침 있으면 앞, 없으면 뒤 (으로/로는 ㄹ 예외)', () {
    expect(LineTemplate.particle('곰', '이/가'.split('/')[0], '가'), '이');
    expect(LineTemplate.particle('코끼리', '이', '가'), '가');
    expect(LineTemplate.particle('기린', '이야', '야'), '이야');
    expect(LineTemplate.particle('하마', '이야', '야'), '야');
    expect(LineTemplate.particle('곰', '으로', '로'), '으로');
    expect(LineTemplate.particle('하마', '으로', '로'), '로');
    expect(LineTemplate.particle('물', '으로', '로'), '로');
    expect(LineTemplate.particle('abc', '이', '가'), '가');
  });

  test('도감 칸 이름: 종마다 조사가 맞는 통문장', () {
    String known(String id) =>
        LineTemplate.expand(lines[LineKeys.dexKnown]!, byId(animals, id));
    expect(known('bear'), '곰이야!');
    expect(known('elephant'), '코끼리야!');
    expect(known('penguin'), '펭귄이야!');
    expect(known('camel'), '낙타야!');
    expect(
      LineTemplate.expand('{name:이/가} 왔어', byId(animals, 'lion')),
      '사자가 왔어',
    );
    expect(
      LineTemplate.expand('{name:은/는}', byId(animals, 'crocodile')),
      '악어는',
    );
  });

  test('모든 대사를 12종으로 펼치면 남는 {…} 자리가 없고, 특징 힌트에 이름이 없다', () {
    final all = LineTemplate.expandAll(lines, animals.species);
    for (final e in all.entries) {
      for (final sentence in e.value.values) {
        expect(sentence, isNot(contains('{')), reason: e.key);
        expect(sentence.trim(), isNotEmpty, reason: e.key);
      }
    }
    expect(all[LineKeys.hintFeature]!.length, 12);
    expect(all[LineKeys.dexUnknown]!.keys.single, isNull);
    expect(all[LineKeys.hintSayAndRepeat]!['elephant'], '코끼리! 따라 해 볼까?');
    expect(all[LineKeys.hintFeature]!['elephant'], '코가 아주아주 길어!');
  });

  test('못 만난 종 대사는 이름을 말하지 않는다', () {
    expect(
      LineTemplate.isSpeciesDependent(lines[LineKeys.dexUnknown]!),
      isFalse,
    );
    for (final s in animals.species) {
      expect(lines[LineKeys.dexUnknown], isNot(contains(s.name)));
    }
  });

  test('받침 빼기(한 음절 이름 앞글자 힌트)', () {
    expect(LineTemplate.withoutFinalConsonant('곰'), '고');
    expect(LineTemplate.withoutFinalConsonant('코'), '코');
  });
}
