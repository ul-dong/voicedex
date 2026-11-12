import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'clip_players.dart';
import 'flutter_tts_speaker.dart';
import 'pack_voice_output.dart';
import 'voice_lines.dart';
import 'voice_pack.dart';
import 'web_tts_speaker.dart';

/// 앱의 음성 출력을 만든다: 녹음 팩(assets/voice/) 우선 + 없으면 TTS.
/// - 앱: audioplayers + flutter_tts
/// - 웹: Web Audio + 브라우저 speechSynthesis
Future<PackVoiceOutput> createVoiceOutput(
  VoiceLines lines, {
  AssetBundle? bundle,
}) async {
  final pack = await VoicePack.load(bundle: bundle);
  final output = PackVoiceOutput(
    lines: lines,
    pack: pack,
    clips: kIsWeb ? WebAudioClipPlayer(pack) : AudioplayersClipPlayer(),
    tts: kIsWeb
        ? WebTtsSpeaker(locale: lines.locale)
        : FlutterTtsSpeaker(locale: lines.locale),
  );
  return output;
}
