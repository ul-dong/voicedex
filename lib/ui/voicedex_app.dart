import 'package:flutter/material.dart';

import '../app/app_services.dart';
import 'home_screen.dart';
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

  /// 시작 화면의 재생 버튼(첫 사용자 제스처): 마이크·음성 인식 권한을 받고 메인 화면으로.
  Future<void> _play(BuildContext context) async {
    await services.ensureSpeech();
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => HomeScreen(services: services),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      StartScreen(onPlay: () => _play(context));
}
