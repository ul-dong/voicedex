import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/app_config.dart';
import '../app/app_services.dart';
import '../content/line_keys.dart';
import '../content/species.dart';
import '../content/world_catalog.dart';
import '../game/quiz_game.dart';
import '../game/svg_picture_cache.dart';
import '../progress/dex_progress.dart';
import '../quiz/name_stage_controller.dart';
import '../quiz/question_picker.dart';
import '../services/speech/fake_speech_input.dart';
import '../services/voice/voice_line.dart';
import 'debug_overlay.dart';
import 'mic_button.dart';
import 'stamp_overlay.dart';

/// 1단계 퀴즈 화면: Flame 장면 + 마이크 버튼(Flutter) + 개발자 오버레이(debug 전용).
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.services,
    required this.spec,
    required this.pool,
  });

  final AppServices services;
  final StageSpec spec;
  final List<Species> pool;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _pictures = SvgPictureCache();
  late final QuizGame _game = QuizGame(pictures: _pictures);
  late final NameStageController _controller;
  bool _overlay = AppConfig.debugOverlayInitiallyOn;

  /// 스테이지 끝 도감 찍힘 연출(보상 2층).
  _StampData? _stamp;

  @override
  void initState() {
    super.initState();
    _controller = NameStageController(
      spec: widget.spec,
      pool: widget.pool,
      view: _game,
      voice: widget.services.voice,
      speech: widget.services.speech,
      sfx: widget.services.sfx,
      picker: QuestionPicker.dexAware(
        isMet: (sp) => widget.services.progress.progress.isMet(
          widget.spec.world.id,
          sp.id,
        ),
      ),
      onStageCleared: _onStageCleared,
      onFinished: () {
        if (mounted) Navigator.of(context).maybePop();
      },
    );
    _game.onPictureTap = _controller.onPictureTap;
    final speech = widget.services.speech;
    if (speech is FakeSpeechInput) {
      speech.correctText = () => '${_controller.current?.name ?? ''}야';
      speech.wrongText = () {
        final cur = _controller.current;
        return widget.pool.firstWhere((s) => s.id != cur?.id).name;
      };
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  /// 결과를 도감에 반영·저장하고, 맞힌 종이 도감 칸으로 날아가 찍히는 연출을 보여 준다.
  Future<void> _onStageCleared(StageResult result) async {
    final services = widget.services;
    final worldId = widget.spec.world.id;
    final before = {
      for (final sp in widget.pool)
        sp.id: services.progress.progress.tier(worldId, sp.id),
    };
    final changes = await services.progress.applyStage(result);
    debugPrint('[stage] stamped $changes');
    if (!mounted) return;
    final done = Completer<void>();
    setState(() => _stamp = _StampData(before, changes, done));
    await done.future;
  }

  Future<void> _begin() async {
    await _game.loaded;
    await _game.preload(widget.pool);
    if (!mounted) return;
    await _controller.start();
  }

  @override
  void dispose() {
    final stamp = _stamp;
    if (stamp != null && !stamp.done.isCompleted) stamp.done.complete();
    _controller.dispose();
    _pictures.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return Scaffold(
      backgroundColor: QuizGame.background,
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              child: Center(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: switch (_controller.phase) {
                      StagePhase.celebrating || StagePhase.finished => 0,
                      _ => 1,
                    },
                    child: MicButton(
                      phase: _controller.phase,
                      soundLevel: widget.services.speech.soundLevel,
                      onTap: _controller.onMicTap,
                      size: shortest * 0.24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_stamp case final stamp?)
            Positioned.fill(
              child: StampOverlay(
                species: widget.pool,
                before: stamp.before,
                changes: stamp.changes,
                onStamp: (c) {
                  unawaited(widget.services.sfx.play(SfxNames.stamp));
                  if (c.isNew) {
                    unawaited(widget.services.sfx.play(SfxNames.unlock));
                  }
                },
                onAllStamped: () => widget.services.voice.say(
                  VoiceLine(
                    stamp.changes.any((c) => c.isNew)
                        ? LineKeys.rewardNewFriends
                        : LineKeys.rewardDexStamped,
                  ),
                ),
                onDone: () {
                  if (!stamp.done.isCompleted) stamp.done.complete();
                },
              ),
            ),
          if (AppConfig.debugOverlayAvailable) ...[
            // 오른쪽 위 구석을 길게 누르면 개발자 오버레이 켜기/끄기 (debug 빌드 전용).
            Positioned(
              top: 0,
              right: 0,
              width: 72,
              height: 72,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () => setState(() => _overlay = !_overlay),
              ),
            ),
            if (_overlay)
              DebugOverlay(
                controller: _controller,
                speech: widget.services.speech,
              ),
          ],
        ],
      ),
    );
  }
}

class _StampData {
  _StampData(this.before, this.changes, this.done);
  final Map<String, DexTier> before;
  final List<StampChange> changes;
  final Completer<void> done;
}
