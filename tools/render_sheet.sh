#!/bin/sh
# 실루엣 시트 렌더: 생성기 실행 → macOS qlmanage(Quick Look, WebKit SVG 렌더러)로 시트 SVG→PNG
# qlmanage 썸네일은 정사각이므로, .crop 파일이 있는 시트는 sips로 가운데를 잘라 그리드 비율로 맞춘다.
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_draft_silhouettes.py
D=docs/silhouette_check
for n in animals_sheet animals_sheet_nolabel animals_34_sheet animals_34_sheet_nolabel animals_side_vs_34 animals_3views animals_front34_sheet_nolabel animals_tone_compare animals_tone_compare_warmbg; do
  qlmanage -t -s 2048 -o "$D" "$D/$n.svg" >/dev/null 2>&1
  mv -f "$D/$n.svg.png" "$D/$n.png"
  if [ -f "$D/$n.crop" ]; then
    read H W < "$D/$n.crop"
    S=$(sips -g pixelWidth "$D/$n.png" | awk '/pixelWidth/{print $2}')
    # 정사각 캔버스(max(W,H)) → 렌더 크기 S로 축척 환산
    M=$(( W > H ? W : H ))
    sips -c $(( H * S / M )) $(( W * S / M )) "$D/$n.png" >/dev/null
  fi
done
ls -la "$D"
