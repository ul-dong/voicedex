"""말하는 도감 cute 일러스트 - crocodile. 오리지널(외부 이미지·기존 캐릭터 참조 금지). 규칙: docs/STYLE_GUIDE.md"""
import math

from common import blob, eye, cheek  # noqa: F401

# ── 악어: 완전 측면(왼쪽) 엎드림. 납작하고 긴 주둥이(높이 ≤ 길이의 0.35, 끝 둥근), 눈 돌기,
#    낮고 긴 몸, 땅을 따라 뻗다 끝이 살짝 들린 긴 꼬리, 등·꼬리 위 작고 둥근 돌기 줄, 짧은 다리 4개.
#    하마와 구별: 주둥이가 낮고 길며 몸 전체가 낮고 가로로 김(실루엣 세로 ≈ 120)
C = "#8DBE8A"


def _f(v):
    return f"{round(v, 1):g}"


def _ell(cx, cy, rx, ry):
    """실루엣용 타원(M/C/Z, 소수 1자리)."""
    k = 0.5523
    p = lambda x, y: f"{_f(x)} {_f(y)}"
    return (f"M{p(cx - rx, cy)}C{p(cx - rx, cy - ry * k)} {p(cx - rx * k, cy - ry)} {p(cx, cy - ry)}"
            f"C{p(cx + rx * k, cy - ry)} {p(cx + rx, cy - ry * k)} {p(cx + rx, cy)}"
            f"C{p(cx + rx, cy + ry * k)} {p(cx + rx * k, cy + ry)} {p(cx, cy + ry)}"
            f"C{p(cx - rx * k, cy + ry)} {p(cx - rx, cy + ry * k)} {p(cx - rx, cy)}Z")


def _cr(pts, n=12):
    out, m = [], len(pts)
    for i in range(m - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, m - 1)]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    out.append(pts[-1])
    return out


def _smooth(pts):
    m = len(pts)
    d = f"M{_f(pts[0][0])} {_f(pts[0][1])}"
    for i in range(m):
        p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{_f(c1[0])} {_f(c1[1])} {_f(c2[0])} {_f(c2[1])} {_f(p2[0])} {_f(p2[1])}"
    return d + "Z"


def _tube(center, w0, w1, step=9):
    """중심선을 따라 굵기 w0→w1 로 가늘어지고 끝이 반원인 관 모양 path. 중심선 각 점도 함께 돌려준다."""
    c = _cr(center)
    acc = [0.0]
    for a, b in zip(c, c[1:]):
        acc.append(acc[-1] + math.dist(a, b))
    L = acc[-1]
    left, right, mid = [], [], []
    nxt = 0.0
    for i, p in enumerate(c):
        if acc[i] + 1e-6 < nxt and i != len(c) - 1:
            continue
        nxt = acc[i] + step
        a, b = c[max(i - 1, 0)], c[min(i + 1, len(c) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        tl = math.hypot(tx, ty) or 1
        nx, ny = -ty / tl, tx / tl
        w = (w0 + (w1 - w0) * acc[i] / L) / 2
        left.append((p[0] + nx * w, p[1] + ny * w))
        right.append((p[0] - nx * w, p[1] - ny * w))
        mid.append((p, (nx, ny), w))
    p = c[-1]; a = c[-2]
    tx, ty = p[0] - a[0], p[1] - a[1]
    tl = math.hypot(tx, ty) or 1
    tx, ty = tx / tl, ty / tl
    nx, ny = -ty, tx
    w = w1 / 2
    cap = [(p[0] + w * (nx * math.cos(t) + tx * math.sin(t)), p[1] + w * (ny * math.cos(t) + ty * math.sin(t)))
           for t in (math.pi * k / 4 for k in range(1, 4))]
    return _smooth(left + cap + right[::-1]), mid


# 머리: 납작한 주둥이(x 22~92, 높이 ≈ 23) + 둥근 뒷머리
_c_head = ("M22 324C22 317 28 314 38 314C60 314 78 312 92 306"
           "C100 292 106 280 118 276C136 272 150 280 156 294"
           "C162 312 158 330 140 338C110 342 60 338 38 337C28 336 22 331 22 324Z")
_c_eye = "M114 304C100 292 98 264 110 254C118 248 130 248 138 256C148 266 148 288 144 300Z"
_c_body = ("M124 300C134 276 172 262 220 262C266 262 296 274 310 294"
           "C318 312 312 334 290 340C240 346 170 346 140 340C122 336 116 318 124 300Z")
_c_tail, _tail_mid = _tube([(286, 306), (322, 326), (352, 334), (374, 326), (384, 306)], 44, 14)


def _top(x):
    """꼬리 윗선에서 x 에 가장 가까운 점(돌기 위치용)."""
    best = min(_tail_mid, key=lambda m: abs(m[0][0] - x))
    (px, py), (nx, ny), w = best
    if ny > 0:
        nx, ny = -nx, -ny
    return px + nx * w, py + ny * w


_bumps = [_ell(156, 274, 9, 9), _ell(184, 266, 9.5, 9.5), _ell(213, 263, 9.5, 9.5),
          _ell(242, 265, 9, 9), _ell(270, 272, 8.5, 8.5)]
for x, r in ((310, 7.5), (338, 6.5)):
    tx, ty = _top(x)
    _bumps.append(_ell(round(tx, 1), round(ty + 2, 1), r, r))

_leg = lambda x0, x1, top, bot=360: (f"M{x0 + 4} {top}C{x0 + 2} {top + 14} {x0 - 10} {top + 20} {x0 - 10} {bot - 7}"
                                    f"C{x0 - 10} {bot + 1} {x0} {bot} {x0 + 10} {bot}"
                                    f"C{x1 - 8} {bot} {x1} {bot} {x1} {bot - 8}"
                                    f"C{x1} {top + 20} {x1} {top + 10} {x1} {top}Z")

ANIMAL = dict(
    id="crocodile", no=9,
    name="악어", base=C, ground=(206, 359, 160, 8), r=10,
    shapes=[
        _leg(212, 236, 322, 357),     # 0 먼 앞다리
        _leg(320, 342, 318, 356),     # 1 먼 뒷다리
        _c_tail,                 # 2 꼬리
        *_bumps,                 # 3~9 등·꼬리 돌기
        _c_body,                 # 10 몸
        _leg(148, 176, 322),     # 11 앞다리
        _leg(264, 292, 320),     # 12 뒷다리
        _c_eye,                  # 13 눈 돌기
        _c_head,                 # 14 머리
    ],
    accents=[],
    creases=["M156 296C162 314 158 330 142 338"],
    details=[
        ("M136 330C170 336 240 336 292 330C302 328 308 322 310 316C306 336 290 342 250 344C200 346 160 346 140 340C136 338 134 334 136 330Z", "#CFE3B8", 1),
        ("M30 330C60 333 100 332 128 324", "stroke:#5E8C5C", 1),
        ("M58 331C60 336 64 336 66 331Z", "#FFFDF6", 1), ("M84 330C86 335 90 335 92 329Z", "#FFFDF6", 1),
        (blob(32, 318, 3.5, 2.5), "#4F7A4D", 1),
        (blob(200, 290, 7, 5), "#7AAE77", 1), (blob(230, 296, 6, 4.5), "#7AAE77", 1), (blob(176, 300, 5, 4), "#7AAE77", 1),
        *eye(122, 268, 6.8),
        *cheek(130, 304, 11, 7),
    ],
)
