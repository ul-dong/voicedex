/// 웹 브라우저 음성 합성(speechSynthesis). 웹이 아닌 플랫폼에서는 쓰지 않는다.
library;

export 'web_tts_speaker_stub.dart'
    if (dart.library.js_interop) 'web_tts_speaker_web.dart';
