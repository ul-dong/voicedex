#!/usr/bin/env python3
"""cute 일러스트 빌드: species/<id>.py → assets/draft_silhouettes/cute/<id>_color.svg, <id>_shadow.svg

  python3 tools/cute/build.py                     # 등록된 모든 종
  python3 tools/cute/build.py --only giraffe      # 특정 종만(쉼표로 여러 개). 병렬 작업 시 반드시 이것을 쓴다.
  python3 tools/cute/build.py --only giraffe --zoom <폴더>
      # 확대 검사용 <폴더>/zoom_<id>.png (왼쪽 컬러 | 오른쪽 그림자, 2048x1024)
다른 종의 파일은 건드리지 않는다(--only 종의 두 SVG 만 씀).
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402


def write_species(a):
    os.makedirs(common.OUT, exist_ok=True)
    for kind, fn in (("color", common.color_group), ("shadow", common.shadow_group)):
        with open(os.path.join(common.OUT, f"{a['id']}_{kind}.svg"), "w") as fh:
            fh.write(common.svg_doc(fn(a, f"{a['id']}_")))


def write_zoom(a, zdir):
    os.makedirs(zdir, exist_ok=True)
    svg = os.path.join(zdir, f"zoom_{a['id']}.svg")
    with open(svg, "w") as fh:
        fh.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800">'
                 f'<rect width="800" height="800" fill="{common.BG}"/>'
                 f'<svg x="0" y="200" width="400" height="400" viewBox="0 0 400 400">{common.color_group(a, "zc_")}</svg>'
                 f'<svg x="400" y="200" width="400" height="400" viewBox="0 0 400 400">{common.shadow_group(a, "zs_")}</svg>'
                 f'</svg>\n')
    png = svg[:-4] + ".png"
    common.render_png(svg, png, 2048, crop_hw=(400, 800))
    return png


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="쉼표로 구분한 종 id")
    ap.add_argument("--zoom", help="확대 검사 PNG 를 쓸 폴더")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    animals = common.load_species(only)
    if only and len(animals) != len(only):
        sys.exit(f"species/ 에 없는 id: {only - {a['id'] for a in animals}}")
    for a in animals:
        write_species(a)
        msg = f"{a['id']}: shapes {len(a['shapes'])}, fillets {len(a['fillets'])}"
        if args.zoom:
            msg += f" → {write_zoom(a, args.zoom)}"
        print(msg)


if __name__ == "__main__":
    main()
