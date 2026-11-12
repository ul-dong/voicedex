import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voicedex/game/svg_clip_fix.dart';

import 'test_data.dart';

/// 12종 색칠 SVG가 flutter_svg로 파싱·렌더되는지 확인한다.
/// 환경변수 VOICEDEX_SVG_OUT=<폴더>를 주면 400×400 PNG를 써서 원본(브라우저) 렌더와 비교할 수 있다.
void main() {
  final animals = loadAnimals();
  final out = Platform.environment['VOICEDEX_SVG_OUT'];

  for (final s in animals.species) {
    testWidgets('SVG 렌더: ${s.id}', (tester) async {
      await tester.runAsync(() async {
        final svg = SvgClipFix.fix(File(s.colorImage).readAsStringSync());
        final info = await vg.loadPicture(SvgStringLoader(svg), null);
        expect(info.size.width, 400);
        expect(info.size.height, 400);
        final image = await info.picture.toImage(400, 400);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        // 불투명 픽셀이 충분히 있어야 한다(그림이 비어 있지 않음).
        var opaque = 0;
        final data = bytes!.buffer.asUint8List();
        for (var i = 3; i < data.length; i += 4) {
          if (data[i] > 200) opaque++;
        }
        expect(
          opaque,
          greaterThan(400 * 400 * 0.06),
          reason: '${s.id} opaque=$opaque',
        );
        if (out != null) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(out).createSync(recursive: true);
          File('$out/${s.id}_flutter.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
        info.picture.dispose();
      });
    });
  }
}
