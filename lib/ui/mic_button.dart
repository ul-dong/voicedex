import 'dart:async';

import 'package:flutter/material.dart';

import '../quiz/name_stage_controller.dart';

/// 마이크 버튼. 듣는 중엔 밝은 색 + 음량에 따라 커지는 고리, 기다리는 중엔 천천히 숨쉬듯 커졌다 작아짐.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.phase,
    required this.soundLevel,
    required this.onTap,
    this.size = 120,
  });

  final StagePhase phase;
  final Stream<double> soundLevel;
  final VoidCallback onTap;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  StreamSubscription<double>? _sub;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.soundLevel.listen((v) {
      if (mounted) setState(() => _level = _level * 0.5 + v * 0.5);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.phase == StagePhase.listening;
    final waiting = widget.phase == StagePhase.waitingForTap;
    final busy = !listening && !waiting;
    final s = widget.size;
    final color = listening
        ? const Color(0xFFE76F6F)
        : waiting
        ? const Color(0xFFF2B45C)
        : const Color(0xFFD9CFC4);
    return Semantics(
      button: true,
      label: '다시 듣기',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: s * 1.9,
          height: s * 1.9,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, child) {
              final t = _ring.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (listening) ...[
                    // 퍼져 나가는 고리 2개
                    for (final phase in const [0.0, 0.5])
                      _ringCircle(
                        s * (1 + ((t + phase) % 1) * 0.8),
                        color.withValues(alpha: 0.35 * (1 - (t + phase) % 1)),
                      ),
                    // 음량 고리
                    _ringCircle(
                      s * (1.05 + _level * 0.5),
                      color.withValues(alpha: 0.35),
                    ),
                  ],
                  if (waiting)
                    _ringCircle(
                      s * (1.1 + 0.15 * (0.5 - (t - 0.5).abs()) * 2),
                      color.withValues(alpha: 0.3),
                    ),
                  child!,
                ],
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: busy
                    ? const []
                    : const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: Icon(
                Icons.mic_rounded,
                size: s * 0.58,
                color: Colors.white.withValues(alpha: busy ? 0.75 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ringCircle(double d, Color c) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
