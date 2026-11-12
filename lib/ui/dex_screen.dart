import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_config.dart';
import '../app/app_services.dart';
import '../content/line_keys.dart';
import '../content/species.dart';
import '../content/world_catalog.dart';
import '../progress/dex_progress.dart';
import '../services/voice/voice_line.dart';
import 'dex_grid.dart';
import 'round_button.dart';

/// 도감 화면(글자 없음): 월드의 12칸. 칸을 누르면 이름을 들려준다(못 만난 종은 "누구일까?").
class DexScreen extends StatefulWidget {
  const DexScreen({
    super.key,
    required this.services,
    required this.world,
    required this.species,
  });

  final AppServices services;
  final WorldDef world;
  final List<Species> species;

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  late final List<GlobalKey<DexCellState>> _keys = [
    for (final _ in widget.species) GlobalKey<DexCellState>(),
  ];
  bool _overlay = AppConfig.debugOverlayInitiallyOn;
  bool _editTiers = false;
  bool _leaving = false;

  AppServices get _s => widget.services;

  @override
  void dispose() {
    unawaited(_s.voice.stop());
    super.dispose();
  }

  Future<void> _onCell(Species sp, int i) async {
    final progress = _s.progress;
    if (_editTiers) {
      final next =
          DexTier.values[(progress.progress.tier(widget.world.id, sp.id).index +
                  1) %
              DexTier.values.length];
      await progress.debugSetTier(widget.world.id, sp.id, next);
      return;
    }
    final met = progress.progress.isMet(widget.world.id, sp.id);
    if (met) _keys[i].currentState?.wiggle();
    unawaited(_s.sfx.play(SfxNames.tap));
    // 빠르게 여러 번 눌러도 마지막 칸 이름만 들리게 이전 음성을 끊는다.
    await _s.voice.stop();
    if (!mounted) return;
    await _s.voice.say(
      met
          ? VoiceLine(LineKeys.dexKnown, species: sp)
          : const VoiceLine(LineKeys.dexUnknown),
    );
  }

  Future<void> _home() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(_s.sfx.play(SfxNames.tap));
    await _s.voice.stop();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final buttonSize = (shortest * 0.16).clamp(64.0, 110.0);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1D6),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: RoundIconButton(
                    icon: Icons.home_rounded,
                    size: buttonSize,
                    color: const Color(0xFFF2A7A7),
                    semanticLabel: '집',
                    onTap: _home,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      shortest * 0.04,
                      0,
                      shortest * 0.04,
                      shortest * 0.04,
                    ),
                    child: ListenableBuilder(
                      listenable: _s.progress,
                      builder: (context, _) => DexGrid(
                        species: widget.species,
                        cellKeys: _keys,
                        tierOf: (sp) =>
                            _s.progress.progress.tier(widget.world.id, sp.id),
                        onTap: _onCell,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (AppConfig.debugOverlayAvailable) ...[
              Positioned(
                top: 0,
                right: 0,
                width: 72,
                height: 72,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => setState(() => _overlay = !_overlay),
                ),
              ),
              if (_overlay) _debugPanel(),
            ],
          ],
        ),
      ),
    );
  }

  /// 개발자 패널(debug 빌드 / 웹 `?debug=1` 전용). 도감 상태를 강제로 바꿔 테두리·금테를 확인한다.
  Widget _debugPanel() {
    Future<void> preset(String name) => _s.progress.debugPreset(
      widget.world.id,
      [for (final sp in widget.species) sp.id],
      name,
    );

    Widget btn(String label, VoidCallback onPressed) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Text(label),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListenableBuilder(
                listenable: _s.progress,
                builder: (context, _) => Text(
                  '[DEBUG dex] met ${_s.progress.progress.metCount(widget.world.id)}/'
                  '${widget.species.length}  edit=${_editTiers ? 'on (tap cycles tier)' : 'off'}',
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final n in const [
                    'empty',
                    'some',
                    'mixed',
                    'border',
                    'gold',
                  ])
                    btn(n, () => preset(n)),
                  btn('edit', () => setState(() => _editTiers = !_editTiers)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
