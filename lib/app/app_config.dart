import 'package:flutter/foundation.dart';

import '../content/species.dart';
import '../progress/progress_store.dart';

/// 빌드 설정. `--dart-define`으로 바꾼다(README 참고). 디버그 기능은 release 빌드에서 전부 꺼진다.
///
/// 예외: 웹(내부 테스트용) 빌드는 URL 파라미터로 켠다. `?debug=1`이 없으면 꺼져 있다.
/// - `?debug=1` 개발자 오버레이(켜진 채 시작, 오른쪽 위 길게 눌러 끄기/켜기)
/// - `?debug=1&fake=1` 가짜 음성 입력(오버레이 버튼)
/// - `?debug=1&script=none,wrong,correct,...` 가짜 음성 대본(자동 진행)
/// - `?debug=1&dex=empty|some|mixed|gold` 시작할 때 도감 상태를 강제로 바꿈(저장됨)
/// - `?debug=1&overlay=0` 개발자 오버레이를 꺼진 채 시작(길게 눌러 켜기)
class AppConfig {
  AppConfig._();

  /// 개발자 오버레이를 켠 채로 시작 (debug 빌드 전용).
  static const bool _overlayRequested = bool.fromEnvironment(
    'VOICEDEX_DEBUG_OVERLAY',
  );

  /// 가짜 음성 입력 사용 (debug 빌드 전용).
  static const bool _fakeRequested = bool.fromEnvironment(
    'VOICEDEX_FAKE_SPEECH',
  );

  /// 가짜 음성 입력 대본. 쉼표로 구분: correct,wrong,none,error 또는 임의 문자열.
  static const String _fakeScript = String.fromEnvironment(
    'VOICEDEX_FAKE_SCRIPT',
  );

  /// 웹 URL 파라미터(웹이 아니면 빈 값).
  static Map<String, String> get _webParams =>
      kIsWeb ? Uri.base.queryParameters : const {};

  /// 웹에서 `?debug=1`.
  static bool get webDebug => kIsWeb && _webParams['debug'] == '1';

  static String get _webScript => webDebug ? (_webParams['script'] ?? '') : '';

  static bool get debugOverlayAvailable => kDebugMode || webDebug;
  static bool get debugOverlayInitiallyOn =>
      (kDebugMode && _overlayRequested) ||
      (webDebug && _webParams['overlay'] != '0');

  /// 도감 상태 강제 프리셋(debug 빌드의 `--dart-define=VOICEDEX_DEX=mixed` 또는 웹 `?debug=1&dex=mixed`).
  static const String _dexPreset = String.fromEnvironment('VOICEDEX_DEX');

  static String get dexPreset =>
      webDebug ? (_webParams['dex'] ?? '') : (kDebugMode ? _dexPreset : '');

  /// 프리셋 이름은 [ProgressController.debugPreset] 참고(empty/some/mixed/border/gold).
  static Future<void> applyDebugDexPreset(
    ProgressController progress,
    List<Species> animals,
  ) async {
    final preset = dexPreset;
    if (preset.isEmpty) return;
    await progress.debugPreset('animals', [
      for (final s in animals) s.id,
    ], preset);
  }

  static bool get useFakeSpeech =>
      (kDebugMode && (_fakeRequested || _fakeScript.isNotEmpty)) ||
      (webDebug && (_webParams['fake'] == '1' || _webScript.isNotEmpty));

  static List<String> get fakeScript =>
      (_webScript.isNotEmpty ? _webScript : _fakeScript)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);

  /// 기기 내 음성 인식만 허용(iOS: requiresOnDeviceRecognition). README 개인정보 절 참고.
  /// 웹에는 적용되지 않는다(브라우저 Web Speech API — 크롬은 Google 서버로 보낸다. 웹은 내부 테스트 전용).
  static const bool onDeviceRecognitionOnly = true;

  static const String speechLocale = 'ko_KR';

  /// 웹 Speech API는 BCP 47 형식(하이픈)을 쓴다.
  static String get speechLocaleForPlatform =>
      kIsWeb ? speechLocale.replaceAll('_', '-') : speechLocale;
}
