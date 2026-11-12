import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../content/world_catalog.dart';
import 'quiz_screen.dart';
import 'start_screen.dart';

class VoicedexApp extends StatelessWidget {
  const VoicedexApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 아이 화면에 글자가 없도록 디버그 배너도 끈다.
      debugShowCheckedModeBanner: false,
      title: '말하는 도감',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF2B45C)),
        useMaterial3: true,
      ),
      home: _Home(services: services),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.services});

  final AppServices services;

  Future<void> _play(BuildContext context) async {
    await services.ensureSpeech();
    final world = await services.content.load(WorldCatalog.animals);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => QuizScreen(
          services: services,
          spec: const StageSpec(
            world: WorldCatalog.animals,
            kind: StageKind.nameFromColor,
          ),
          pool: world.species,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      StartScreen(onPlay: () => _play(context));
}
