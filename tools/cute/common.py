"""말하는 도감 cute 일러스트 공용 모듈 (그림체 규칙의 코드 구현). 규칙 문서: docs/STYLE_GUIDE.md

종 파일(species/<id>.py)은 ANIMAL dict 하나만 정의한다. 이 모듈은 그 dict를 받아
  - fillets(): 부위 외곽이 만나는 오목한 꺾임에 자동 필렛(접합부를 하나의 몸처럼)
  - color_group(): 합집합 실루엣에 음영 1단계 + 주름선 + accents + details
  - shadow_group(): shapes + accents + fillets 를 #1E1E1E 단색으로(컬러와 외곽선 동일)
을 만든다. 이 파일은 공용이므로 종 작업 중에는 수정하지 않는다.

ANIMAL 키: id, no(도감 번호), name, base(본체색), ground(cx, cy, rx, ry 바닥 그림자),
  r(기본 필렛 반지름), r_pairs({(i, j): r} 선택), shapes[path], accents[(path, color)],
  creases[열린 path], details[(path, color | "stroke:#색", opacity)]
"""
import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "draft_silhouettes", "cute")
SHEET = os.path.join(ROOT, "docs", "silhouette_check")
SPECIES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "species")
SHADOW = "#1E1E1E"
BG = "#F3EBDD"

# 팔레트(파스텔 자연색). 새 종은 여기 값을 참고해 비슷한 명도·채도로 고른다(STYLE_GUIDE 참조).
PALETTE = {
    "kangaroo": "#D9A577", "hippo": "#B7A6C9", "bear": "#B98A63", "elephant": "#B8C4D0",
    "eye": "#2B2420", "highlight": "#FFFFFF", "cheek": "#F2A7A7", "ivory": "#FFFDF6",
    "inner_ear_pink": "#F2B8A8", "cream": "#F3DDBE",
}

# ---------------------------------------------------------------- 기하 도우미
def blob(cx, cy, rx, ry):
    """색 전용 디테일(눈·볼 등)에 쓰는 베지어 4분할 타원. 실루엣에는 쓰지 않는다."""
    k = 0.5523
    return (f"M{cx - rx} {cy}C{cx - rx} {cy - ry * k} {cx - rx * k} {cy - ry} {cx} {cy - ry}"
            f"C{cx + rx * k} {cy - ry} {cx + rx} {cy - ry * k} {cx + rx} {cy}"
            f"C{cx + rx} {cy + ry * k} {cx + rx * k} {cy + ry} {cx} {cy + ry}"
            f"C{cx - rx * k} {cy + ry} {cx - rx} {cy + ry * k} {cx - rx} {cy}Z")


def sample(d, n=48):
    """절대좌표 M/C/L/Z path → 닫힌 폴리라인 점 목록."""
    tok = re.findall(r"[MCLZ]|-?\d+(?:\.\d+)?", d)
    pts, cur, i, cmd = [], None, 0, None
    while i < len(tok):
        t = tok[i]
        if t in "MCLZ":
            cmd = t; i += 1
            if t == "Z":
                continue
        if cmd == "M":
            cur = (float(tok[i]), float(tok[i + 1])); pts.append(cur); i += 2; cmd = "L"
        elif cmd == "L":
            cur = (float(tok[i]), float(tok[i + 1])); pts.append(cur); i += 2
        elif cmd == "C":
            p1 = (float(tok[i]), float(tok[i + 1])); p2 = (float(tok[i + 2]), float(tok[i + 3]))
            p3 = (float(tok[i + 4]), float(tok[i + 5])); i += 6
            for k in range(1, n + 1):
                t_ = k / n; u = 1 - t_
                pts.append((u ** 3 * cur[0] + 3 * u * u * t_ * p1[0] + 3 * u * t_ * t_ * p2[0] + t_ ** 3 * p3[0],
                            u ** 3 * cur[1] + 3 * u * u * t_ * p1[1] + 3 * u * t_ * t_ * p2[1] + t_ ** 3 * p3[1]))
            cur = p3
    return pts


