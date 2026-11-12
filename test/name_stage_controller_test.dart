import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/content/line_keys.dart';
import 'package:voicedex/content/species.dart';
import 'package:voicedex/content/world_catalog.dart';
import 'package:voicedex/progress/dex_progress.dart';
import 'package:voicedex/quiz/hint_ladder.dart';
import 'package:voicedex/quiz/name_stage_controller.dart';
import 'package:voicedex/quiz/question_picker.dart';
import 'package:voicedex/quiz/stage_view.dart';
import 'package:voicedex/services/sfx/sound_effects.dart';
import 'package:voicedex/services/speech/speech_input.dart';
import 'package:voicedex/services/voice/voice_line.dart';
import 'package:voicedex/services/voice/voice_output.dart';

import 'test_data.dart';

class FakeView implements QuizStageView {
  final events = <String>[];
  @override
  Future<void> showQuestion(Species s, int i, int total) async =>
      events.add('show:${s.id}');
  @override
  Future<void> playCorrect(Species s) async => events.add('correct:${s.id}');
  @override
  Future<void> celebrate(List<Species> met) async =>
      events.add('celebrate:${met.length}');
}

class FakeVoice implements VoiceOutput {
  final said = <String>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<void> say(VoiceLine line) async => said.add(line.toString());
  @override
  Future<void> stop() async {}
}

/// 듣기마다 미리 정한 함수로 결과를 만든다. 대본이 비면 멈춰서 기다린다.
class ScriptedSpeech implements SpeechInput {
  ScriptedSpeech(this.script);
  final List<SpeechOutcome Function()> script;
  int listens = 0;
  Completer<SpeechOutcome>? hanging;

  @override
  Future<bool> initialize() async => true;
  @override
  Future<SpeechOutcome> listenOnce({
    bool Function(List<String>)? acceptPartial,
  }) {
    listens++;
    if (script.isEmpty) {
      hanging = Completer();
      return hanging!.future;
    }
    return Future.value(script.removeAt(0)());
  }

  @override
  Future<void> cancel() async {
    final h = hanging;
    hanging = null;
    if (h != null && !h.isCompleted) h.complete(const SpeechOutcome.noSpeech());
  }

  @override
  Stream<double> get soundLevel => const Stream.empty();
  @override
  String get debugDescription => 'scripted';
}

