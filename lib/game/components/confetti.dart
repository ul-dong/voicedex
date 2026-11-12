import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

const _palette = [
  Color(0xFFF2A7A7),
  Color(0xFFF2B45C),
  Color(0xFF8DBE8A),
  Color(0xFFB7A6C9),
  Color(0xFFB8C4D0),
  Color(0xFFE8C27A),
];

/// 정답 때 그림 주변에 터지는 작은 동그라미.
ParticleSystemComponent sparkleBurst(
  Vector2 center, {
  Random? random,
  int count = 18,
}) {
  final rnd = random ?? Random();
  return ParticleSystemComponent(
    position: center,
    particle: Particle.generate(
      count: count,
      lifespan: 0.9,
      generator: (i) {
        final angle = (i / count) * 2 * pi + rnd.nextDouble() * 0.3;
        final speed = 180 + rnd.nextDouble() * 140;
        return AcceleratedParticle(
          speed: Vector2(cos(angle), sin(angle)) * speed,
          acceleration: Vector2(0, 260),
          child: CircleParticle(
            radius: 5 + rnd.nextDouble() * 5,
            paint: Paint()..color = _palette[i % _palette.length],
          ),
        );
      },
    ),
  );
}

/// 스테이지 끝 축하 색종이(위에서 떨어짐).
ParticleSystemComponent confettiRain(
  Vector2 area, {
  Random? random,
  int count = 90,
}) {
  final rnd = random ?? Random();
  return ParticleSystemComponent(
    particle: Particle.generate(
      count: count,
      lifespan: 3.2,
      generator: (i) {
        final start = Vector2(
          rnd.nextDouble() * area.x,
          -20 - rnd.nextDouble() * area.y * 0.4,
        );
        final color = _palette[i % _palette.length];
        final w = 8 + rnd.nextDouble() * 8;
        return AcceleratedParticle(
          position: start,
          speed: Vector2(
            (rnd.nextDouble() - 0.5) * 80,
            120 + rnd.nextDouble() * 120,
          ),
          acceleration: Vector2(0, 40),
          child: RotatingParticle(
            from: rnd.nextDouble() * pi,
            to: rnd.nextDouble() * 6 * pi,
            child: ComputedParticle(
              renderer: (canvas, particle) {
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: w,
                      height: w * 0.6,
                    ),
                    const Radius.circular(3),
                  ),
                  Paint()..color = color,
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
