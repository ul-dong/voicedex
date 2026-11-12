#!/usr/bin/env python3
"""등록된 모든 종(species/ 자동 탐색)으로 검사 시트를 만든다.
  docs/silhouette_check/cute_trial.png         행=종, 열=컬러|그림자 (5종 이상이면 한 행에 2종)
  docs/silhouette_check/cute_trial_shadows.png 그림자만 라벨 없이 격자(4종 이하 2열, 그 이상 4열)
  python3 tools/cute/sheet.py
병렬 작업 중에는 각자 build.py --zoom 으로 확인하고, 시트는 통합 단계에서 한 번만 돌린다.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

FONT = 'font-family="Apple SD Gothic Neo, sans-serif" fill="#6B5E4E" text-anchor="middle"'


def write(name, W, H, body, size=1600):
    M = max(W, H)
    svg = os.path.join(common.SHEET, name + ".svg")
    with open(svg, "w") as fh:
        fh.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{M}" height="{M}" viewBox="0 0 {M} {M}">'
                 f'<rect width="{M}" height="{M}" fill="{common.BG}"/>'
                 f'<g transform="translate({(M - W) / 2} {(M - H) / 2})">{body}</g></svg>\n')
    with open(os.path.join(common.SHEET, name + ".crop"), "w") as fh:
        fh.write(f"{H} {W}\n")
    common.render_png(svg, os.path.join(common.SHEET, name + ".png"), size, crop_hw=(H, W))


def cell_svg(x, y, s, inner):
    return f'<svg x="{x}" y="{y}" width="{s}" height="{s}" viewBox="0 0 400 400">{inner}</svg>'


def main():
    animals = common.load_species()
    n = len(animals)
    per_row = 1 if n <= 4 else 2
    rows = -(-n // per_row)
    cell, lw, th = 340, 110, 44
    blockw = lw + cell * 2
    W, H = blockw * per_row, th + cell * rows
    b = []
    for k in range(per_row):
        b.append(f'<text x="{k * blockw + lw + cell / 2}" y="30" font-size="22" {FONT}>컬러</text>')
        b.append(f'<text x="{k * blockw + lw + cell * 1.5}" y="30" font-size="22" {FONT}>그림자</text>')
    for i, a in enumerate(animals):
        ox, y = (i % per_row) * blockw, th + cell * (i // per_row)
        b.append(f'<text x="{ox + lw / 2}" y="{y + cell / 2}" font-size="24" {FONT}>{a["name"]}</text>')
        for c, fn in enumerate((common.color_group, common.shadow_group)):
            x = ox + lw + cell * c
            b.append(f'<rect x="{x + 4}" y="{y + 4}" width="{cell - 8}" height="{cell - 8}" fill="none" stroke="#DDD0BC" stroke-width="2"/>')
            b.append(cell_svg(x + 10, y + 10, cell - 20, fn(a, f"t{a['id']}{c}_")))
    write("cute_trial", W, H, "".join(b))

    cols = 2 if n <= 4 else 4
    cell = 380
    b = [cell_svg(cell * (i % cols) + 10, cell * (i // cols) + 10, cell - 20, common.shadow_group(a, ""))
         for i, a in enumerate(animals)]
    write("cute_trial_shadows", cell * cols, cell * (-(-n // cols)), "".join(b))
    print(f"{n}종 시트 완료: {', '.join(a['id'] for a in animals)}")


if __name__ == "__main__":
    main()
