#!/usr/bin/env python3
"""말하는 도감 - '자연스러운 실루엣' 시범 생성기 (캥거루·하마·곰·코끼리 4종).

기존 gen_draft_silhouettes.py(타원·튜브 조립)와 별개다. 여기서는 기본 도형을 쓰지 않고,
각 동물의 해부학 비율을 따라 3차 베지어로 직접 그린 유기적 외곽선(path)만 쓴다.
모든 형태는 이 파일에서 손으로 좌표를 잡은 오리지널이며 외부 이미지·기존 캐릭터를 참조하지 않는다.

한 종의 '부위 목록'(같은 path 소스)에서 세 버전을 파생한다.
  <id>_flat.svg   단색 #2A2A2A
  <id>_shade.svg  왼쪽 위 광원, 같은 회색 계열 그라데이션 + 먼 쪽 부위 약간 밝게 + 흐린 바닥 그림자
  <id>_color.svg  1단계 참고용 단순 자연색 (눈 등 디테일은 color 전용 extras 에만 있음)
부위 layer: 'far'(몸 뒤, 그림자판에서 밝게) / 'body' / 'mid'(몸 앞이지만 먼 쪽, 밝게) / 'near'(몸 앞에 겹침, 부드러운 접촉 그림자)
viewBox 0 0 400 400.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "draft_silhouettes", "natural")
SHEET = os.path.join(ROOT, "docs", "silhouette_check")

FLAT = "#2A2A2A"

# ---------------------------------------------------------------- 종 정의
# 각 part: (layer, d, color)    extras: color 버전 전용 디테일 (d, fill, opacity)

ANIMALS = {}

# 캥거루 - 왼쪽을 보는 3/4 측면, 꼬리를 땅에 대고 쉬는 자세(몸을 앞으로 기울임)
ANIMALS["kangaroo"] = dict(
    name="캥거루", ground=(232, 361, 128, 9),
    parts=[
        ("far", "M136 346C150 341 182 340 214 342C226 344 228 356 220 358L144 358C130 358 126 350 136 346Z", "#9C6B45"),
        ("far", "M190 177C184 192 172 206 160 214C154 218 152 225 158 227C166 228 176 220 186 210C196 199 202 186 204 176Z", "#9C6B45"),
        ("far", "M175 94C174 76 180 58 191 50C198 60 196 80 187 98Z", "#9C6B45"),
        ("body",
         "M108 114C114 101 132 88 150 85C163 82 172 86 179 95"
         "C188 108 196 123 207 139C236 170 268 205 280 245"
         "C285 262 288 273 292 281C306 305 332 328 372 346"
         "C381 350 381 358 372 359C342 359 310 352 282 341"
         "C270 337 260 337 255 343C250 351 253 357 246 360"
         "L132 361C117 361 109 356 113 351C119 345 150 343 192 339"
         "C199 333 182 318 177 304C172 291 177 279 188 270"
         "C177 250 169 226 167 202C165 182 160 166 150 152"
         "C143 142 137 135 131 130C122 128 114 124 108 114Z", "#B07A4F"),
        ("near", "M182 262C204 232 254 225 278 249C293 267 287 300 260 318C236 333 201 330 181 313C168 300 170 278 182 262Z", "#B07A4F"),
        ("near", "M182 168C178 186 166 204 152 216C146 221 143 228 149 231C157 233 168 224 178 214C190 202 198 187 200 172Z", "#B07A4F"),
        ("near", "M158 91C150 74 153 54 164 44C175 50 180 70 175 92Z", "#B07A4F"),
    ],
    extras=[
        ("M120 126C132 132 150 134 158 140C164 170 170 200 178 236C170 230 160 200 150 170C142 152 130 140 120 126Z", "#E2C29A", 0.8),
        ("M161 85C158 70 159 58 164 51C169 60 170 74 168 87Z", "#E8B9A0", 0.9),
        ("M134 104C134 100 140 99 141 103C141 107 135 108 134 104Z", "#1E1A17", 1),
        ("M107 114C108 110 113 110 113 114C112 117 108 117 107 114Z", "#2B211B", 1),
    ],
)

# 하마 - 왼쪽을 보는 3/4 측면, 입 닫음(머리 윤곽의 콧구멍·눈·귀 돌기가 가장 하마답다)
ANIMALS["hippo"] = dict(
    name="하마", ground=(212, 356, 172, 10),
    parts=[
        ("far", "M214 290C216 312 216 330 216 346C216 352 222 354 230 354L248 354C256 354 258 348 256 342C254 326 252 306 250 288Z", "#7F7486"),
        ("far", "M268 292C270 312 272 330 272 344C272 350 278 352 286 352L298 352C304 352 306 346 304 340C300 322 298 306 296 292Z", "#7F7486"),
        ("far", "M162 152C162 140 167 132 174 133C180 135 180 145 173 156Z", "#7F7486"),
        ("body",
         "M50 192C58 182 70 178 80 182C88 186 96 186 104 180"
         "C112 172 114 158 124 152C132 147 140 150 143 158"
         "C150 162 160 158 172 150C210 128 290 124 332 144"
         "C366 160 380 198 374 234C370 260 362 278 352 290"
         "C349 310 351 330 351 347C351 354 345 356 331 356L306 356"
         "C299 356 297 350 298 344C299 330 297 318 292 309"
         "C260 314 222 313 192 307C189 321 191 336 193 348"
         "C193 355 187 357 175 357L150 357C141 357 139 350 141 343"
         "C142 325 140 302 136 291C120 289 100 285 82 281"
         "C64 278 49 272 43 259C37 243 37 210 50 192Z", "#8E8295"),
        ("near", "M146 152C143 139 149 129 157 130C164 132 164 145 157 157Z", "#8E8295"),
        ("near", "M370 206C379 210 383 220 380 230C375 227 371 220 367 214Z", "#8E8295"),
    ],
    extras=[
        ("M46 250C70 262 104 262 132 256", "none", 1),
        ("M66 190C68 186 74 186 75 190C74 193 68 194 66 190Z", "#3A3040", 1),
        ("M127 158C128 154 134 154 135 158C134 162 128 162 127 158Z", "#1E1A1F", 1),
        ("M150 142C151 136 157 135 158 141Z", "#C99C9C", 0.9),
    ],
)

# 곰 - 왼쪽을 보는 3/4 측면 보행(얼굴은 살짝 관객 쪽, 귀 둘 다 보임)
ANIMALS["bear"] = dict(
    name="곰", ground=(212, 355, 172, 10),
    parts=[
        ("far", "M222 262C226 290 228 318 228 338C228 346 234 350 244 350L262 350C272 350 274 344 268 339C262 326 262 296 262 268Z", "#6E4E36"),
        ("far", "M282 262C288 290 292 316 294 336C295 345 300 349 310 349L326 349C334 349 336 343 330 338C324 324 322 296 318 266Z", "#6E4E36"),
        ("far", "M130 132C127 116 137 106 148 110C157 114 156 127 147 136Z", "#6E4E36"),
        ("body",
         "M56 190C58 180 66 176 78 174C88 172 92 164 96 154"
         "C102 138 116 128 132 128C146 128 158 124 172 116"
         "C188 106 214 104 232 114C258 126 290 132 320 134"
         "C350 136 372 158 374 190C376 215 368 236 360 250"
         "C356 280 358 320 360 340C362 350 356 354 344 354L314 354"
         "C302 354 299 347 307 342C314 330 312 302 305 282"
         "C280 284 240 282 206 278C204 300 202 325 200 340"
         "C200 350 196 354 184 354L150 354C138 354 136 346 146 341"
         "C154 330 153 300 150 272C140 250 118 238 98 232"
         "C88 228 76 220 68 214C60 208 56 200 56 190Z", "#7C5A3F"),
        ("near", "M104 140C97 124 104 111 116 112C127 114 128 129 122 140Z", "#7C5A3F"),
    ],
    extras=[
        ("M56 190C58 181 66 177 78 174C84 186 82 204 70 214C62 208 56 200 56 190Z", "#A88262", 0.9),
        ("M109 137C106 127 110 120 116 121C121 123 121 132 118 138Z", "#5A3E2A", 1),
        ("M54 187C55 182 61 181 63 185C63 190 57 191 54 187Z", "#1E1612", 1),
        ("M98 164C99 160 104 160 105 164C104 168 99 168 98 164Z", "#1E1612", 1),
    ],
)

# 코끼리 - 앞모습 3/4(얼굴 거의 정면, 몸은 오른쪽 뒤로), 양쪽 귀를 펼친 자세
ANIMALS["elephant"] = dict(
    name="코끼리", ground=(230, 359, 172, 10),
    parts=[
        ("far", "M346 236C350 280 352 320 352 346C352 353 356 356 364 356L376 356C382 356 384 352 383 346C380 310 380 270 380 220Z", "#8D9196"),
        ("far", "M212 232C212 276 212 320 212 350C212 357 218 360 226 360L248 360C256 360 260 356 259 349C257 320 256 276 256 234Z", "#8D9196"),
        ("far", "M384 168C392 190 395 214 392 236C397 240 397 249 390 251C383 249 383 240 388 235C388 214 385 194 379 177Z", "#8D9196"),
        ("body",
         "M120 150C140 120 180 104 230 100C280 96 330 98 356 114"
         "C380 128 390 160 388 196C386 226 378 248 366 262"
         "C330 272 284 270 252 262L222 250C210 230 200 214 192 206"
         "L150 206C130 206 116 196 112 180C110 168 114 158 120 150Z", "#9DA2A7"),
        ("body", "M300 240C302 280 302 320 302 350C302 357 308 360 316 360L334 360C342 360 345 355 344 349C342 320 344 280 346 240Z", "#9DA2A7"),
        ("mid", "M206 98C226 82 262 82 280 104C294 124 292 158 280 186C270 208 254 222 238 222C228 222 222 212 218 200C214 190 208 182 202 176Z", "#8D9196"),
        ("near", "M80 214C80 262 78 316 78 348C78 356 84 360 94 360L114 360C122 360 126 356 126 348C124 316 124 262 124 218Z", "#9DA2A7"),
        ("near", "M136 100C116 88 84 92 68 118C56 140 60 170 70 192C78 210 94 226 108 232C118 236 124 228 126 216C130 200 134 190 138 178Z", "#9DA2A7"),
        ("near",
         "M132 104C134 76 152 64 174 64C196 64 214 76 216 104"
         "C218 128 210 148 202 164C196 178 193 190 192 206"
         "C191 238 190 270 188 296C186 318 178 334 162 338"
         "C150 340 142 332 145 322C148 314 156 314 159 320"
         "C163 312 163 298 163 284C163 256 160 232 154 212"
         "C144 194 134 176 130 154C128 134 129 118 132 104Z", "#9DA2A7"),
        ("near", "M160 200C152 216 140 226 124 230C127 222 140 212 151 196Z", "#F1E8D2"),
        ("near", "M188 200C194 216 202 224 215 226C213 218 203 208 195 194Z", "#F1E8D2"),
    ],
    extras=[
        ("M128 116C108 108 88 116 80 136C74 156 80 184 98 208C108 196 116 176 122 156C126 140 128 128 128 116Z", "#C9A7A2", 0.45),
        ("M154 128C155 123 161 123 162 128C161 132 155 132 154 128Z", "#1E1F22", 1),
        ("M186 128C187 123 193 123 194 128C193 132 187 132 186 128Z", "#1E1F22", 1),
        ("M166 244C172 246 180 246 186 244", "none", 1),
        ("M166 270C172 272 178 272 184 270", "none", 1),
    ],
)

ORDER = ["kangaroo", "hippo", "bear", "elephant"]

# ---------------------------------------------------------------- 렌더
LAYER_ORDER = {"far": 0, "body": 1, "mid": 2, "near": 3}


def ordered(parts):
    return sorted(parts, key=lambda p: LAYER_ORDER[p[0]])


def group_flat(a, p):
    body = "".join(f'<path d="{d}"/>' for _, d, _ in ordered(a["parts"]))
    return f'<g fill="{FLAT}">{body}</g>'


def group_shade(a, p):
    """p: id 접두사(시트에서 여러 종을 한 문서에 넣을 때 id 충돌 방지)."""
    gx, gy, grx, gry = a["ground"]
    defs = f"""<defs>
