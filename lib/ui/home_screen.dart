import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_services.dart';
import '../content/line_keys.dart';
import '../content/world_catalog.dart';
import '../game/svg_clip_fix.dart';
import '../services/voice/voice_line.dart';
import 'dex_screen.dart';
import 'quiz_screen.dart';
import 'round_button.dart';

/// 메인 화면(글자 없음): 월드 입구(큰 그림 버튼)와 도감 버튼.
/// 잠긴/유료 월드는 아이 화면에 보이지 않는다([WorldCatalog.visibleToChild]).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  /// 화면 이동 중에는 다른 탭을 무시한다(연타·실수 탭 방지).
  bool _busy = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_s.voice.say(const VoiceLine(LineKeys.homeWelcome)));
    });
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  /// 버튼 이름을 말하고 화면을 연다.
  Future<void> _go(String lineKey, Widget Function() page) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      unawaited(_s.sfx.play(SfxNames.tap));
      await _s.voice.stop();
      await _s.voice.say(VoiceLine(lineKey));
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => page(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWorld(WorldDef world) async {
    final content = await _s.content.load(world);
    await _go(
      LineKeys.homeWorld(world.id),
      () => QuizScreen(
        services: _s,
        spec: StageSpec(world: world, kind: StageKind.nameFromColor),
        pool: content.species,
      ),
    );
  }

  Future<void> _openDex() async {
    // 지금은 동물 월드 도감만 있다. 월드가 늘면 도감 첫 화면에서 월드를 고르게 한다.
    const world = WorldCatalog.animals;
    final content = await _s.content.load(world);
    await _go(
      LineKeys.homeDex,
      () => DexScreen(services: _s, world: world, species: content.species),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final worlds = WorldCatalog.visibleToChild();
    final landscape = size.width > size.height;
    final gates = [
      for (final w in worlds)
        _WorldGate(
          world: w,
          bob: _bob,
          dimmed: _busy,
          onTap: () => _openWorld(w),
        ),
    ];
    final dexButton = RoundIconButton(
      icon: Icons.menu_book_rounded,
      size: (shortest * 0.24).clamp(80.0, 170.0),
      color: const Color(0xFF8FB8E0),
      semanticLabel: '도감',
      onTap: _openDex,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(shortest * 0.05),
          child: landscape
              ? Row(
                  children: [
                    for (final g in gates) Expanded(child: g),
                    SizedBox(width: shortest * 0.05),
                    dexButton,
                  ],
                )
              : Column(
                  children: [
                    for (final g in gates) Expanded(child: g),
                    SizedBox(height: shortest * 0.06),
                    dexButton,
                  ],
                ),
        ),
      ),
    );
  }
}

/// 월드 입구: 둥근 언덕 그림 위에 그 월드 친구들이 서 있는 큰 버튼.
class _WorldGate extends StatefulWidget {
  const _WorldGate({
    required this.world,
    required this.bob,
    required this.onTap,
    required this.dimmed,
  });

  final WorldDef world;
  final Animation<double> bob;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  State<_WorldGate> createState() => _WorldGateState();
}

class _WorldGateState extends State<_WorldGate> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final base = Color(widget.world.color);
    return Semantics(
      button: true,
      label: widget.world.id,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 100),
          child: AnimatedOpacity(
            opacity: widget.dimmed ? 0.8 : 1,
            duration: const Duration(milliseconds: 150),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight;
                final side = min(w, h);
                final ids = widget.world.coverSpecies;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(side * 0.12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFCFE8F5), Color(0xFFE9F5FB)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 해
                      Positioned(
                        right: w * 0.08,
                        top: h * 0.07,
                        child: Container(
                          width: side * 0.16,
                          height: side * 0.16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD86B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // 언덕
                      Positioned(
                        left: -w * 0.2,
                        right: -w * 0.2,
                        bottom: -h * 0.55,
                        height: h * 0.9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(w, h * 0.45),
                            ),
                          ),
                        ),
                      ),
                      // 친구들
                      // 양옆 친구 먼저, 가운데 친구를 맨 앞에.
                      for (final i in const [1, 2, 0])
                        if (i < ids.length) _coverAnimal(ids[i], i, w, h, side),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverAnimal(String id, int i, double w, double h, double side) {
    // 가운데(크게) → 왼쪽 → 오른쪽.
    const xs = [0.5, 0.19, 0.81];
    final pic = i == 0 ? min(h * 0.6, w * 0.44) : min(h * 0.44, w * 0.34);
    return AnimatedBuilder(
      animation: widget.bob,
      builder: (context, child) {
        final phase = (widget.bob.value + i * 0.33) % 1.0;
        final lift = sin(phase * pi) * side * 0.025;
        return Positioned(
          left: w * xs[i] - pic / 2,
          bottom: h * 0.12 + lift,
          width: pic,
          height: pic,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: SvgPicture(
          FixedSvgAssetLoader('assets/draft_silhouettes/cute/${id}_color.svg'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
