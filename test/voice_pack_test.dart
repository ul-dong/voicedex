import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/content/line_keys.dart';
import 'package:voicedex/content/line_template.dart';
import 'package:voicedex/content/species.dart';
import 'package:voicedex/content/world_catalog.dart';
import 'package:voicedex/services/sfx/sound_effects.dart';
import 'package:voicedex/services/voice/pack_voice_output.dart';
import 'package:voicedex/services/voice/voice_choice.dart';
import 'package:voicedex/services/voice/voice_engines.dart';
import 'package:voicedex/services/voice/voice_line.dart';
import 'package:voicedex/services/voice/voice_lines.dart';
import 'package:voicedex/services/voice/voice_pack.dart';
import 'package:voicedex/services/voice/voice_sentences.dart';

import 'test_data.dart';

/// 녹음 재생 흉내: [play]는 [finishAll]이나 [stop]까지 기다린다(즉시 끝내려면 autoFinish).
class FakeClips implements ClipPlayer {
  FakeClips({this.autoFinish = true, this.fail = const {}});

  final bool autoFinish;
  final Set<String> fail;
  final List<String> played = [];
  int stops = 0;
  final List<Completer<bool>> _pending = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> play(String file) async {
    played.add(file);
    if (fail.contains(file)) return false;
    if (autoFinish) return true;
    final c = Completer<bool>();
    _pending.add(c);
    return c.future;
  }

  void finishAll() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete(true);
    }
    _pending.clear();
  }

  @override
  Future<void> stop() async {
    stops++;
    finishAll();
  }
}

class FakeTts implements TextSpeaker {
  final List<String> spoken = [];

  @override
  String get debugDescription => 'fake';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

void main() {
  final lines = VoiceLines.fromJson(
    jsonDecode(File(VoiceLines.defaultAsset).readAsStringSync())
        as Map<String, dynamic>,
  );
  final animals = loadAnimals();
  final allSpecies = <Species>[
    for (final w in WorldCatalog.ordered)
      ...WorldContent.fromJson(
        jsonDecode(File(w.dataAsset).readAsStringSync())
            as Map<String, dynamic>,
      ).species,
  ];
  final elephant = byId(animals, 'elephant');
  final bear = byId(animals, 'bear');

  group('녹음 팩 조회', () {
    final pack = VoicePack({'맞아! 코끼리!': 'v0038.mp3', '코...': 'v0015.mp3'});

    test('문장 그대로 찾는다', () {
      expect(pack.lookup('맞아! 코끼리!'), 'v0038.mp3');
      expect(pack.lookup('코...'), 'v0015.mp3');
      expect(VoicePack.assetKey('v0015.mp3'), 'assets/voice/v0015.mp3');
    });

    test('앞뒤·겹친 띄어쓰기는 같은 문장, 문장부호가 다르면 다른 문장', () {
      expect(pack.lookup(' 맞아!  코끼리! '), 'v0038.mp3');
      expect(pack.lookup('맞아! 코끼리?'), isNull);
      expect(pack.lookup('맞아 코끼리'), isNull);
    });

    test('조각을 이어 붙이지 않는다(통문장이 없으면 null)', () {
      expect(pack.lookup('맞아! 코끼리! 코...'), isNull);
      expect(pack.lookup('코끼리!'), isNull);
    });

    test('매니페스트 형식이 틀리면 빈 팩', () {
      expect(VoicePack.fromJson('x').isEmpty, isTrue);
      expect(VoicePack.fromJson({'a': 1, 'b': 'b.mp3'}).length, 1);
    });
  });

  group('PackVoiceOutput', () {
    VoiceLine correct(Species s) =>
        VoiceLine(VoiceKeys.correctSayName, species: s);

    test('녹음이 있으면 녹음만 튼다', () async {
      final clips = FakeClips();
      final tts = FakeTts();
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack({'맞아! 코끼리!': 'v0038.mp3'}),
        clips: clips,
        tts: tts,
      );
      await v.say(correct(elephant));
      expect(clips.played, ['v0038.mp3']);
      expect(tts.spoken, isEmpty);
      expect(v.lastSource, VoiceSource.pack);
    });

    test('녹음이 없으면 같은 문장을 TTS로', () async {
      final clips = FakeClips();
      final tts = FakeTts();
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack({'맞아! 코끼리!': 'v0038.mp3'}),
        clips: clips,
        tts: tts,
      );
      await v.say(correct(bear));
      expect(clips.played, isEmpty);
      expect(tts.spoken, ['맞아! 곰!']);
      expect(v.lastSource, VoiceSource.tts);
    });

    test('녹음 재생에 실패하면 TTS로', () async {
      final clips = FakeClips(fail: {'v0038.mp3'});
      final tts = FakeTts();
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack({'맞아! 코끼리!': 'v0038.mp3'}),
        clips: clips,
        tts: tts,
      );
      await v.say(correct(elephant));
      expect(clips.played, ['v0038.mp3']);
      expect(tts.spoken, ['맞아! 코끼리!']);
    });

