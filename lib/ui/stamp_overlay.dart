import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../content/species.dart';
import '../game/svg_clip_fix.dart';
import '../progress/dex_progress.dart';
import 'dex_grid.dart';

/// 보상 2층 연출: 스테이지 끝에 이번에 맞힌 종들이 차례로 도감 칸으로 날아가 "콕" 찍힌다.
/// 새로 열린 종은 더 크게 날아가고, 칸이 반짝이며 크게 튄다. 글자 없음, 아이의 탭은 무시한다.
class StampOverlay extends StatefulWidget {
  const StampOverlay({
    super.key,
    required this.species,
    required this.before,
    required this.changes,
    this.onStamp,
    this.onAllStamped,
    this.onDone,
  });

  /// 도감 칸 순서(월드 전체 12종).
  final List<Species> species;

  /// 이번 스테이지 반영 전 칸 상태.
  final Map<String, DexTier> before;

  /// 반영 결과(날아갈 순서).
  final List<StampChange> changes;

  /// 칸에 찍힐 때마다(효과음용).
  final void Function(StampChange change)? onStamp;

  /// 다 찍힌 뒤 (음성용). 돌려준 Future가 끝나면 마무리.
  final Future<void> Function()? onAllStamped;
  final VoidCallback? onDone;

  @override
  State<StampOverlay> createState() => _StampOverlayState();
}

class _StampOverlayState extends State<StampOverlay>
    with TickerProviderStateMixin {
  late final Map<String, DexTier> _tiers = {...widget.before};
  final Set<String> _glowing = {};
  late final List<GlobalKey<DexCellState>> _keys = [
    for (final _ in widget.species) GlobalKey<DexCellState>(),
  ];

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// 날아가는 중인 그림.
  _Flight? _flight;
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  /// 찍힌 칸의 튐.
  final Map<String, AnimationController> _pops = {};
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _disposed = true;
    _fade.dispose();
    _fly.dispose();
    for (final c in _pops.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _run() async {
    await _fade.forward();
    await _wait(250);
    for (final change in widget.changes) {
      if (_disposed) return;
      setState(() => _flight = _Flight(change));
      await _fly.forward(from: 0);
      if (_disposed) return;
      final pop = _pops[change.speciesId] ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: change.isNew ? 700 : 450),
      );
      setState(() {
        _flight = null;
        _tiers[change.speciesId] = change.after;
        if (change.isNew) _glowing.add(change.speciesId);
      });
      widget.onStamp?.call(change);
      unawaited(pop.forward(from: 0));
      await _wait(change.isNew ? 380 : 220);
    }
    if (_disposed) return;
    // 다 찍히면 열린 칸들이 한 번씩 콩 뛴다.
    for (final k in _keys) {
      final st = k.currentState;
      if (st != null && st.widget.tier != DexTier.hidden) st.wiggle();
    }
    await (widget.onAllStamped?.call() ?? Future<void>.value());
    await _wait(900);
    if (_disposed) return;
    await _fade.reverse();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return AbsorbPointer(
      // 아이가 아무 데나 눌러도 연출이 흐트러지지 않게.
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: const Color(0xF2FFF1D6),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(shortest * 0.05),
              child: LayoutBuilder(
                builder: (context, box) {
                  final layout = DexGridLayout(
                    box.biggest,
                    widget.species.length,
                  );
                  final children = <Widget>[];
                  for (var i = 0; i < widget.species.length; i++) {
                    final sp = widget.species[i];
                    final pop = _pops[sp.id];
                    Widget cell = DexCell(
                      key: _keys[i],
                      species: sp,
                      tier: _tiers[sp.id] ?? DexTier.hidden,
                      glow: _glowing.contains(sp.id),
                    );
                    if (pop != null) {
                      final big = _glowing.contains(sp.id);
                      cell = AnimatedBuilder(
                        animation: pop,
                        builder: (context, child) {
                          final t = pop.value;
                          final s = 1 + sin(t * pi) * (big ? 0.28 : 0.14);
                          return Transform.scale(scale: s, child: child);
                        },
                        child: cell,
                      );
                      if (big) {
                        cell = Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: cell),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: pop,
                                  builder: (context, _) => CustomPaint(
                                    painter: _BurstPainter(pop.value),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    }
                    children.add(
                      Positioned.fromRect(
                        rect: layout.cellRect(i),
                        child: cell,
                      ),
                    );
                  }
                  final f = _flight;
                  if (f != null) {
                    final index = widget.species.indexWhere(
                      (s) => s.id == f.change.speciesId,
                    );
                    children.add(
                      _flyingPicture(
                        box.biggest,
                        layout.cellRect(index),
                        f,
                        index,
                      ),
                    );
                  }
                  return Stack(clipBehavior: Clip.none, children: children);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flyingPicture(Size area, Rect target, _Flight f, int index) {
    final sp = widget.species[index];
    final startSide = area.shortestSide * (f.change.isNew ? 0.62 : 0.42);
    final start = Rect.fromCenter(
      center: Offset(area.width / 2, area.height * 0.5),
      width: startSide,
      height: startSide,
    );
    return AnimatedBuilder(
      animation: _fly,
      builder: (context, child) {
        // 0~0.35: 가운데에서 커지며 등장(새 종은 잠깐 머문다), 0.35~1: 칸으로 포물선 비행.
        final t = _fly.value;
        final appear = Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
        final travel = Curves.easeInOutCubic.transform(
          ((t - 0.35) / 0.65).clamp(0.0, 1.0),
        );
        final rect = Rect.lerp(start, target, travel)!;
        final arc = sin(travel * pi) * area.height * 0.08;
        final scale = t < 0.35 ? appear : 1.0;
        return Positioned(
          left: rect.left,
          top: rect.top - arc,
          width: rect.width,
          height: rect.height,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: sin(travel * pi) * -0.25,
              child: child,
            ),
          ),
        );
      },
      child: SvgPicture(
        FixedSvgAssetLoader(sp.colorImage),
        fit: BoxFit.contain,
      ),
    );
  }
}

class _Flight {
  _Flight(this.change);
  final StampChange change;
}

/// 새로 열린 칸 둘레로 퍼지는 동그라미 반짝이.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFF2A7A7),
    Color(0xFFF2B45C),
    Color(0xFF8DBE8A),
    Color(0xFFB7A6C9),
    Color(0xFFFFD86B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final r0 = size.shortestSide * 0.5;
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * pi;
      final r = r0 + t * size.shortestSide * 0.45;
      final p = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * r,
        size.shortestSide * 0.05 * (1 - t * 0.5),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
