import 'package:flutter/material.dart';

import '../quiz/name_stage_controller.dart';
import '../services/speech/fake_speech_input.dart';
import '../services/speech/speech_input.dart';

/// 개발자용 오버레이(debug 빌드 전용, 기본 꺼짐). 인식된 문자열과 판정 결과를 보여 준다.
/// 가짜 음성 입력을 쓰는 중이면 정답/오답/무응답/에러 버튼도 보여 준다.
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({
    super.key,
    required this.controller,
    required this.speech,
  });

  final NameStageController controller;
  final SpeechInput speech;

  @override
  Widget build(BuildContext context) {
    final fake = speech is FakeSpeechInput ? speech as FakeSpeechInput : null;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
            ),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final cur = controller.current;
                final recent = controller.history.reversed.take(4).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[DEBUG] ${speech.debugDescription}'),
                    Text(
                      'Q${controller.index + 1}/${controller.questions.length} '
                      '${cur?.id ?? '-'} (${cur?.name ?? '-'})  phase=${controller.phase.name}',
                    ),
                    for (final r in recent) Text(r.toString()),
                    if (fake != null)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final t in const [
                            'correct',
                            'wrong',
                            'none',
                            'error',
                          ])
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => fake.inject(t),
                              child: Text(t),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
