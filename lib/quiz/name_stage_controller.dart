import 'dart:async';

import 'package:flutter/foundation.dart';

import '../content/line_keys.dart';
import '../content/species.dart';
import '../content/world_catalog.dart';
import '../progress/dex_progress.dart';
import '../services/sfx/sound_effects.dart';
import '../services/speech/speech_input.dart';
import '../services/voice/voice_line.dart';
import '../services/voice/voice_output.dart';
import 'answer_judge.dart';
import 'hint_ladder.dart';
import 'question_picker.dart';
import 'stage_view.dart';

enum StagePhase {
  idle,

  /// 그림 등장 중.
  presenting,

  /// 안내 음성(문제·힌트·다시 말해줄래)을 말하는 중.
  speaking,

  /// 듣는 중(마이크 반응).
  listening,

  /// 인식 실패가 이어져 자동 듣기를 멈춤. 마이크를 누르면 다시 듣는다.
  waitingForTap,

  /// 정답 연출 중.
  rewarding,

  celebrating,
  finished,
}

/// 개발자 오버레이용 기록 한 줄.
class AttemptRecord {
  AttemptRecord(this.speciesId, this.outcome, this.judgement);

  final String speciesId;
  final SpeechOutcome outcome;
  final Judgement judgement;

  @override
  String toString() => '$speciesId: $outcome → ${judgement.verdict.name}';
}

/// "그림 보고 이름 말하기" 스테이지 진행기(1단계 = 색칠 그림, 3단계 = 그림자에서도 재사용 예정).
///
/// 흐름: 그림 → 문제 음성 → 자동 듣기 → 판정
///   - 정답: 정답 연출(효과음 + 이름 음성) → 다음 문제
///   - 오답: 단계식 힌트([HintLadder]: 특징 → 앞글자 → 정답 듣고 따라 말하기) → 다시 듣기 (무한)
///   - 인식 실패: "다시 말해줄래?" → 다시 듣기. 힌트 단계는 그대로. [maxAutoRetries]번 이어지면 마이크를 누를 때까지 기다림.
///   - 6문항 끝: 축하 → [onStageCleared](도감 찍힘 연출, 진행 저장) → [onFinished]
class NameStageController extends ChangeNotifier {
  NameStageController({
    required this.spec,
    required this.pool,
    required this.view,
    required this.voice,
    required this.speech,
    this.sfx = const NoSoundEffects(),
    this.judge = const AnswerJudge(),
    QuestionPicker? picker,
    this.maxAutoRetries = 3,
    this.onStageCleared,
    this.onFinished,
  }) : picker = picker ?? QuestionPicker();

  final StageSpec spec;
  final List<Species> pool;
  final QuizStageView view;
  final VoiceOutput voice;
  final SpeechInput speech;
  final SoundEffects sfx;
  final AnswerJudge judge;
  final QuestionPicker picker;
  final int maxAutoRetries;

  /// 스테이지를 끝냈을 때(축하 다음) 결과를 넘긴다. 돌려준 Future가 끝나면 [onFinished].
  final Future<void> Function(StageResult result)? onStageCleared;
  final VoidCallback? onFinished;

  List<Species> _questions = const [];
  int _index = 0;
  int _epoch = 0;
  int _failStreak = 0;
  StagePhase _phase = StagePhase.idle;
  bool _disposed = false;
  final HintLadder _hints = HintLadder();
  final List<QuestionResult> _results = [];
  final List<AttemptRecord> history = [];

  /// 지금 문항의 힌트 단계(개발자 오버레이용).
  HintStep get hintStep => _hints.step;

  /// 지금까지 맞힌 문항(힌트 사용 여부 포함).
  List<QuestionResult> get results => List.unmodifiable(_results);

  List<Species> get questions => _questions;
  int get index => _index;
  StagePhase get phase => _phase;
  Species? get current =>
      _index < _questions.length ? _questions[_index] : null;

  String get _askKey => switch (spec.kind) {
    StageKind.nameFromColor => VoiceKeys.askNameFromColor,
    _ => throw UnimplementedError('stage ${spec.kind} not implemented'),
  };

  Future<void> start() async {
    _questions = picker.pick(pool, spec.questionCount);
    _index = 0;
    _results.clear();
    history.clear();
    debugPrint('[stage] questions ${_questions.map((s) => s.id).toList()}');
    await _beginQuestion();
  }

  /// 그림을 누르면 문제를 다시 말해 주고 다시 듣는다.
  Future<void> onPictureTap() async {
    if (!_interruptible) return;
    final e = await _interrupt();
    await _askThenListen(e);
  }