def inside(p, poly):
    x, y = p; c = False; n = len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            c = not c
    return c


def walk(poly, i, step, dist):
    """poly 의 i 번째 점에서 step(+1/-1) 방향으로 외곽을 따라 dist 만큼 간 점."""
    n, acc, j = len(poly), 0.0, i
    while acc < dist:
        k = (j + step) % n
        acc += math.dist(poly[j], poly[k]); j = k
        if abs(j - i) > n - 2:
            break
    return poly[j]


def crossings(pa, pb):
    """pa 외곽이 pb 경계를 넘는 지점들: (교차점, pa 인덱스, pb 밖으로 나가는 방향)."""
    res, n = [], len(pa)
    ins = [inside(p, pb) for p in pa]
    for i in range(n):
        j = (i + 1) % n
        if ins[i] != ins[j]:
            P = ((pa[i][0] + pa[j][0]) / 2, (pa[i][1] + pa[j][1]) / 2)
            res.append((P, i, +1 if not ins[j] else -1))
    return res


def fillets(shapes, r, r_pairs=None):
    """부위 외곽끼리 만나는 모든 오목 꺾임에 반지름 약 r 의 필렛 쐐기를 만든다.
    r_pairs={(i, j): r} 로 특정 부위 쌍만 반지름을 바꿀 수 있다(0 이면 생략, 예: 겨드랑이 틈 유지)."""
    r_pairs = r_pairs or {}
    polys = [sample(d) for d in shapes]
    out = []
    for a in range(len(polys)):
        for b in range(a + 1, len(polys)):
            rr = r_pairs.get((a, b), r)
            if rr <= 0:
                continue
            ca, cb = crossings(polys[a], polys[b]), crossings(polys[b], polys[a])
            for P, ia, sa in ca:
                best = min(cb, key=lambda c: math.dist(c[0], P), default=None)
                if best is None or math.dist(best[0], P) > 6:
                    continue
                Q, ib, sb = best
                C = ((P[0] + Q[0]) / 2, (P[1] + Q[1]) / 2)
                A = walk(polys[a], ia, sa, rr)
                B = walk(polys[b], ib, sb, rr)
                # 쐐기 꼭짓점을 몸 안쪽으로 5px 밀어 넣어 접합부의 머리카락 같은 틈을 덮는다
                M = ((A[0] + B[0]) / 2, (A[1] + B[1]) / 2)
                L = math.dist(M, C) or 1
                D = (C[0] + (C[0] - M[0]) / L * 5, C[1] + (C[1] - M[1]) / L * 5)
                f = lambda p: f"{p[0]:.1f} {p[1]:.1f}"
                out.append(f"M{f(A)}Q{f(C)} {f(B)}L{f(D)}Z")
    return out


def eye(cx, cy, r=7):
    return [(blob(cx, cy, r, r * 1.15), "#2B2420", 1),
            (blob(cx - r * 0.35, cy - r * 0.45, r * 0.38, r * 0.38), "#FFFFFF", 1)]


def cheek(cx, cy, rx=11, ry=7):
    return [(blob(cx, cy, rx, ry), "#F2A7A7", 0.55)]


# ---------------------------------------------------------------- 종 정의


# ---------------------------------------------------------------- 렌더
# ---------------------------------------------------------------- 렌더
def darker(hexc, k=0.9):
    h = hexc.lstrip("#")
    return "#%02X%02X%02X" % tuple(int(int(h[i:i + 2], 16) * k) for i in (0, 2, 4))


