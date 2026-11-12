import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicedex/content/world_catalog.dart';
import 'package:voicedex/progress/dex_progress.dart';
import 'package:voicedex/progress/progress_store.dart';

StageResult stage(StageKind kind, Map<String, bool> hinted) => StageResult(
  worldId: 'animals',
  kind: kind,
  results: [
    for (final e in hinted.entries) QuestionResult(e.key, usedHint: e.value),
  ],
);

void main() {
  group('도감 단계 규칙', () {
    test('처음엔 전부 그림자(hidden)', () {
      final p = DexProgress();
      expect(p.tier('animals', 'elephant'), DexTier.hidden);
      expect(p.metCount('animals'), 0);
    });

    test('1단계: 힌트를 써도 칸은 똑같이 열린다. 단계 표시만 힌트 없는 종에 붙는다', () {
      final p = DexProgress();
      final changes = p.apply(
        stage(StageKind.nameFromColor, {'elephant': false, 'bear': true}),
      );
      expect(p.tier('animals', 'elephant'), DexTier.open);
      expect(p.tier('animals', 'bear'), DexTier.open);
      expect(p.entry('animals', 'elephant').marks, {StageKind.nameFromColor});
      // 힌트 쓴 문항: 표시가 "아직 없음"일 뿐, 실패 기록은 없다.
      expect(p.entry('animals', 'bear').marks, isEmpty);
      expect(changes.every((c) => c.isNew), isTrue);
      expect(p.metCount('animals'), 2);
    });

    test('2단계 힌트 없이 → 테두리, 3단계 힌트 없이 → 금테', () {
      final p = DexProgress()
        ..apply(stage(StageKind.nameFromColor, {'lion': false}));
      final c2 = p.apply(stage(StageKind.matchShadow, {'lion': false}));
      expect(p.tier('animals', 'lion'), DexTier.border);
      expect(c2.single.upgraded, isTrue);
      expect(c2.single.isNew, isFalse);
      p.apply(stage(StageKind.nameFromShadow, {'lion': false}));
      expect(p.tier('animals', 'lion'), DexTier.gold);
    });

    test('2·3단계에서 힌트를 쓰면 테두리·금테가 붙지 않고, 그대로 열린 칸으로 남는다', () {
      final p = DexProgress()
        ..apply(stage(StageKind.nameFromColor, {'camel': false}));
      final c = p.apply(stage(StageKind.matchShadow, {'camel': true}));
      expect(p.tier('animals', 'camel'), DexTier.open);
      expect(c.single.upgraded, isFalse);
      p.apply(stage(StageKind.nameFromShadow, {'camel': true}));
      expect(p.tier('animals', 'camel'), DexTier.open);
      // 나중에 힌트 없이 맞히면 그때 받는다.
      p.apply(stage(StageKind.matchShadow, {'camel': false}));
      expect(p.tier('animals', 'camel'), DexTier.border);
    });

    test('이미 받은 표시는 나중에 힌트를 써도 내려가지 않는다', () {
      final p = DexProgress()
        ..apply(stage(StageKind.nameFromColor, {'hippo': false}))
        ..apply(stage(StageKind.matchShadow, {'hippo': false}))
        ..apply(stage(StageKind.matchShadow, {'hippo': true}))
        ..apply(stage(StageKind.nameFromColor, {'hippo': true}));
      expect(p.tier('animals', 'hippo'), DexTier.border);
    });

    test('개발자 강제 단계', () {
      final p = DexProgress();
      for (final t in DexTier.values) {
        p.debugSetTier('animals', 'rhino', t);
        expect(p.tier('animals', 'rhino'), t);
      }
    });
  });

  group('진행 저장/불러오기', () {
    test('JSON 왕복', () {
      final p = DexProgress()
        ..apply(
          stage(StageKind.nameFromColor, {'elephant': false, 'bear': true}),
        )
        ..apply(stage(StageKind.nameFromShadow, {'elephant': false}));
      final back = DexProgress.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(back.tier('animals', 'elephant'), DexTier.gold);
      expect(back.tier('animals', 'bear'), DexTier.open);
      expect(back.entry('animals', 'bear').marks, isEmpty);
      expect(back.tier('animals', 'lion'), DexTier.hidden);
    });

    test('깨진 저장 내용은 빈 도감', () {
      expect(DexProgress.fromJson({'worlds': 3}).metCount('animals'), 0);
      expect(
        DexProgress.fromJson({
          'worlds': {
            'animals': {
              'lion': 'x',
              'bear': {
                'met': true,
                'marks': ['zzz'],
              },
            },
          },
        }).tier('animals', 'bear'),
        DexTier.open,
      );
    });

    test('shared_preferences 저장소: 저장 후 새로 열어도 그대로', () async {
      SharedPreferences.setMockInitialValues({});
      final c1 = await ProgressController.open(SharedPrefsProgressStore());
      await c1.applyStage(
        stage(StageKind.nameFromColor, {'penguin': false, 'monkey': true}),
      );
      final c2 = await ProgressController.open(SharedPrefsProgressStore());
      expect(c2.progress.tier('animals', 'penguin'), DexTier.open);
      expect(c2.progress.entry('animals', 'penguin').marks, {
        StageKind.nameFromColor,
      });
      expect(c2.progress.tier('animals', 'monkey'), DexTier.open);
      expect(c2.progress.metCount('animals'), 2);
    });

    test('저장 내용이 JSON이 아니면 빈 도감으로 시작', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsProgressStore.defaultKey: '{not json',
      });
      final c = await ProgressController.open(SharedPrefsProgressStore());
      expect(c.progress.metCount('animals'), 0);
    });

    test('메모리 저장소 + 개발자 프리셋', () async {
      final store = MemoryProgressStore();
      final c = await ProgressController.open(store);
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      await c.debugPreset('animals', ids, 'mixed');
      final again = await ProgressController.open(store);
      expect(
        [for (final id in ids) again.progress.tier('animals', id)],
        [
          DexTier.hidden,
          DexTier.open,
          DexTier.border,
          DexTier.gold,
          DexTier.hidden,
          DexTier.open,
          DexTier.border,
          DexTier.gold,
        ],
      );
    });
  });
}
