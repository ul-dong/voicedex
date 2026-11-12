import 'dart:async';

import 'package:flutter/foundation.dart';

import '../content/species.dart';
import '../content/world_catalog.dart';
import '../services/sfx/sound_effects.dart';
import '../services/speech/speech_input.dart';
import '../services/voice/voice_line.dart';
import '../services/voice/voice_output.dart';
import 'answer_judge.dart';
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
///   - 정답: 정답 연출(효과음, 없으면 이름 음성) → 다음 문제
///   - 오답: 첫 음절 힌트 음성 → 다시 듣기 (무한)
///   - 인식 실패: "다시 말해줄래?" → 다시 듣기. [maxAutoRetries]번 이어지면 마이크를 누를 때까지 기다림.
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
  final VoidCallback? onFinished;

  List<Species> _questions = const [];
  int _index = 0;
  int _epoch = 0;
  int _failStreak = 0;
  StagePhase _phase = StagePhase.idle;
  bool _disposed = false;
  final List<AttemptRecord> history = [];

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
        await _say(VoiceLine(VoiceKeys.hintFirstSyllable, species: target));
        if (e != _epoch) return;
        await _listen(e);
      case Verdict.notRecognized:
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

  Future<void> _onCorrect(int e, Species s) async {
    _setPhase(StagePhase.rewarding);
    final anim = view.playCorrect(s);
    final played = await sfx.playCorrect(s);
    if (!played) {
      await voice.say(VoiceLine(VoiceKeys.correctSayName, species: s));
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
    await Future.wait([
      view.celebrate(_questions),
      voice.say(const VoiceLine(VoiceKeys.stageClear)),
    ]);
    if (e != _epoch) return;
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
