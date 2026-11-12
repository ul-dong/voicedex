import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';

import '../content/species.dart';
import '../quiz/stage_view.dart';
import 'components/confetti.dart';
import 'components/species_picture.dart';
import 'svg_picture_cache.dart';

/// 퀴즈 장면(Flame). 그림 컴포넌트와 정답·축하 연출을 맡는다. 버튼은 Flutter 위젯으로 위에 얹는다.
class QuizGame extends FlameGame implements QuizStageView {
  QuizGame({required this.pictures, this.onPictureTap, Random? random})
    : _random = random ?? Random();

  final SvgPictureCache pictures;
  VoidCallback? onPictureTap;
  final Random _random;

  SpeciesPicture? _current;
  final List<Component> _celebration = [];

  static const background = Color(0xFFFFF6E5);

  @override
  Color backgroundColor() => background;

  /// 그림 크기와 발밑 위치. 아래쪽 마이크 버튼 자리를 남긴다.
  double get _side => min(size.x * 0.82, size.y * 0.56);
  Vector2 get _feet => Vector2(size.x / 2, size.y * 0.70);

  Future<void> preload(Iterable<Species> species) async {
    for (final s in species) {
      await pictures.load(s.colorImage);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final c = _current;
    if (c != null && c.isMounted) {
      c
        ..size = Vector2.all(_side)
        ..position = _feet;
    }
  }

  Future<void> _runEffect(Component target, Effect effect) {
    final done = Completer<void>();
    effect.onComplete = () {
      if (!done.isCompleted) done.complete();
    };
    target.add(effect);
    // 컴포넌트가 화면에서 빠지면 효과가 끝나지 않을 수 있어 안전 시간 둠.
    return done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  @override
  Future<void> showQuestion(Species species, int index, int total) async {
    _clearCelebration();
    final old = _current;
    if (old != null) {
      await _runEffect(
        old,
        MoveByEffect(
          Vector2(-size.x, 0),
          EffectController(duration: 0.35, curve: Curves.easeIn),
        ),
      );
      old.removeFromParent();
    }
    final info = await pictures.load(species.colorImage);
    final pic = SpeciesPicture(
      picture: info,
      side: _side,
      position: _feet,
      onTap: () => onPictureTap?.call(),
    )..scale = Vector2.all(0.3);
    _current = pic;
    await add(pic);
    await _runEffect(
      pic,
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: 0.55, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  Future<void> playCorrect(Species species) async {
    final pic = _current;
    if (pic == null) return;
    add(
      sparkleBurst(
        pic.position - Vector2(0, pic.size.y * 0.5),
        random: _random,
      ),
    );
    final hop = _runEffect(
      pic,
      SequenceEffect([
        // 웅크렸다가
        ScaleEffect.to(
          Vector2(1.08, 0.9),
          EffectController(duration: 0.12, curve: Curves.easeOut),
        ),
        // 튀어올라 늘어나고
        ScaleEffect.to(
          Vector2(0.94, 1.08),
          EffectController(duration: 0.18, curve: Curves.easeOut),
        ),
        // 착지
        ScaleEffect.to(
          Vector2(1.06, 0.94),
          EffectController(duration: 0.14, curve: Curves.easeIn),
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.2, curve: Curves.elasticOut),
        ),
      ]),
    );
    final jump = _runEffect(
      pic,
      SequenceEffect([
        MoveByEffect(Vector2(0, 0), EffectController(duration: 0.12)),
        MoveByEffect(
          Vector2(0, -_side * 0.18),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
        MoveByEffect(
          Vector2(0, _side * 0.18),
          EffectController(duration: 0.18, curve: Curves.easeIn),
        ),
      ]),
    );
    final wiggle = _runEffect(
      pic,
      SequenceEffect([
        RotateEffect.by(0.12, EffectController(duration: 0.1, startDelay: 0.5)),
        RotateEffect.by(-0.24, EffectController(duration: 0.16)),
        RotateEffect.by(0.12, EffectController(duration: 0.1)),
      ]),
    );
    await Future.wait([hop, jump, wiggle]);
    pic
      ..angle = 0
      ..position = _feet
      ..scale = Vector2.all(1);
  }

  @override
  Future<void> celebrate(List<Species> met) async {
    final old = _current;
    _current = null;
    if (old != null) {
      await _runEffect(
        old,
        ScaleEffect.to(
          Vector2.all(0.01),
          EffectController(duration: 0.3, curve: Curves.easeIn),
        ),
      );
      old.removeFromParent();
    }
    // 만난 동물들을 두 줄로 세워 차례로 콩콩 뛰게 한다.
    final perRow = (met.length / 2).ceil();
    final cell = min(size.x / (perRow + 0.4), size.y * 0.26);
    for (var i = 0; i < met.length; i++) {
      final row = i ~/ perRow;
      final col = i % perRow;
      final rowCount = row == 0 ? perRow : met.length - perRow;
      final x = size.x / 2 + (col - (rowCount - 1) / 2) * cell;
      final y = size.y * 0.40 + row * cell * 1.05;
      final info = await pictures.load(met[i].colorImage);
      final pic = SpeciesPicture(
        picture: info,
        side: cell * 0.95,
        position: Vector2(x, y),
      )..scale = Vector2.all(0.01);
      _celebration.add(pic);
      await add(pic);
      pic.add(
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: 0.4,
            startDelay: i * 0.12,
            curve: Curves.elasticOut,
          ),
        ),
      );
      pic.add(
        MoveByEffect(
          Vector2(0, -cell * 0.16),
          EffectController(
            duration: 0.22,
            reverseDuration: 0.22,
            startDelay: 0.6 + i * 0.15,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
            repeatCount: 4,
          ),
        ),
      );
    }
    final rain = confettiRain(size, random: _random);
    _celebration.add(rain);
    add(rain);
    await Future<void>.delayed(const Duration(milliseconds: 3600));
  }

  void _clearCelebration() {
    for (final c in _celebration) {
      c.removeFromParent();
    }
    _celebration.clear();
  }
}