def color_group(a, p):
    gx, gy, grx, gry = a["ground"]
    body = a["shapes"] + a["fillets"]
    paths = "".join(f'<path d="{d}"/>' for d in body)
    out = [f'<path d="{blob(gx, gy, grx, gry)}" fill="#000" opacity="0.08"/>',
           f'<defs><clipPath id="{p}u">{paths}</clipPath>']
    for i, (d, _) in enumerate(a["accents"]):
        out.append(f'<clipPath id="{p}a{i}"><path d="{d}"/></clipPath>')
    out.append("</defs>")
    # 합집합 실루엣에 음영 1단계(한 번만): 어두운 색 위에 왼쪽 위로 비킨 본체색을 덮음
    out.append(f'<g fill="{darker(a["base"])}">{paths}</g>')
    out.append(f'<g clip-path="url(#{p}u)"><g fill="{a["base"]}" transform="translate(-5 -6)">{paths}</g></g>')
    for d in a["creases"]:
        out.append(f'<path d="{d}" fill="none" stroke="{darker(a["base"], 0.84)}" stroke-width="2.5" '
                   f'stroke-linecap="round" opacity="0.6"/>')
    for i, (d, c) in enumerate(a["accents"]):
        out.append(f'<path d="{d}" fill="{darker(c, 0.9)}"/>'
                   f'<g clip-path="url(#{p}a{i})"><path d="{d}" fill="{c}" transform="translate(-2 -2)"/></g>')
    for d, c, op in a["details"]:
        if c.startswith("stroke:"):
            out.append(f'<path d="{d}" fill="none" stroke="{c[7:]}" stroke-width="3" stroke-linecap="round"/>')
        else:
            out.append(f'<path d="{d}" fill="{c}" opacity="{op}"/>')
    return "".join(out)


def shadow_group(a, p):
    ds = a["shapes"] + [d for d, _ in a["accents"]] + a["fillets"]
    return f'<g fill="{SHADOW}">' + "".join(f'<path d="{d}"/>' for d in ds) + "</g>"


def svg_doc(inner, size=400):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="{size}" height="{size}">{inner}</svg>\n'


def prepare(a):
    """ANIMAL dict 에 fillets 를 계산해 넣는다(이미 있으면 그대로)."""
    if "fillets" not in a:
        a["fillets"] = fillets(a["shapes"] + [d for d, _ in a.get("accents", [])], a.get("r", 11), a.get("r_pairs"))
    a.setdefault("accents", []); a.setdefault("creases", []); a.setdefault("details", [])
    return a


def load_species(only=None):
    """species/ 폴더를 자동 탐색해 ANIMAL dict 목록을 도감 번호순으로 반환('_'로 시작하는 파일 제외)."""
    import importlib.util
    import sys
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    res = []
    for fn in sorted(os.listdir(SPECIES_DIR)):
        if not fn.endswith(".py") or fn.startswith("_"):
            continue
        sid = fn[:-3]
        if only and sid not in only:
            continue
        spec = importlib.util.spec_from_file_location(f"cute_species_{sid}", os.path.join(SPECIES_DIR, fn))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        a = mod.ANIMAL
        assert a["id"] == sid, f"{fn}: ANIMAL id({a['id']}) 와 파일 이름이 달라요"
        res.append(prepare(a))
    return sorted(res, key=lambda a: a.get("no", 99))


def render_png(svg_path, png_path, size, crop_hw=None):
    """macOS qlmanage(Quick Look)로 SVG→PNG. qlmanage 결과는 정사각이므로 crop_hw=(h, w) 비율로 가운데를 자른다."""
    import shutil
    import subprocess
    import tempfile
    tmp = tempfile.mkdtemp(prefix="cute_ql_")
    subprocess.run(["qlmanage", "-t", "-s", str(size), "-o", tmp, svg_path],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    out = os.path.join(tmp, os.path.basename(svg_path) + ".png")
    shutil.move(out, png_path)
    shutil.rmtree(tmp, ignore_errors=True)
    if crop_hw:
        h, w = crop_hw
        m = max(h, w)
        subprocess.run(["sips", "-c", str(h * size // m), str(w * size // m), png_path],
                       stdout=subprocess.DEVNULL, check=True)
