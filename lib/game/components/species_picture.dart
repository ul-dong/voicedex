import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG 그림 한 장을 그리는 컴포넌트. 기준점은 발밑 가운데(bottomCenter)라 튀어오르기·찌그러짐이 자연스럽다.
class SpeciesPicture extends PositionComponent with TapCallbacks {
  SpeciesPicture({
    required this.picture,
    required double side,
    super.position,
    this.onTap,
  }) : super(size: Vector2.all(side), anchor: Anchor.bottomCenter);

  final PictureInfo picture;
  final VoidCallback? onTap;

  @override
  void render(Canvas canvas) {
    final w = picture.size.width == 0 ? 400.0 : picture.size.width;
    final h = picture.size.height == 0 ? 400.0 : picture.size.height;
    canvas.save();
    canvas.scale(size.x / w, size.y / h);
    canvas.drawPicture(picture.picture);
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) => onTap?.call();
}
