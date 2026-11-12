import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/svg_clip_fix.dart';

/// 시작 화면: 큰 재생 버튼 하나(글자 없음).
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.onPlay});

  final Future<void> Function() onPlay;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  bool _busy = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPlay();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final buttonSize = shortest * 0.42;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E5),
      body: SafeArea(
        child: Stack(
          children: [
            // 장식용 동물 그림(누를 수 없음).
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final id in const ['penguin', 'elephant', 'rabbit'])
                      SvgPicture(
                        FixedSvgAssetLoader(
                          'assets/draft_silhouettes/cute/${id}_color.svg',
                        ),
                        width: shortest * 0.28,
                        height: shortest * 0.28,
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.04).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Semantics(
                  button: true,
                  label: '놀이 시작',
                  child: GestureDetector(
                    onTap: _tap,
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: _busy
                            ? const Color(0xFFE8CBA8)
                            : const Color(0xFFF2B45C),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: buttonSize * 0.7,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
