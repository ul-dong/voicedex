import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 미리 녹음한 목소리 팩: 통문장 → 파일 이름(`assets/voice/manifest.json`).
///
/// 문장 하나가 녹음 하나다. 조각을 이어 붙이지 않는다(이음새에서 억양이 끊기기 때문 — 알록달록의 교훈).
/// 파일 번호(vNNNN.mp3)는 한 번 정해지면 바뀌지 않는다(tools/voice/export_lines_test.dart).
class VoicePack {
  VoicePack(Map<String, String> files)
    : _files = Map.unmodifiable(files),
      _loose = {for (final e in files.entries) _normalize(e.key): e.value};

  static const manifestAsset = 'assets/voice/manifest.json';
  static const assetDir = 'assets/voice/';

  final Map<String, String> _files;
  final Map<String, String> _loose;

  bool get isEmpty => _files.isEmpty;
  int get length => _files.length;

  /// 모든 녹음 파일 이름.
  Iterable<String> get files => _files.values.toSet();

  /// 파일 이름 → 에셋 키.
  static String assetKey(String file) => '$assetDir$file';

  /// 앞뒤 공백·여러 칸 띄어쓰기 차이는 같은 문장으로 본다. 문장부호는 억양이 달라지므로 구별한다.
  static String _normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// 문장의 녹음 파일. 없으면 null(→ TTS로 대신 말한다).
  String? lookup(String sentence) =>
      _files[sentence] ?? _loose[_normalize(sentence)];

  factory VoicePack.fromJson(Object? json) {
    if (json is! Map) return VoicePack(const {});
    return VoicePack({
      for (final e in json.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    });
  }

  /// 매니페스트를 읽는다. 없거나 깨졌으면 빈 팩(전부 TTS).
  static Future<VoicePack> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(manifestAsset);
      return VoicePack.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('[voice] no voice pack: $e');
      return VoicePack(const {});
    }
  }
}