void main() {
  final pool = loadAnimals().species;
  const spec = StageSpec(
    world: WorldCatalog.animals,
    kind: StageKind.nameFromColor,
  );

  late FakeView view;
  late FakeVoice voice;

  setUp(() {
    view = FakeView();
    voice = FakeVoice();
  });

  NameStageController make(ScriptedSpeech speech, {VoidCallback? onFinished}) =>
      NameStageController(
        spec: spec,
        pool: pool,
        view: view,
        voice: voice,
        speech: speech,
        picker: QuestionPicker(random: Random(3)),
        onFinished: onFinished,
      );

  test('6문항 모두 정답 → 축하 → 종료', () async {
    late NameStageController c;
    final speech = ScriptedSpeech([
      for (var i = 0; i < 6; i++)
        () => SpeechOutcome.recognized(['${c.current!.name}야']),
    ]);
    var finished = false;
    c = make(speech, onFinished: () => finished = true);
    await c.start();
    expect(finished, isTrue);
    expect(c.phase, StagePhase.finished);
    expect(view.events.where((e) => e.startsWith('show:')).length, 6);
    expect(view.events.where((e) => e.startsWith('correct:')).length, 6);
    expect(view.events.last, 'celebrate:6');
    expect(
      voice.said.where((s) => s.startsWith(VoiceKeys.askNameFromColor)).length,
      6,
    );
    // 효과음이 없으므로 정답마다 이름을 말한다.
    expect(
      voice.said.where((s) => s.startsWith(VoiceKeys.correctSayName)).length,
      6,
    );
    expect(voice.said.last, VoiceKeys.stageClear);
    expect(c.questions.map((s) => s.id).toSet().length, 6);
  });

  test('오답이면 단계식 힌트 후 다시 듣고, 인식 실패면 "다시 말해줄래?" (힌트 단계 그대로)', () async {
    late NameStageController c;
    final speech = ScriptedSpeech([
      () => const SpeechOutcome.noSpeech(),
      () => const SpeechOutcome.recognized(['몰라']),
      () => const SpeechOutcome.error('error_network'),
      () => const SpeechOutcome.recognized(['몰라']),
      () => SpeechOutcome.recognized([c.current!.name]),
    ]);
    c = make(speech);
    unawaited(c.start());
    await pumpEventQueue();
    final first = c.questions.first;
    final relevant = voice.said
        .takeWhile((s) => !s.startsWith(VoiceKeys.correctSayName))
        .toList();
    expect(relevant, [
      '${VoiceKeys.askNameFromColor}(${first.id})',
      '${VoiceKeys.retryListen}(${first.id})',
      '${LineKeys.hintFeature}(${first.id})',
      '${VoiceKeys.retryListen}(${first.id})',
      '${VoiceKeys.hintFirstSyllable}(${first.id})',
    ]);
    expect(c.history.map((r) => r.judgement.verdict.name).toList(), [
      'notRecognized',
      'wrong',
      'notRecognized',
      'wrong',
      'correct',
    ]);
    expect(c.index, 1); // 다음 문제로 넘어감
    c.dispose();
  });

  test('오답은 몇 번이든 계속 다시 듣는다(실패 판정 없음)', () async {
    late NameStageController c;
    final speech = ScriptedSpeech([
      for (var i = 0; i < 10; i++)
        () => const SpeechOutcome.recognized(['강아지']),
      () => SpeechOutcome.recognized([c.current!.name]),
    ]);
    c = make(speech);
    unawaited(c.start());
    await pumpEventQueue();
    // 특징 1번 → 앞글자 1번 → 그다음부터는 계속 "따라 해 볼까?"
    expect(
      voice.said.where((s) => s.startsWith(LineKeys.hintFeature)).length,
      1,
    );
    expect(
      voice.said.where((s) => s.startsWith(VoiceKeys.hintFirstSyllable)).length,
      1,
    );
    expect(
      voice.said.where((s) => s.startsWith(LineKeys.hintSayAndRepeat)).length,
      8,
    );
    expect(c.index, 1);
    c.dispose();
  });

  test('인식 실패가 3번 이어지면 자동 듣기를 멈추고, 마이크를 누르면 다시 듣는다', () async {
    late NameStageController c;
    final speech = ScriptedSpeech([
      () => const SpeechOutcome.noSpeech(),
      () => const SpeechOutcome.noSpeech(),
      () => const SpeechOutcome.noSpeech(),
    ]);
    c = make(speech);
    unawaited(c.start());
    await pumpEventQueue();
    expect(c.phase, StagePhase.waitingForTap);
    expect(speech.listens, 3);
    speech.script.add(() => SpeechOutcome.recognized([c.current!.name]));
    unawaited(c.onMicTap());
    await pumpEventQueue();
    expect(speech.listens, greaterThanOrEqualTo(4));
    expect(c.index, 1);
    c.dispose();
  });

  test('권한 없음(unavailable)이면 바로 기다림 상태', () async {
    final speech = ScriptedSpeech([
      () => const SpeechOutcome.unavailable('error_permission'),
    ]);
    final c = make(speech);
    unawaited(c.start());
    await pumpEventQueue();
    expect(c.phase, StagePhase.waitingForTap);
    expect(voice.said.any((s) => s.startsWith('hint.')), isFalse);
    c.dispose();
  });

  test('듣는 중 그림을 누르면 문제를 다시 말하고 다시 듣는다', () async {
    final speech = ScriptedSpeech([]); // 계속 기다림
    final c = make(speech);
    unawaited(c.start());
    await pumpEventQueue();
    expect(c.phase, StagePhase.listening);
    expect(speech.listens, 1);
    unawaited(c.onPictureTap());
    await pumpEventQueue();
    expect(
      voice.said.where((s) => s.startsWith(VoiceKeys.askNameFromColor)).length,
      2,
    );
    expect(speech.listens, 2);
    expect(c.history, isEmpty); // 취소된 듣기는 기록·판정하지 않음
    c.dispose();
  });

  group('단계식 힌트', () {
    test('오답1 → 특징, 오답2 → 앞글자, 오답3 → 정답 들려주고 따라 하기 → 따라 말하면 정답', () async {
      late NameStageController c;
      final sfx = RecordingSoundEffects();
      final speech = ScriptedSpeech([
        () => const SpeechOutcome.recognized(['몰라']),
        () => const SpeechOutcome.noSpeech(), // 인식 실패: 단계 그대로
        () => const SpeechOutcome.recognized(['강아지']),
        () => const SpeechOutcome.error('e'), // 인식 실패: 단계 그대로
        () => const SpeechOutcome.recognized(['고양이']),
        () => SpeechOutcome.recognized([c.current!.name]), // 따라 말함
      ]);
      c = NameStageController(
        spec: spec,
        pool: pool,
        view: view,
        voice: voice,
        speech: speech,
        sfx: sfx,
        picker: QuestionPicker(random: Random(3)),
      );
      unawaited(c.start());
      await pumpEventQueue();
      final id = c.questions.first.id;
      final upToNext = voice.said
          .takeWhile(
            (s) => !s.startsWith(
              '${VoiceKeys.askNameFromColor}(${c.questions[1].id}',
            ),
          )
          .toList();
      expect(upToNext, [
        '${VoiceKeys.askNameFromColor}($id)',
        '${LineKeys.hintFeature}($id)',
        '${VoiceKeys.retryListen}($id)',
        '${VoiceKeys.hintFirstSyllable}($id)',
        '${VoiceKeys.retryListen}($id)',
        '${LineKeys.hintSayAndRepeat}($id)',
        '${LineKeys.correctAfterRepeat}($id)',
      ]);
      expect(c.index, 1);
      expect(c.results.single.speciesId, id);
      expect(c.results.single.usedHint, isTrue);
      expect(sfx.played.where((n) => n == SfxNames.tryAgain).length, 3);
      expect(sfx.played, contains(SfxNames.correct));
      c.dispose();
    });

    test('인식 실패만 이어지면 힌트를 주지 않고 힌트 사용으로 세지 않는다', () async {
      late NameStageController c;
      final speech = ScriptedSpeech([
        () => const SpeechOutcome.noSpeech(),
        () => const SpeechOutcome.error('e'),
        () => SpeechOutcome.recognized([c.current!.name]),
      ]);
      c = make(speech);
      unawaited(c.start());
      await pumpEventQueue();
      expect(voice.said.any((s) => s.startsWith('hint.')), isFalse);
      expect(c.results.single.usedHint, isFalse);
      c.dispose();
    });

    test('문항이 바뀌면 힌트 단계가 처음으로 돌아간다', () async {
      late NameStageController c;
      final speech = ScriptedSpeech([
        () => const SpeechOutcome.recognized(['몰라']),
        () => const SpeechOutcome.recognized(['몰라']),
        () => SpeechOutcome.recognized([c.current!.name]),
        () => const SpeechOutcome.recognized(['몰라']),
      ]);
      c = make(speech);
      unawaited(c.start());
      await pumpEventQueue();
      final second = c.questions[1].id;
      expect(voice.said.last, '${LineKeys.hintFeature}($second)');
      expect(c.hintStep, HintStep.feature);
      c.dispose();
    });
  });

  test('스테이지 끝: 결과(힌트 사용 여부)를 넘기고 그 뒤에 종료', () async {
    late NameStageController c;
    final speech = ScriptedSpeech([
      () => const SpeechOutcome.recognized(['몰라']), // 1번 문항만 힌트
      for (var i = 0; i < 6; i++)
        () => SpeechOutcome.recognized(['${c.current!.name}야']),
    ]);
    StageResult? got;
    final order = <String>[];
    c = NameStageController(
      spec: spec,
      pool: pool,
      view: view,
      voice: voice,
      speech: speech,
      picker: QuestionPicker(random: Random(3)),
      onStageCleared: (r) async {
        got = r;
        order.add('cleared');
      },
      onFinished: () => order.add('finished'),
    );
    await c.start();
    expect(order, ['cleared', 'finished']);
    expect(got!.worldId, 'animals');
    expect(got!.kind, StageKind.nameFromColor);
    expect(
      got!.results.map((r) => r.speciesId).toList(),
      c.questions.map((s) => s.id).toList(),
    );
    expect(got!.results.map((r) => r.usedHint).toList(), [
      true,
      false,
      false,
      false,
      false,
      false,
    ]);
  });
}