    test('끼어들기: 새 say가 오면 앞의 say는 바로 돌아오고 TTS로 넘어가지 않는다', () async {
      final clips = FakeClips(autoFinish: false);
      final tts = FakeTts();
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack({'맞아! 코끼리!': 'a.mp3', '맞아! 곰!': 'b.mp3'}),
        clips: clips,
        tts: tts,
      );
      var firstDone = false;
      final first = v.say(correct(elephant)).then((_) => firstDone = true);
      await pumpEventQueue();
      expect(clips.played, ['a.mp3']);
      expect(firstDone, isFalse);

      final second = v.say(correct(bear));
      await pumpEventQueue();
      expect(firstDone, isTrue, reason: '앞의 말은 끊기고 바로 돌아온다');
      expect(clips.played, ['a.mp3', 'b.mp3']);

      var secondDone = false;
      unawaited(second.then((_) => secondDone = true));
      await pumpEventQueue();
      expect(secondDone, isFalse, reason: '뒤의 말은 끝까지 기다린다');
      clips.finishAll();
      await first;
      await second;
      expect(tts.spoken, isEmpty);
    });

    test('stop: 진행 중인 say가 바로 돌아온다', () async {
      final clips = FakeClips(autoFinish: false);
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack({'맞아! 코끼리!': 'a.mp3'}),
        clips: clips,
        tts: FakeTts(),
      );
      var done = false;
      final f = v.say(correct(elephant)).then((_) => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      await v.stop();
      await pumpEventQueue();
      expect(done, isTrue);
      await f;
    });

    test('TTS가 끝나지 않아도 stop하면 돌아온다', () async {
      final tts = _HangingTts();
      final v = PackVoiceOutput(
        lines: lines,
        pack: VoicePack(const {}),
        clips: FakeClips(),
        tts: tts,
      );
      var done = false;
      final f = v.say(correct(elephant)).then((_) => done = true);
      await pumpEventQueue();
      expect(tts.spoken, ['맞아! 코끼리!']);
      expect(done, isFalse);
      await v.stop();
      await pumpEventQueue();
      expect(done, isTrue);
      await f;
    });
  });

  group('녹음 대본(문장 목록)', () {
    final sentences = allVoiceSentences(lines, allSpecies);

    test('모든 대사 × 모든 종의 실제 문장을 포함한다', () {
      final keys = {...VoiceKeys.all, ...LineKeys.all, ...lines.lines.keys};
      for (final key in keys) {
        expect(lines.lines.containsKey(key), isTrue, reason: key);
        final template = lines.lines[key]!;
        final targets = LineTemplate.isSpeciesDependent(template)
            ? allSpecies
            : <Species?>[null, ...allSpecies];
        for (final s in targets) {
          final text = lines.render(VoiceLine(key, species: s));
          expect(sentences, contains(text), reason: '$key ${s?.id}');
        }
      }
    });

    test('채우지 못한 자리 표시·빈 문장·중복이 없다', () {
      expect(sentences.where(unfilledPlaceholder.hasMatch), isEmpty);
      expect(sentences.where((s) => s.trim().isEmpty), isEmpty);
      expect(sentences.toSet().length, sentences.length);
    });

    test('종별 대사는 종마다 펼치고 같은 문장은 한 번(코끼리·코뿔소 힌트 "코...")', () {
      expect(sentences, containsAll(['맞아! 코끼리!', '맞아! 곰!', '맞아! 낙타!']));
      expect(sentences.where((s) => s == '코...').length, 1);
    });

    test('조사: 받침에 맞게 펼친다', () {
      final t = '{name:이야/야}!';
      expect(LineTemplate.expand(t, bear), '곰이야!');
      expect(LineTemplate.expand(t, elephant), '코끼리야!');
    });
  });

  group('실제 녹음 팩(assets/voice)', () {
    final manifest =
        (jsonDecode(File(VoicePack.manifestAsset).readAsStringSync()) as Map)
            .cast<String, String>();
    final sentences = allVoiceSentences(lines, allSpecies);

    test('앱이 말하는 모든 문장에 녹음이 있다 (없으면 tools/voice/gen_voice.command)', () {
      final missing = sentences.where((s) => !manifest.containsKey(s)).toList();
      expect(missing, isEmpty, reason: '녹음 없음(지금은 TTS로 나옴): $missing');
    });

    test('매니페스트의 파일이 모두 있고 번호가 겹치지 않는다', () {
      for (final f in manifest.values) {
        expect(File('assets/voice/$f').existsSync(), isTrue, reason: f);
      }
      expect(manifest.values.toSet().length, manifest.length);
    });
  });

  group('기기 음성 고르기', () {
    test('여성·neural 우선, 남성 회피', () {
      expect(voiceScore('Yuna'), greaterThan(voiceScore('Some voice')));
      expect(voiceScore('Yuna (Enhanced)'), greaterThan(0));
      expect(voiceScore('ko-kr-x-ism-local'), greaterThan(0));
      expect(voiceScore('Microsoft InJoon Online (Natural)'), lessThan(0));
      expect(voiceScore('ko-kr-x-kod-network'), lessThan(0));
      expect(voiceScore('Korean Male'), lessThan(0));
      expect(voiceScore('Korean Female'), greaterThan(0));
      expect(voiceScore('X Neural'), 20);
      expect(
        voiceScore('Microsoft SunHi Online (Natural)'),
        greaterThan(voiceScore('X Neural')),
      );
    });

    test('톤: 음높이 1.0(올리지 않음), 속도 웹 0.9 / 모바일 0.44', () {
      expect(ttsTone(web: true), (pitch: 1.0, rate: 0.9));
      expect(ttsTone(web: false), (pitch: 1.0, rate: 0.44));
    });
  });

  group('효과음', () {
    test('모든 효과음 파일이 있고, 화면이 쓰는 이름(SfxNames)을 모두 찾는다', () {
      for (final s in Sfx.values) {
        expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      }
      for (final name in SfxNames.all) {
        expect(Sfx.byFile(name), isNotNull, reason: name);
      }
      expect(Sfx.byFile('nope'), isNull);
    });

    test('기록용 구현', () async {
      final r = RecordingSoundEffects();
      await r.play('correct');
      await r.playSfx(Sfx.unlock);
      expect(r.played, ['correct', 'unlock']);
      expect(await r.playCorrect(byId(animals, 'lion')), isFalse);
    });
  });
}

/// 끝을 알리지 않는 TTS(사파리에서 가끔 있는 일).
class _HangingTts extends FakeTts {
  @override
  Future<void> speak(String text) {
    spoken.add(text);
    return Completer<void>().future;
  }
}
