import 'dart:convert';

import 'package:flutter/services.dart';

import '../../content/line_template.dart';
import 'voice_line.dart';

/// 대사 키 → 문장 표.
///
/// 문장 안의 자리 표시(`{name}`, `{hint}`, `{feature}`, `{name:이/가}` …)는 [LineTemplate] 규칙으로 채운다
/// (`assets/data/voice_lines_ko.json`의 `template_rules`). 녹음 대본([allVoiceSentences])도 같은 규칙을 쓰므로
/// 앱이 말하는 문장과 녹음 매니페스트의 문장이 글자 하나까지 같다.
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

  /// 대사를 문장으로 바꾼다.
  String render(VoiceLine line) {
    final template = lines[line.key];
    if (template == null) {
      throw StateError('voice line "${line.key}" not found');
    }
    return LineTemplate.expand(template, line.species);
  }
}
