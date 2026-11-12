import 'dart:convert';

import 'package:flutter/services.dart';

import 'voice_line.dart';

/// 대사 키 → 문장 표.
class VoiceLines {
  const VoiceLines({required this.locale, required this.lines});

  final String locale;
  final Map<String, String> lines;

  static const defaultAsset = 'assets/data/voice_lines_ko.json';

  factory VoiceLines.fromJson(Map<String, dynamic> json) => VoiceLines(
    locale: json['locale'] as String,
    lines: (json['lines'] as Map<String, dynamic>).cast<String, String>(),
  );

  static Future<VoiceLines> load({
    AssetBundle? bundle,
    String asset = defaultAsset,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    return VoiceLines.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 대사를 문장으로 바꾼다. `{name}`→표시 이름, `{hint}`→첫 음절.
  String render(VoiceLine line) {
    final template = lines[line.key];
    if (template == null) {
      throw StateError('voice line "${line.key}" not found');
    }
    final s = line.species;
    return template
        .replaceAll('{name}', s?.name ?? '')
        .replaceAll('{hint}', s?.hint ?? '');
  }
}
