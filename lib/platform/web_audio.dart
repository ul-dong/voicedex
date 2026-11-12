/// 웹 브라우저 음성 기능 확인·마이크 권한(웹에서만 동작, 다른 플랫폼에서는 아무것도 하지 않는다).
library;

export 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio_web.dart';
