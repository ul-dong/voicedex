import 'package:flutter_test/flutter_test.dart';
import 'package:voicedex/game/svg_clip_fix.dart';

void main() {
  test('시계 방향 path는 그대로', () {
    const cw = 'M0 0L10 0L10 10L0 10Z';
    expect(SvgClipFix.normalizePath(cw), cw);
  });

  test('반시계 방향 path는 뒤집는다 (L/C/Q)', () {
    expect(
      SvgClipFix.normalizePath('M0 0L0 10L10 10L10 0Z'),
      'M10 0L10 10L0 10L0 0Z',
    );
    expect(
      SvgClipFix.normalizePath('M0 0C0 5 0 10 0 10L10 10Q10 5 10 0Z'),
      'M10 0Q10 5 10 10L0 10C0 10 0 5 0 0Z',
    );
  });

  test('clipPath 안의 path만 바꾸고 나머지는 그대로', () {
    const svg =
        '<svg><defs><clipPath id="u"><path d="M0 0L0 10L10 10L10 0Z"/></clipPath></defs>'
        '<path d="M0 0L0 10L10 10L10 0Z"/></svg>';
    final out = SvgClipFix.fix(svg);
    expect(
      out,
      contains('<clipPath id="u"><path d="M10 0L10 10L0 10L0 0Z"/></clipPath>'),
    );
    expect(out, endsWith('<path d="M0 0L0 10L10 10L10 0Z"/></svg>'));
  });

  test('해석할 수 없는 path는 건드리지 않는다', () {
    const d = 'M0 0a5 5 0 0 1 10 0Z';
    expect(SvgClipFix.normalizePath(d), d);
  });
}
