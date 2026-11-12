import 'package:flutter_svg/flutter_svg.dart';

import 'svg_clip_fix.dart';

/// SVG 에셋을 한 번만 파싱해 [PictureInfo]로 들고 있는다.
class SvgPictureCache {
  final Map<String, PictureInfo> _cache = {};

  Future<PictureInfo> load(String asset) async {
    final hit = _cache[asset];
    if (hit != null) return hit;
    final info = await vg.loadPicture(FixedSvgAssetLoader(asset), null);
    _cache[asset] = info;
    return info;
  }

  PictureInfo? peek(String asset) => _cache[asset];

  void dispose() {
    for (final info in _cache.values) {
      info.picture.dispose();
    }
    _cache.clear();
  }
}
