import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../content/species.dart';
import '../game/svg_clip_fix.dart';
import '../progress/dex_progress.dart';

/// 도감 칸 배치. 화면 비율에 맞춰 3·4·6열 중 칸이 가장 커지는 쪽을 고른다.
class DexGridLayout {
  DexGridLayout(this.area, this.count) {
    var best = 0.0;
    var bestCols = 3;
    for (final cols in const [3, 4, 6]) {
      final rows = (count / cols).ceil();
      final c = min(area.width / cols, area.height / rows);
      if (c > best) {
        best = c;
        bestCols = cols;
      }
    }
    cols = bestCols;
    rows = (count / cols).ceil();
    pitch = best;
    origin = Offset(
      (area.width - pitch * cols) / 2,
      (area.height - pitch * rows) / 2,
    );
  }

  final Size area;
  final int count;
  late final int cols;
  late final int rows;

  /// 칸 간격 포함 한 칸의 크기.
  late final double pitch;
  late final Offset origin;

  double get gap => pitch * 0.08;
  double get cellSide => pitch - gap;

  Rect cellRect(int i) {
    final col = i % cols;
    final row = i ~/ cols;
    return Rect.fromLTWH(
      origin.dx + col * pitch + gap / 2,
      origin.dy + row * pitch + gap / 2,
      cellSide,
      cellSide,
    );
  }
}

/// 도감 칸 하나(글자 없음). 못 만난 종은 그림자, 만난 종은 색칠 그림 + 단계 표시(테두리/금테).
class DexCell extends StatefulWidget {
  const DexCell({
    super.key,
    required this.species,
    required this.tier,
    this.onTap,
    this.glow = false,
  });

  final Species species;
  final DexTier tier;
  final VoidCallback? onTap;

  /// 방금 열린 칸 강조(찍힘 연출).
  final bool glow;

  static const _cellBg = Color(0xFFFFFDF7);
  static const _hiddenBg = Color(0xFFEFE6D8);
  static const borderColor = Color(0xFF6CC3B5);
  static const goldA = Color(0xFFFFD86B);
  static const goldB = Color(0xFFE2A21C);

  @override
  State<DexCell> createState() => DexCellState();
}

class DexCellState extends State<DexCell> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  /// 그림이 살짝 콩 뛰고 흔들린다.
  void wiggle() => _wiggle.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide;
        final tier = widget.tier;
        final hidden = tier == DexTier.hidden;
        final ring = switch (tier) {
          DexTier.border => side * 0.06,
          DexTier.gold => side * 0.085,
          _ => 0.0,
        };
        final radius = side * 0.2;
        Widget picture = SvgPicture(
          FixedSvgAssetLoader(
            hidden ? widget.species.shadowImage : widget.species.colorImage,
          ),
          fit: BoxFit.contain,
        );
        if (hidden) picture = Opacity(opacity: 0.82, child: picture);
        picture = AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) {
            final t = _wiggle.value;
            final hop = sin(t * pi) * side * 0.08;
            final tilt = sin(t * pi * 3) * 0.12 * (1 - t);
            return Transform.translate(
              offset: Offset(0, -hop),
              child: Transform.rotate(angle: tilt, child: child),
            );
          },
          child: picture,
        );

        final inner = Container(
          decoration: BoxDecoration(
            color: hidden ? DexCell._hiddenBg : DexCell._cellBg,
            borderRadius: BorderRadius.circular(max(0, radius - ring)),
          ),
          padding: EdgeInsets.all(side * 0.07),
          child: picture,
        );

        final Decoration outer = switch (tier) {
          DexTier.gold => BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DexCell.goldA, DexCell.goldB, DexCell.goldA],
            ),
            boxShadow: _shadow(side, widget.glow),
          ),
          DexTier.border => BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: DexCell.borderColor,
            boxShadow: _shadow(side, widget.glow),
          ),
          _ => BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: hidden ? DexCell._hiddenBg : DexCell._cellBg,
            boxShadow: hidden ? const [] : _shadow(side, widget.glow),
          ),
        };

        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              decoration: outer,
              padding: EdgeInsets.all(ring),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  inner,
                  if (tier == DexTier.gold)
                    IgnorePointer(child: CustomPaint(painter: _ShinePainter())),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<BoxShadow> _shadow(double side, bool glow) => [
    BoxShadow(
      color: glow ? const Color(0x88FFD86B) : const Color(0x22000000),
      blurRadius: glow ? side * 0.25 : side * 0.06,
      spreadRadius: glow ? side * 0.04 : 0,
      offset: Offset(0, glow ? 0 : side * 0.03),
    ),
  ];
}

/// 금테 칸의 반짝 점(별 모양은 쓰지 않는다 — 별점처럼 보이지 않게).
class _ShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xCCFFFFFF);
    final s = size.shortestSide;
    canvas.drawCircle(Offset(s * 0.14, s * 0.14), s * 0.035, p);
    canvas.drawCircle(Offset(s * 0.22, s * 0.09), s * 0.018, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 도감 12칸 그리드.
class DexGrid extends StatelessWidget {
  const DexGrid({
    super.key,
    required this.species,
    required this.tierOf,
    this.onTap,
    this.cellKeys,
    this.glowing = const {},
  });

  final List<Species> species;
  final DexTier Function(Species s) tierOf;
  final void Function(Species s, int index)? onTap;

  /// 칸을 흔들기 위한 키(선택).
  final List<GlobalKey<DexCellState>>? cellKeys;
  final Set<String> glowing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = DexGridLayout(box.biggest, species.length);
        return Stack(
          children: [
            for (var i = 0; i < species.length; i++)
              Positioned.fromRect(
                rect: layout.cellRect(i),
                child: DexCell(
                  key: cellKeys?[i],
                  species: species[i],
                  tier: tierOf(species[i]),
                  glow: glowing.contains(species[i].id),
                  onTap: onTap == null ? null : () => onTap!(species[i], i),
                ),
              ),
          ],
        );
      },
    );
  }
}
