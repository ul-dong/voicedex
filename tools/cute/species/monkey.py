"""말하는 도감 cute 일러스트 - monkey. 오리지널(외부 이미지·기존 캐릭터 참조 금지). 규칙: docs/STYLE_GUIDE.md"""
import math

from common import blob, eye, cheek  # noqa: F401

# ── 원숭이: 앞모습 3/4(왼쪽) 선 자세. 앞팔을 L자로 위로 들어 흔듦, 머리 양옆 둥근 귀,
#    몸 뒤(오른쪽)에서 몸과 겹치지 않고 위로 말려 올라간 긴 꼬리. 곰과 구별: 귀가 머리 '옆', 팔다리 가늘고 김, 꼬리 보임
M = "#B88A68"
FACE = "#EBCBA8"


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


def _cr(pts, closed, n=12):
    """Catmull-Rom 스플라인을 촘촘히 샘플."""
    out = []
    m = len(pts)
    segs = m if closed else m - 1
    for i in range(segs):
        p0 = pts[(i - 1) % m] if closed else pts[max(i - 1, 0)]
        p1, p2 = pts[i % m], pts[(i + 1) % m]
        p3 = pts[(i + 2) % m] if closed else pts[min(i + 2, m - 1)]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    if not closed:
        out.append(pts[-1])
    return out


def _smooth(pts):
    """닫힌 점열 → Catmull-Rom 을 베지어(C)로 바꾼 path."""
    m = len(pts)
    d = f"M{_f(pts[0][0])} {_f(pts[0][1])}"
    for i in range(m):
        p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{_f(c1[0])} {_f(c1[1])} {_f(c2[0])} {_f(c2[1])} {_f(p2[0])} {_f(p2[1])}"
    return d + "Z"


def _tube(center, w0, w1, step=9):
    """중심선(점 목록)을 따라 굵기 w0→w1 로 가늘어지고 끝이 반원인 관 모양 path."""
    c = _cr(center, False)
    acc = [0.0]
    for a, b in zip(c, c[1:]):
        acc.append(acc[-1] + math.dist(a, b))
    L = acc[-1]
    left, right = [], []
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
    # 끝 반원 캡
    p = c[-1]; a = c[-2]
    tx, ty = p[0] - a[0], p[1] - a[1]
    tl = math.hypot(tx, ty) or 1
    tx, ty = tx / tl, ty / tl
    nx, ny = -ty, tx
    w = w1 / 2
    cap = [(p[0] + w * (nx * math.cos(t) + tx * math.sin(t)), p[1] + w * (ny * math.cos(t) + ty * math.sin(t)))
           for t in (math.pi * k / 4 for k in range(1, 4))]
    return _smooth(left + cap + right[::-1])


_m_head = _ell(186, 114, 76, 74)
_m_ear_l = _ell(106, 122, 21, 23)
_m_ear_r = _ell(264, 118, 22, 24)
_m_body = ("M150 178C176 166 222 168 242 190C260 212 262 262 254 292"
           "C246 318 220 328 192 328C164 328 140 316 134 290C126 258 130 204 150 178Z")
# 위로 든 앞팔: 어깨 → 왼쪽 팔꿈치 → 위로 세운 아래팔 → 둥근 손
_m_arm = ("M154 206C126 206 96 208 78 206C70 190 68 150 68 120"
          "C70 98 62 84 48 84C34 84 28 98 32 114C34 130 36 160 38 192"
          "C40 224 52 236 76 236C102 236 130 236 158 240Z")
_m_leg_n = ("M152 290C150 312 148 328 146 338C132 342 122 348 124 354"
            "C126 362 150 362 172 360C182 358 186 350 184 340C182 324 182 308 184 292Z")
_m_leg_f = ("M216 292C216 310 216 326 214 338C204 342 198 350 202 356"
            "C206 362 230 362 246 358C254 354 252 342 248 336C248 320 248 306 248 290Z")
_m_tail = _tube([(236, 300), (276, 318), (318, 322), (352, 304), (368, 266), (358, 228),
                 (330, 212), (306, 228), (308, 254), (328, 258)], 20, 13)

ANIMAL = dict(
    id="monkey", no=8,
    name="원숭이", base=M, ground=(206, 359, 150, 8), r=11,
    r_pairs={},
    shapes=[
        _m_tail,       # 0 꼬리(몸 뒤에서 오른쪽으로 나와 위로 말림)
        _m_leg_f,      # 1 먼 다리
        _m_body,       # 2 몸
        _m_leg_n,      # 3 앞 다리
        _m_arm,        # 4 위로 든 앞팔
        _m_ear_l,      # 5 왼 귀(머리 옆)
        _m_ear_r,      # 6 오른 귀(머리 옆)
        _m_head,       # 7 머리
    ],
    accents=[],
    creases=["M144 184C164 194 200 196 228 186"],
    details=[
        (blob(190, 266, 36, 44), FACE, 1),                                                         # 배
        (blob(104, 122, 11, 13), "#F2B8A8", 1), (blob(266, 118, 12, 14), "#F2B8A8", 1),          # 귀 안쪽
        ("M174 90C162 76 134 78 128 100C122 118 126 134 132 142C122 156 126 178 148 184"
         "C168 190 202 190 220 182C238 172 238 152 228 142C236 130 236 106 222 94C208 84 186 84 174 90Z", FACE, 1),  # 얼굴
        (blob(48, 104, 12, 13), FACE, 1),                                                          # 손바닥
        *eye(154, 118), *eye(200, 118),
        *cheek(140, 154), *cheek(220, 154),
        (blob(172, 146, 6, 4), "#5A3A28", 1),
        ("M160 162C168 170 182 170 190 162", "stroke:#7A5236", 1),
    ],
)
