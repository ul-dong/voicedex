import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dex_progress.dart';

/// 진행 저장소. 기기 로컬만(앱: NSUserDefaults / SharedPreferences, 웹: localStorage).
abstract class ProgressStore {
  Future<DexProgress> load();
  Future<void> save(DexProgress progress);
}

class SharedPrefsProgressStore implements ProgressStore {
  SharedPrefsProgressStore({this.key = defaultKey});

  static const defaultKey = 'voicedex.progress.v1';
  final String key;

  @override
  Future<DexProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return DexProgress();
      return DexProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // 저장 내용이 깨졌거나 저장소를 못 쓰면 빈 도감으로 시작한다.
      debugPrint('[progress] load failed: $e');
      return DexProgress();
    }
  }

  @override
  Future<void> save(DexProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(progress.toJson()));
    } catch (e) {
      debugPrint('[progress] save failed: $e');
    }
  }
}

/// 테스트·저장 불가 환경용.
class MemoryProgressStore implements ProgressStore {
  String? raw;

  @override
  Future<DexProgress> load() async => raw == null
      ? DexProgress()
      : DexProgress.fromJson(jsonDecode(raw!) as Map<String, dynamic>);

  @override
  Future<void> save(DexProgress progress) async =>
      raw = jsonEncode(progress.toJson());
}

/// 화면들이 같이 보는 도감 상태. 바뀌면 바로 저장한다.
class ProgressController extends ChangeNotifier {
  ProgressController(this._store, this._progress);

  static Future<ProgressController> open(ProgressStore store) async =>
      ProgressController(store, await store.load());

  final ProgressStore _store;
  DexProgress _progress;

  DexProgress get progress => _progress;

  Future<List<StampChange>> applyStage(StageResult result) async {
    final changes = _progress.apply(result);
    notifyListeners();
    await _store.save(_progress);
    return changes;
  }

  Future<void> debugSetTier(
    String worldId,
    String speciesId,
    DexTier tier,
  ) async {
    _progress.debugSetTier(worldId, speciesId, tier);
    notifyListeners();
    await _store.save(_progress);
  }

  /// 개발자 프리셋: empty(빈 도감) / some(앞 5종 열림) / mixed(빈칸·열림·테두리·금테 차례로) / border / gold.
  Future<void> debugPreset(
    String worldId,
    List<String> speciesIds,
    String name,
  ) async {
    _progress = DexProgress();
    for (var i = 0; i < speciesIds.length; i++) {
      final tier = switch (name) {
        'some' => i < 5 ? DexTier.open : DexTier.hidden,
        'mixed' => DexTier.values[i % DexTier.values.length],
        'border' => DexTier.border,
        'gold' => DexTier.gold,
        _ => DexTier.hidden,
      };
      _progress.debugSetTier(worldId, speciesIds[i], tier);
    }
    notifyListeners();
    await _store.save(_progress);
  }

  Future<void> debugReset() async {
    _progress = DexProgress();
    notifyListeners();
    await _store.save(_progress);
  }
}