  /// 마이크를 누르면 바로 다시 듣는다.
  Future<void> onMicTap() async {
    if (!_interruptible) return;
    final e = await _interrupt();
    await _listen(e);
  }

  bool get _interruptible => switch (_phase) {
    StagePhase.speaking ||
    StagePhase.listening ||
    StagePhase.waitingForTap => true,
    _ => false,
  };

  Future<int> _interrupt() async {
    final e = ++_epoch;
    _failStreak = 0;
    await speech.cancel();
    await voice.stop();
    return e;
  }

  Future<void> _beginQuestion() async {
    final e = ++_epoch;
    _failStreak = 0;
    _hints.reset();
    final s = current!;
    _setPhase(StagePhase.presenting);
    await view.showQuestion(s, _index, _questions.length);
    if (e != _epoch) return;
    await _askThenListen(e);
  }

  Future<void> _askThenListen(int e) async {
    _setPhase(StagePhase.speaking);
    await voice.say(VoiceLine(_askKey, species: current));
    if (e != _epoch) return;
    await _listen(e);
  }

  Future<void> _say(VoiceLine line) async {
    _setPhase(StagePhase.speaking);
    await voice.say(line);
  }

  Future<void> _listen(int e) async {
    final target = current!;
    _setPhase(StagePhase.listening);
    final outcome = await speech.listenOnce(
      acceptPartial: (partial) =>
          judge.judgeText(partial, target).verdict == Verdict.correct,
    );
    if (e != _epoch) return;
    final j = judge.judge(outcome, target);
    history.add(AttemptRecord(target.id, outcome, j));
    debugPrint('[stage] ${target.id} $outcome -> $j');
    notifyListeners();

    switch (j.verdict) {
      case Verdict.correct:
        await _onCorrect(e, target);
      case Verdict.wrong:
        _failStreak = 0;
        final step = _hints.onWrong();
        _setPhase(StagePhase.speaking);
        await sfx.play(SfxNames.tryAgain);
        if (e != _epoch) return;
        await _say(VoiceLine(hintKey(step), species: target));
        if (e != _epoch) return;
        await _listen(e);
      case Verdict.notRecognized:
        _hints.onNotRecognized();
        if (outcome.kind == SpeechOutcomeKind.unavailable) {
          _setPhase(StagePhase.waitingForTap);
          return;
        }
        _failStreak++;
        if (_failStreak >= maxAutoRetries) {
          _failStreak = 0;
          _setPhase(StagePhase.waitingForTap);
          return;
        }
        await _say(VoiceLine(VoiceKeys.retryListen, species: target));
        if (e != _epoch) return;
        await _listen(e);
    }
  }

  /// 힌트 단계 → 대사 키.
  static String hintKey(HintStep step) => switch (step) {
    HintStep.feature => LineKeys.hintFeature,
    HintStep.firstSyllable => VoiceKeys.hintFirstSyllable,
    HintStep.sayAndRepeat || HintStep.none => LineKeys.hintSayAndRepeat,
  };

  Future<void> _onCorrect(int e, Species s) async {
    _setPhase(StagePhase.rewarding);
    _results.add(QuestionResult(s.id, usedHint: _hints.usedHint));
    final repeated = _hints.step == HintStep.sayAndRepeat;
    final anim = view.playCorrect(s);
    await sfx.play(SfxNames.correct);
    final played = await sfx.playCorrect(s);
    if (!played || repeated) {
      await voice.say(
        VoiceLine(
          repeated ? LineKeys.correctAfterRepeat : VoiceKeys.correctSayName,
          species: s,
        ),
      );
    }
    await anim;
    if (e != _epoch) return;
    _index++;
    if (_index < _questions.length) {
      await _beginQuestion();
    } else {
      await _celebrate(e);
    }
  }

  Future<void> _celebrate(int e) async {
    _setPhase(StagePhase.celebrating);
    unawaited(sfx.play(SfxNames.fanfare));
    await Future.wait([
      view.celebrate(_questions),
      voice.say(const VoiceLine(VoiceKeys.stageClear)),
    ]);
    if (e != _epoch) return;
    final cleared = onStageCleared;
    if (cleared != null) {
      await cleared(
        StageResult(
          worldId: spec.world.id,
          kind: spec.kind,
          results: List.unmodifiable(_results),
        ),
      );
      if (e != _epoch) return;
    }
    _setPhase(StagePhase.finished);
    onFinished?.call();
  }

  void _setPhase(StagePhase p) {
    if (_disposed) return;
    _phase = p;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    unawaited(speech.cancel());
    unawaited(voice.stop());
    super.dispose();
  }
}
