import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_audio_stub.dart' show MicPermission;

export 'web_audio_stub.dart' show MicPermission;

bool get webSpeechRecognitionSupported =>
    web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
    web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

bool get webSpeechSynthesisSupported =>
    web.window.hasProperty('speechSynthesis'.toJS).toDart;

/// 재생 버튼을 누른 그 순간(사용자 제스처 안)에 마이크 권한 창을 띄운다.
/// 허용되면 스트림은 바로 닫는다(녹음하지 않음). 실제 인식은 Web Speech API가 따로 마이크를 연다.
Future<MicPermission> requestWebMicrophone() async {
  try {
    final nav = web.window.navigator;
    if (!nav.hasProperty('mediaDevices'.toJS).toDart) {
      return MicPermission.unknown; // http(비보안 출처) 등
    }
    final stream = await nav.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart
        // 권한 창에 답하지 않거나 창이 뜨지 않는 환경(내장 브라우저 등)에서 시작 화면에 갇히지 않게.
        .timeout(const Duration(seconds: 12));
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
    return MicPermission.granted;
  } on TimeoutException {
    debugPrint('[web] getUserMedia: no answer, continuing');
    return MicPermission.unknown;
  } catch (e) {
    debugPrint('[web] getUserMedia failed: $e');
    final s = e.toString();
    if (s.contains('NotAllowed') ||
        s.contains('Permission') ||
        s.contains('NotFound') ||
        s.contains('denied')) {
      return MicPermission.denied;
    }
    return MicPermission.unknown;
  }
}
