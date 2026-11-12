import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// flutter_svg(vector_graphics_compiler 1.3.x)는 `<clipPath>` 안의 여러 path를 **하나의 nonzero path로 이어 붙인다**.
/// 그래서 감는 방향이 반대인 두 path가 겹치는 곳은 winding이 0이 되어 클립에서 빠지고,
/// 우리 그림의 음영(밝은 사본을 합집합 실루엣으로 클립)에 어두운 얼룩이 생긴다.
/// SVG 규격상 clipPath 자식은 합집합이므로, 각 자식 path의 감는 방향을 같은 쪽으로 맞추면 결과가 같아진다.
///
/// 원본 SVG 파일은 바꾸지 않고, 앱이 읽을 때만 이 변환을 거친다.
/// 지원: 절대좌표 M/C/Q/L/Z, 자식당 하위 path 1개 (STYLE_GUIDE §2의 path 형식 + 필렛의 Q).
class SvgClipFix {
  SvgClipFix._();

  static final _clipRe = RegExp(
    r'(<clipPath\b[^>]*>)(.*?)(</clipPath>)',
    dotAll: true,
  );
  static final _dRe = RegExp(r'(<path\b[^>]*?\bd=")([^"]*)(")');
  static final _tokRe = RegExp(
    r'[MCLQZ]|-?\d*\.?\d+(?:e-?\d+)?',
    caseSensitive: false,
  );

  static String fix(String svg) => svg.replaceAllMapped(_clipRe, (m) {
    final body = m[2]!.replaceAllMapped(
      _dRe,
      (p) => '${p[1]}${normalizePath(p[2]!)}${p[3]}',
    );
    return '${m[1]}$body${m[3]}';
  });

  /// 시계 방향(화면 좌표, y 아래로)으로 맞춘다. 해석할 수 없는 path는 그대로 둔다.
  static String normalizePath(String d) {
    final segs = _parse(d);
    if (segs == null || segs.length < 2) return d;
    // 신발끈 공식(제어점 포함 다각형). 단순 도형에서 부호가 실제 곡선과 같다.
    final pts = <List<double>>[];
    for (final s in segs) {
      for (var i = 0; i < s.pts.length; i += 2) {
        pts.add([s.pts[i], s.pts[i + 1]]);
      }
    }
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      area += a[0] * b[1] - b[0] * a[1];
    }
    if (area >= 0) return d; // 이미 시계 방향
    return _reverse(segs);
  }

  static List<_Seg>? _parse(String d) {
    final toks = _tokRe.allMatches(d).map((m) => m[0]!).toList();
    final segs = <_Seg>[];
    var i = 0;
    var sawM = false;
    var closed = false;
    while (i < toks.length) {
      final cmd = toks[i++];
      final n = switch (cmd) {
        'M' => 2,
        'L' => 2,
        'Q' => 4,
        'C' => 6,
        'Z' => 0,
        _ => -1,
      };
      if (n < 0) return null;
      if (cmd == 'Z') {
        closed = true;
        continue;
      }
      if (closed) return null; // Z 뒤에 더 있으면(하위 path 여러 개) 건드리지 않는다
      if (cmd == 'M') {
        if (sawM) return null;
        sawM = true;
      }
      // 같은 명령 반복(암묵적 반복) 지원
      do {
        if (i + n > toks.length) return null;
        final nums = <double>[];
        for (var k = 0; k < n; k++) {
          final v = double.tryParse(toks[i + k]);
          if (v == null) return null;
          nums.add(v);
        }
        i += n;
        segs.add(_Seg(cmd == 'M' && segs.isNotEmpty ? 'L' : cmd, nums));
      } while (i < toks.length && double.tryParse(toks[i]) != null);
    }
    if (!sawM || segs.first.cmd != 'M') return null;
    return segs;
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  static String _reverse(List<_Seg> segs) {
    // 각 세그먼트의 시작점 계산
    final starts = <List<double>>[];
    var cur = [segs.first.pts[0], segs.first.pts[1]];
    for (final s in segs) {
      starts.add(cur);
      cur = [s.pts[s.pts.length - 2], s.pts[s.pts.length - 1]];
    }
    final end = cur;
    final b = StringBuffer('M${_fmt(end[0])} ${_fmt(end[1])}');
    for (var k = segs.length - 1; k >= 1; k--) {
      final s = segs[k];
      final st = starts[k];
      final p = s.pts;
      switch (s.cmd) {
        case 'L':
          b.write('L${_fmt(st[0])} ${_fmt(st[1])}');
        case 'Q':
          b.write('Q${_fmt(p[0])} ${_fmt(p[1])} ${_fmt(st[0])} ${_fmt(st[1])}');
        case 'C':
          b.write(
            'C${_fmt(p[2])} ${_fmt(p[3])} ${_fmt(p[0])} ${_fmt(p[1])} '
            '${_fmt(st[0])} ${_fmt(st[1])}',
          );
      }
    }
    b.write('Z');
    return b.toString();
  }
}

class _Seg {
  _Seg(this.cmd, this.pts);
  final String cmd;
  final List<double> pts;
}

/// [SvgClipFix]를 거쳐 에셋 SVG를 읽는 로더. 앱의 모든 그림은 이 로더로 읽는다.
class FixedSvgAssetLoader extends SvgAssetLoader {
  const FixedSvgAssetLoader(super.assetName);

  @override
  String provideSvg(ByteData? message) =>
      SvgClipFix.fix(super.provideSvg(message));
}
