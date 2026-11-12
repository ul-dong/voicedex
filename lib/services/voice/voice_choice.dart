/// 기기 음성(TTS) 고르기·톤. 알록달록 `audio_service.dart`의 규칙을 그대로 옮겼다.
library;

/// 목소리 이름으로 점수를 매긴다(높을수록 우선). 부드러운 여성·neural 음성 우선, 남성 음성은 피한다.
int voiceScore(String name) {
  final n = name.toLowerCase();
  const preferred = [
    'sunhi', // Edge 자연스러운 여성 음성
    'google 한국', 'google korean', // Chrome 여성 음성
    'yuna', // iOS/macOS 여성 음성
    'ko-kr-x-ism', 'ko-kr-x-kob', // Android Google 여성 음성
    'heami', // Windows 여성 음성
    'female', 'sora', 'jimin', 'seoyeon',
  ];
  const avoid = [
    'injoon',
    'hyunsu',
    'bongjin',
    'gookmin',
    'ko-kr-x-koc',
    'ko-kr-x-kod',
    'male',
  ];
  for (var i = 0; i < preferred.length; i++) {
    if (n.contains(preferred[i])) return 100 - i;
  }
  for (final a in avoid) {
    if (n.contains(a) && !n.contains('female')) return -10;
  }
  return n.contains('natural') || n.contains('neural') ? 20 : 0;
}

/// TTS 톤. 음높이는 올리지 않는다(기계음이 일그러져 오히려 무섭게 들린다 — 알록달록의 교훈).
/// 속도 단위가 플랫폼마다 다르다: 웹 1.0 = 보통, 모바일(flutter_tts) 0.5 = 보통.
({double pitch, double rate}) ttsTone({required bool web}) =>
    (pitch: 1.0, rate: web ? 0.9 : 0.44);

/// 문장 길이에 비례한 안전 시간: 엔진이 끝을 알리지 않아도 이 시간 뒤엔 돌아온다.
Duration speakGuard(String text) =>
    Duration(milliseconds: 3000 + 250 * text.length);