<radialGradient id="{p}lit" gradientUnits="userSpaceOnUse" cx="135" cy="105" r="330" fx="120" fy="90">
<stop offset="0" stop-color="#555555"/><stop offset="0.45" stop-color="#3A3A3A"/><stop offset="1" stop-color="#232323"/></radialGradient>
<radialGradient id="{p}far" gradientUnits="userSpaceOnUse" cx="135" cy="105" r="330" fx="120" fy="90">
<stop offset="0" stop-color="#6E6E6E"/><stop offset="0.45" stop-color="#595959"/><stop offset="1" stop-color="#454545"/></radialGradient>
<linearGradient id="{p}floor" gradientUnits="userSpaceOnUse" x1="0" y1="240" x2="0" y2="360">
<stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.22"/></linearGradient>
<filter id="{p}blur" x="-30%" y="-200%" width="160%" height="500%"><feGaussianBlur stdDeviation="7"/></filter>
<filter id="{p}soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="4"/></filter>
<clipPath id="{p}clip">{''.join(f'<path d="{d}"/>' for l, d, _ in a['parts'] if l != 'far')}</clipPath>
</defs>"""
    out = [defs, f'<ellipse cx="{gx}" cy="{gy}" rx="{grx}" ry="{gry}" fill="#000" opacity="0.2" filter="url(#{p}blur)"/>']
    for l, d, _ in ordered(a["parts"]):
        if l == "far":
            out.append(f'<path d="{d}" fill="url(#{p}far)"/>')
        elif l == "body":
            out.append(f'<path d="{d}" fill="url(#{p}lit)"/>')
        elif l == "mid":
            # 몸 앞에 있지만 먼 쪽인 부위(예: 코끼리 먼 귀): 접촉 그림자 + 약간 밝은 톤
            out.append(f'<g clip-path="url(#{p}clip)"><path d="{d}" fill="#111" opacity="0.3" '
                       f'transform="translate(3 4)" filter="url(#{p}soft)"/></g>')
            out.append(f'<path d="{d}" fill="url(#{p}far)" opacity="0.92"/>')
        else:
            # 겹치는 앞쪽 부위: 몸 위에 부드러운 접촉 그림자(블러, 실루엣 안으로 클립) → 경계가 딱 끊기지 않음
            out.append(f'<g clip-path="url(#{p}clip)"><path d="{d}" fill="#111" opacity="0.35" '
                       f'transform="translate(3 4)" filter="url(#{p}soft)"/></g>')
            out.append(f'<path d="{d}" fill="url(#{p}lit)"/>')
    # 아래쪽(배·다리 안쪽)을 은은히 어둡게: 몸 실루엣에 선형 그라데이션을 덧씌움
    out.append(f'<g clip-path="url(#{p}clip)"><rect x="0" y="0" width="400" height="400" fill="url(#{p}floor)"/></g>')
    return "".join(out)


def shade_rgb(hexc, k):
    h = hexc.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(c * k))) for c in (r, g, b))


def group_color(a, p):
    gx, gy, grx, gry = a["ground"]
    out = [f'<defs><filter id="{p}cblur" x="-30%" y="-200%" width="160%" height="500%"><feGaussianBlur stdDeviation="7"/></filter></defs>',
           f'<ellipse cx="{gx}" cy="{gy}" rx="{grx}" ry="{gry}" fill="#000" opacity="0.15" filter="url(#{p}cblur)"/>']
    for l, d, c in ordered(a["parts"]):
        out.append(f'<path d="{d}" fill="{c}"/>')
    for d, c, op in a["extras"]:
        if c == "none":
            out.append(f'<path d="{d}" fill="none" stroke="#00000055" stroke-width="2" stroke-linecap="round"/>')
        else:
            out.append(f'<path d="{d}" fill="{c}" opacity="{op}"/>')
    return "".join(out)


VARIANTS = [("color", group_color), ("flat", group_flat), ("shade", group_shade)]


def svg_doc(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">{inner}</svg>\n'


def main():
    os.makedirs(OUT, exist_ok=True)
    for aid in ORDER:
        a = ANIMALS[aid]
        for v, fn in VARIANTS:
            with open(os.path.join(OUT, f"{aid}_{v}.svg"), "w") as fh:
                fh.write(svg_doc(fn(a, f"{aid}_{v}_")))

    # 시트: 행=종, 열=컬러|단색|자연 그림자
    cell, lw, th = 300, 110, 44
    W, H = lw + cell * 3, th + cell * len(ORDER)
    M = max(W, H)
    oy = (M - H) / 2
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{M}" height="{M}" viewBox="0 0 {M} {M}">',
         f'<rect width="{M}" height="{M}" fill="#F3EBDD"/>', f'<g transform="translate({(M - W) / 2} {oy})">',
         f'<g font-family="Apple SD Gothic Neo, sans-serif" font-size="22" fill="#6B5E4E" text-anchor="middle">']
    for i, t in enumerate(["컬러(1단계)", "단색", "자연 그림자"]):
        s.append(f'<text x="{lw + cell * i + cell / 2}" y="30">{t}</text>')
    s.append("</g>")
    for r, aid in enumerate(ORDER):
        a = ANIMALS[aid]
        y = th + cell * r
        s.append(f'<text x="{lw / 2}" y="{y + cell / 2}" font-family="Apple SD Gothic Neo, sans-serif" '
                 f'font-size="24" fill="#6B5E4E" text-anchor="middle">{a["name"]}</text>')
        for c, (v, fn) in enumerate(VARIANTS):
            x = lw + cell * c
            s.append(f'<rect x="{x + 4}" y="{y + 4}" width="{cell - 8}" height="{cell - 8}" fill="none" stroke="#DDD0BC" stroke-width="2"/>')
            s.append(f'<svg x="{x + 10}" y="{y + 10}" width="{cell - 20}" height="{cell - 20}" viewBox="20 20 380 380">'
                     f'{fn(a, f"s{aid}{v}_")}</svg>')
    s.append("</g></svg>\n")
    with open(os.path.join(SHEET, "natural_trial.svg"), "w") as fh:
        fh.write("".join(s))
    with open(os.path.join(SHEET, "natural_trial.crop"), "w") as fh:
        fh.write(f"{H} {W}\n")


if __name__ == "__main__":
    main()
