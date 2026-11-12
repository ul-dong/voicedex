import 'package:flutter/material.dart';

/// 아이용 큰 동그라미 버튼(글자 없음). 누르는 동안 살짝 작아진다.
class RoundIconButton extends StatefulWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 88,
    this.color = const Color(0xFFF2B45C),
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  State<RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<RoundIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        // 그림보다 넓게 눌리도록 여백까지 탭 영역.
        child: Padding(
          padding: EdgeInsets.all(s * 0.12),
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: const Duration(milliseconds: 90),
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: s * 0.6, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
