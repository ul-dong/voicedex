#!/usr/bin/env python3
"""말하는 도감(voicedex) - 동물 실루엣 검사용 초안 생성기.

검사용 초안(DRAFT)이다. 최종 그림이 아니다.
모든 형태는 이 스크립트의 기하 도형(타원·튜브·다각형)을 조합해 직접 그린 오리지널이며
외부 이미지/기존 캐릭터를 참조하지 않는다.
출력: assets/draft_silhouettes/animals/<id>.svg  (viewBox 0 0 512 512, 검정 단색, 오른쪽을 보는 측면)
      docs/silhouette_check/animals_sheet.svg / animals_sheet_nolabel.svg (렌더용 합본)
"""
import math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "draft_silhouettes", "animals")
SHEET = os.path.join(ROOT, "docs", "silhouette_check")


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def ell(cx, cy, rx, ry, rot=0):
    a = math.radians(rot)
    dx, dy = rx * math.cos(a), rx * math.sin(a)
    p1 = (cx + dx, cy + dy)
    p2 = (cx - dx, cy - dy)
    return (f"M{f(p1[0])} {f(p1[1])}A{f(rx)} {f(ry)} {f(rot)} 1 0 {f(p2[0])} {f(p2[1])}"
            f"A{f(rx)} {f(ry)} {f(rot)} 1 0 {f(p1[0])} {f(p1[1])}Z")


def circ(cx, cy, r):
    return ell(cx, cy, r, r)


def poly(*pts):
    return "M" + "L".join(f"{f(x)} {f(y)}" for x, y in pts) + "Z"


def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return (u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1])


def tube(ctrl, w0, w1, n=40, caps=True):
    """3차 베지어(4점)·2차처럼 쓰는 3점·직선(2점)을 따라 폭이 w0→w1로 변하는 채워진 튜브."""
    if len(ctrl) == 2:
        (x0, y0), (x1, y1) = ctrl
        ctrl = [(x0, y0), (x0 + (x1 - x0) / 3, y0 + (y1 - y0) / 3),
                (x0 + 2 * (x1 - x0) / 3, y0 + 2 * (y1 - y0) / 3), (x1, y1)]
    elif len(ctrl) == 3:
        ctrl = [ctrl[0], ctrl[1], ctrl[1], ctrl[2]]
    pts = [bez(*ctrl, i / n) for i in range(n + 1)]
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1
        nx, ny = -ty / L, tx / L
        w = (w0 + (w1 - w0) * i / n) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    d = poly(*(left + right[::-1]))
    if caps:
        d += circ(*pts[0], w0 / 2) + circ(*pts[-1], w1 / 2)
    return d


def leg(x, top, bottom, w, foot=None):
    """수직 다리 + 발."""
    d = tube([(x, top), (x, bottom - w * 0.3)], w, w * 0.92, caps=False)
    fh = foot if foot else w * 0.55
    d += ell(x + 2, bottom - fh * 0.5, w * 0.55, fh * 0.5)
    return d


def spiky(cx, cy, rx, ry, depth, n, rot0=0):
    """갈기용 들쭉날쭉한 원."""
    out = []
    for i in range(n):
        a0 = math.radians(rot0 + 360 * i / n)
        a1 = math.radians(rot0 + 360 * (i + 0.5) / n)
        out.append(((cx + rx * math.cos(a0), cy + ry * math.sin(a0)),
                    (cx + (rx - depth) * math.cos(a1), cy + (ry - depth) * math.sin(a1))))
    d = f"M{f(out[-1][1][0])} {f(out[-1][1][1])}"
    for i in range(n):
        tip, valley = out[i]
        d += f"Q{f(tip[0])} {f(tip[1])} {f(valley[0])} {f(valley[1])}"
    return d + "Z"


# ---------------------------------------------------------------- 종별 형태
G = 480  # 지면선


def elephant():  # 단서: 긴 코
    return [
        ell(225, 240, 155, 118),                  # 몸통
        ell(372, 190, 72, 80),                    # 머리
        ell(330, 205, 52, 88, 12),                # 귀(큰 부채)
        tube([(420, 210), (478, 280), (462, 390), (492, 452)], 50, 24),  # 긴 코
        tube([(492, 452), (500, 468), (486, 478), (476, 466)], 24, 18),  # 코끝 말림
        leg(115, 290, G, 58), leg(170, 300, G - 6, 56),
        leg(300, 300, G, 60), leg(352, 280, G - 6, 56),
        tube([(72, 220), (50, 250), (44, 300), (48, 335)], 10, 6),      # 꼬리
        ell(48, 342, 7, 12),
    ]


def giraffe():  # 단서: 긴 목
    return [
        ell(205, 290, 112, 58, -12),              # 몸통(어깨가 높음)
        tube([(270, 280), (320, 205), (365, 130), (392, 70)], 66, 34),  # 긴 목
        ell(420, 72, 52, 24, 28),                 # 머리(코가 아래로)
        tube([(392, 52), (386, 20)], 9, 8), circ(386, 18, 9),  # 뿔(오시콘)
        tube([(410, 54), (408, 22)], 9, 8), circ(408, 20, 9),
        tube([(376, 62), (348, 54)], 14, 6),      # 귀
        leg(120, 320, G, 22, 18), leg(152, 320, G - 4, 21, 18),
        leg(262, 290, G, 23, 18), leg(292, 290, G - 4, 22, 18),
        tube([(100, 280), (78, 330), (74, 370), (78, 405)], 9, 5), ell(80, 414, 9, 16),
    ]


def lion():  # 단서: 갈기
    return [
        ell(225, 305, 140, 72),                   # 몸통
        spiky(355, 235, 108, 118, 24, 18, 5),     # 갈기
        ell(450, 258, 44, 36, 10),                # 주둥이(갈기 밖으로)
        leg(120, 330, G, 38), leg(165, 340, G - 6, 36),
        leg(300, 330, G, 40), leg(345, 320, G - 6, 38),
        tube([(90, 290), (40, 320), (30, 400), (62, 430)], 13, 9),  # 꼬리
        ell(66, 436, 16, 20, 30),                 # 꼬리 술
    ]


def rabbit():  # 단서: 긴 귀 (앉은 자세, 작은 동그란 꼬리)
    return [
        ell(225, 360, 130, 105),                  # 몸통(웅크림)
        ell(190, 395, 105, 80),                   # 뒷다리 허벅지
        ell(345, 270, 78, 64, 10),                # 머리
        ell(400, 290, 40, 32),                    # 주둥이
        ell(318, 128, 30, 100, -14),              # 긴 귀
        ell(362, 125, 28, 100, 8),                # 긴 귀
        ell(345, 462, 46, 18),                    # 앞발
        ell(225, 466, 100, 18),                   # 뒷발(길다)
        circ(98, 345, 32),                        # 동그란 꼬리
    ]


def penguin():  # 단서: 직립 자세
    return [
        ell(250, 300, 118, 178, 6),               # 몸통(달걀형, 서 있음)
        ell(280, 112, 74, 70),                    # 머리
        poly((340, 98), (412, 120), (338, 132)),  # 부리
        ell(160, 290, 30, 112, 22),               # 날개(뒤로 펼침)
        poly((150, 430), (100, 470), (175, 462)), # 꼬리깃
        ell(290, 474, 70, 14),                    # 발
    ]


def bear():  # 단서: 둥근 등, 짧은 목, 머리가 낮다
    return [
        ell(235, 275, 165, 104),                  # 몸통
        ell(290, 195, 104, 86),                   # 어깨 혹(둥근 등, 높게)
        ell(405, 285, 70, 60),                    # 머리(낮게)
        ell(462, 302, 40, 28, 8),                 # 주둥이
        circ(380, 218, 26), circ(418, 224, 20),   # 둥근 귀 2개
        leg(115, 300, G, 64), leg(170, 320, G - 6, 60),
        leg(300, 320, G, 64), leg(355, 310, G - 6, 60),
        ell(70, 250, 16, 14),                     # 짧은 꼬리
    ]


def hippo():  # 단서: 크게 벌린 입(네모난 턱 + 이빨), 통 몸통, 아주 짧은 다리
    return [
        ell(215, 335, 175, 100),                  # 통 몸통
        ell(352, 300, 82, 80),                    # 큰 머리
        tube([(372, 272), (468, 196)], 84, 74),   # 위턱(위로 크게 벌어짐, 네모난 덩어리)
        circ(470, 172, 16),                       # 콧구멍 돌기
        tube([(380, 348), (480, 350)], 62, 58),   # 아래턱(두툼)
        poly((448, 322), (458, 284), (468, 322)), # 아래 엄니
        poly((404, 322), (412, 292), (420, 322)),
        poly((440, 232), (452, 262), (462, 222)), # 위 이빨
        circ(318, 228, 15), circ(296, 238, 12),   # 작은 귀
        circ(350, 222, 15),                       # 눈 돌기
        leg(100, 400, G, 54), leg(160, 410, G - 4, 52),
        leg(280, 405, G, 56), leg(335, 395, G - 4, 52),
        poly((42, 320), (20, 330), (42, 345)),    # 꼬리
    ]


def monkey():  # 단서: 긴 팔과 긴(말린) 꼬리
    return [
        ell(255, 285, 62, 98, 14),                # 몸통
        circ(292, 150, 52),                       # 머리
        ell(338, 166, 30, 24),                    # 주둥이
        circ(250, 150, 20),                       # 귀
        tube([(282, 220), (350, 210), (410, 160), (448, 82)], 24, 18),  # 위로 뻗은 긴 팔
        ell(452, 70, 16, 22, 20),                 # 손
        tube([(245, 225), (222, 310), (210, 390), (218, 460)], 24, 18), # 땅까지 닿는 긴 팔
        ell(226, 470, 22, 12),
        tube([(240, 355), (205, 400), (220, 440), (200, 470)], 32, 22), # 다리
        tube([(285, 360), (320, 410), (305, 440), (318, 470)], 32, 22),
        ell(206, 474, 24, 10), ell(326, 474, 24, 10),
        tube([(205, 350), (90, 380), (40, 260), (110, 210)], 16, 12),   # 긴 꼬리
        tube([(110, 210), (160, 180), (170, 250), (128, 245)], 12, 9),  # 꼬리 끝 말림
    ]


def crocodile():  # 단서: 낮고 긴 몸
    d = [
        ell(250, 405, 175, 42),                   # 몸통(낮고 길다)
        poly((395, 380), (505, 400), (505, 414), (395, 432)),  # 긴 주둥이
        ell(405, 392, 28, 20),                    # 머리 뒤
        circ(420, 376, 9),                        # 눈 돌기
        tube([(100, 402), (60, 410), (30, 420), (8, 404)], 62, 8),  # 굵은 꼬리 → 가늘게
        tube([(330, 425), (345, 450), (360, 470)], 28, 22), ell(368, 474, 22, 8),
        tube([(170, 425), (160, 450), (150, 470)], 30, 24), ell(158, 474, 24, 8),
    ]
    for i, x in enumerate(range(110, 380, 30)):  # 등 돌기
        d.append(poly((x - 10, 372), (x, 352 - (4 if i % 2 else 0)), (x + 10, 372)))
    return d


def rhino():  # 단서: 코 위의 큰 뿔, 뾰족 귀, 숙인 머리
    return [
        ell(225, 280, 165, 108),                  # 몸통
        ell(395, 325, 82, 56, 24),                # 머리(아래로 숙임)
        ell(450, 362, 40, 32, 20),                # 코
        "M445 345Q470 290 492 222Q478 300 482 360Z",   # 큰 뿔
        "M410 318Q418 292 432 268Q432 300 440 330Z",   # 작은 뿔
        tube([(350, 270), (345, 240), (338, 212)], 22, 8),  # 뾰족한 귀
        leg(110, 320, G, 60), leg(165, 330, G - 6, 56),
        leg(300, 330, G, 62), leg(352, 320, G - 6, 58),
        tube([(62, 260), (48, 290), (46, 320)], 10, 6), ell(46, 328, 7, 12),
    ]


def kangaroo():  # 단서: 꼬리로 받친 직립 앉은 자세, 굵은 꼬리, 긴 뒷발
    return [
        ell(290, 270, 70, 118, 18),               # 상체(앞으로 기움)
        ell(255, 372, 90, 80),                    # 엉덩이·허벅지
        tube([(270, 410), (300, 440), (320, 458)], 48, 30),  # 정강이 → 발로 연결
        ell(330, 462, 110, 18),                   # 긴 뒷발
        tube([(215, 400), (150, 440), (90, 462), (22, 468)], 64, 16),  # 굵은 꼬리(땅을 짚음)
        tube([(325, 185), (340, 160), (352, 140)], 52, 44),            # 목
        ell(375, 128, 55, 32, 16),                # 머리(길쭉)
        tube([(345, 108), (330, 60)], 22, 10),    # 귀(중간 길이)
        tube([(362, 104), (360, 56)], 20, 10),
        tube([(345, 225), (385, 250), (398, 285)], 18, 12),  # 짧은 앞발
    ]


def camel():  # 단서: 등의 혹 2개, 앞으로 굽은 목
    return [
        ell(230, 250, 140, 66),                   # 몸통
        ell(180, 185, 58, 64),                    # 혹 1
        ell(285, 185, 56, 62),                    # 혹 2
        tube([(335, 245), (405, 275), (432, 205), (422, 140)], 52, 34),  # 굽은 목
        ell(452, 132, 48, 24, 12),                # 머리
        tube([(420, 122), (412, 104)], 12, 6),    # 귀
        leg(130, 285, G, 26, 16), leg(160, 285, G - 4, 25, 16),
        leg(295, 285, G, 27, 16), leg(325, 280, G - 4, 26, 16),
        tube([(92, 240), (78, 280), (76, 320)], 9, 5), ell(76, 328, 6, 12),
    ]


ANIMALS = [
    ("elephant", "코끼리", elephant), ("giraffe", "기린", giraffe), ("lion", "사자", lion),
    ("rabbit", "토끼", rabbit), ("penguin", "펭귄", penguin), ("bear", "곰", bear),
    ("hippo", "하마", hippo), ("monkey", "원숭이", monkey), ("crocodile", "악어", crocodile),
    ("rhino", "코뿔소", rhino), ("kangaroo", "캥거루", kangaroo), ("camel", "낙타", camel),
]


# ---------------------------------------------------------------- 3/4 앞모습 (정면에서 약 30~45도 돌림)
# 규칙: 머리가 관객 쪽(오른쪽 앞)에 크게, 몸통은 왼쪽 뒤로 물러남.
# 앞다리 두 개는 지면선 G에, 뒷다리 두 개는 원근 때문에 조금 위(G-14~-20)에 둔다.
GB = G - 16  # 뒷다리 지면선


def elephant34():  # 긴 코 + 양쪽 큰 귀
    return [
        ell(165, 245, 135, 112),                  # 몸통(뒤로)
        ell(228, 200, 78, 108, -12),              # 먼 쪽 귀(왼쪽, 부채)
        ell(410, 180, 54, 88, 14),                # 가까운 쪽 귀(오른쪽)
        ell(330, 195, 82, 88),                    # 머리(정면 쪽)
        tube([(336, 250), (350, 340), (430, 350), (462, 262)], 56, 28),  # 긴 코(S자로 앞으로 들어 올림)
        tube([(462, 262), (478, 222), (452, 206), (440, 228)], 28, 18),  # 코끝 말림
        leg(262, 300, G, 64), leg(372, 330, G - 2, 62),   # 앞다리
        leg(105, 300, GB, 54), leg(165, 310, GB + 4, 54),  # 뒷다리
        tube([(36, 230), (26, 270), (28, 310)], 10, 6), ell(28, 318, 7, 12),
    ]


def giraffe34():  # 긴 목, 정면을 향한 머리, 양쪽 뿔·귀
    return [
        ell(190, 330, 98, 60, -16),               # 몸통
        tube([(250, 318), (282, 230), (318, 150), (336, 96)], 66, 36),  # 긴 목
        ell(340, 84, 42, 34),                     # 머리(정면 쪽)
        ell(366, 116, 28, 22, 30),                # 주둥이(앞-아래)
        ell(268, 335, 50, 38),                    # 가슴
        tube([(326, 58), (318, 22)], 9, 8), circ(318, 20, 9),   # 뿔 2개(좌우로 벌어짐)
        tube([(354, 56), (362, 22)], 9, 8), circ(362, 20, 9),
        tube([(310, 78), (276, 66)], 14, 6), tube([(372, 74), (404, 58)], 14, 6),  # 양쪽 귀
        leg(248, 350, G, 24, 18), leg(296, 340, G - 2, 23, 18),
        leg(138, 360, GB, 21, 16), leg(172, 365, GB + 4, 21, 16),
        tube([(100, 330), (84, 380), (86, 420)], 9, 5), ell(88, 428, 9, 15),
    ]


def lion34():  # 얼굴을 둘러싼 둥근 갈기
    return [
        ell(165, 305, 125, 75, -6),               # 몸통(뒤로)
        spiky(320, 225, 122, 128, 26, 20, 4),     # 갈기(정면에 가까워 둥근 후광)
        ell(350, 278, 48, 40),                    # 주둥이
        ell(332, 330, 66, 42),                    # 가슴
        leg(290, 320, G, 42), leg(370, 320, G - 2, 40),
        leg(100, 330, GB, 36), leg(150, 340, GB + 4, 36),
        tube([(48, 285), (14, 320), (16, 400), (44, 424)], 13, 9),
        ell(50, 430, 16, 20, 30),
    ]


def rabbit34():  # 긴 귀 2개(V자로 벌어짐), 웅크린 몸
    return [
        ell(225, 365, 120, 102),                  # 몸통
        ell(180, 400, 98, 74),                    # 허벅지
        ell(318, 268, 76, 64),                    # 머리
        ell(350, 300, 38, 30),                    # 주둥이
        ell(270, 128, 28, 98, -16),               # 귀(좌)
        ell(352, 124, 27, 98, 16),                # 귀(우)
        ell(318, 466, 30, 16), ell(368, 462, 28, 15),  # 앞발 2개
        ell(196, 466, 92, 18),                    # 뒷발
        circ(100, 360, 30),                       # 꼬리
    ]


def penguin34():  # 직립, 양쪽 날개, 두 발
    return [
        ell(250, 300, 122, 180),                  # 몸통
        ell(266, 110, 72, 68),                    # 머리
        poly((318, 110), (380, 134), (316, 150)), # 부리(앞-오른쪽)
        ell(138, 300, 26, 106, 16),               # 날개(좌)
        ell(368, 300, 24, 100, -16),              # 날개(우)
        ell(214, 476, 44, 13), ell(298, 478, 44, 13),  # 발 2개
    ]


def bear34():  # 정면 쪽 큰 머리 + 둥근 귀 2개 + 짧은 주둥이, 뒤로 둥근 등
    return [
        ell(175, 300, 140, 98),                   # 몸통
        ell(200, 240, 118, 100),                  # 둥근 등(어깨 혹)
        circ(330, 232, 80),                       # 머리(크고 둥글게)
        circ(270, 162, 30), circ(390, 160, 28),   # 둥근 귀 2개(좌우)
        ell(360, 280, 40, 32),                    # 짧은 주둥이
        ell(326, 322, 86, 52),                    # 가슴
        leg(285, 320, G, 66), leg(375, 320, G - 2, 62),
        leg(100, 330, GB, 58), leg(160, 340, GB + 4, 58),
    ]


def hippo34():  # 정면을 향해 크게 벌린 입, 통 몸통, 짧은 다리
    return [
        ell(185, 330, 160, 100),                  # 통 몸통
        ell(330, 330, 90, 78),                    # 큰 머리
        tube([(345, 290), (410, 180)], 120, 108), # 위턱(넓적, 위로 벌어짐)
        circ(390, 140, 18), circ(440, 158, 18),   # 콧구멍 돌기 2개
        tube([(340, 370), (450, 392)], 80, 74),   # 아래턱
        poly((392, 360), (400, 322), (410, 360)), # 아래 엄니
        poly((440, 368), (448, 330), (458, 368)),
        poly((436, 228), (444, 262), (456, 220)), # 위 이빨
        circ(268, 248, 15), circ(300, 238, 12),   # 작은 귀
        leg(290, 405, G, 58), leg(380, 410, G - 2, 54),
        leg(80, 400, GB, 50), leg(140, 410, GB + 4, 50),
        poly((28, 318), (8, 330), (28, 344)),
    ]


def monkey34():  # 긴 팔 + 몸 뒤로 휘감는 긴 꼬리, 양쪽 귀
    return [
        ell(255, 290, 66, 98, 8),                 # 몸통
        circ(280, 152, 54),                       # 머리
        circ(222, 156, 20), circ(338, 150, 18),   # 양쪽 귀
        ell(304, 182, 32, 24),                    # 주둥이
        tube([(300, 225), (365, 205), (418, 150), (446, 74)], 24, 18),  # 위로 뻗은 팔
        ell(450, 62, 16, 22, 20),
        tube([(212, 230), (186, 310), (176, 390), (186, 462)], 24, 18), # 땅에 닿는 팔
        ell(194, 470, 22, 12),
        tube([(236, 360), (220, 410), (236, 440), (226, 472)], 32, 22),
        tube([(286, 360), (312, 410), (300, 440), (312, 472)], 32, 22),
        ell(232, 476, 24, 10), ell(320, 476, 24, 10),
        tube([(220, 370), (110, 420), (40, 300), (90, 220)], 16, 12),   # 긴 꼬리
        tube([(90, 220), (130, 170), (170, 230), (128, 240)], 12, 9),
    ]


def crocodile34():  # 머리가 앞, 몸은 대각선 뒤로 길게, 꼬리 S자
    d = [
        poly((330, 392), (500, 440), (500, 462), (330, 448)),   # 긴 주둥이(앞으로)
        ell(318, 414, 62, 40),                    # 머리
        circ(300, 378, 11), circ(340, 380, 10),   # 눈 돌기 2개
        tube([(300, 405), (230, 370), (165, 340), (110, 320)], 96, 66),  # 몸(대각선으로 물러남)
        tube([(110, 320), (50, 300), (30, 250), (90, 222)], 66, 8),      # 꼬리(S자로 휘어 보이게)
        tube([(338, 440), (360, 470)], 28, 22), ell(366, 474, 22, 8),    # 앞다리(가까운)
        tube([(258, 400), (236, 440)], 26, 20), ell(232, 444, 20, 7),    # 앞다리(먼)
        tube([(170, 362), (186, 400)], 28, 22), ell(192, 404, 22, 8),    # 뒷다리
        tube([(128, 345), (106, 380)], 24, 18), ell(102, 384, 18, 7),
    ]
    for i in range(9):  # 등 돌기(몸 윗선을 따라)
        t = i / 8
        x = 290 - 190 * t; y = 360 - 66 * t
        d.append(poly((x - 10, y + 8), (x - 2, y - 14), (x + 8, y + 6)))
    return d


def rhino34():  # 앞으로 내민 코끝 위의 큰 뿔, 몸 뒤쪽의 뾰족 귀
    return [
        ell(165, 285, 135, 95),                   # 몸통
        ell(322, 322, 80, 60, 20),                # 머리
        ell(392, 370, 46, 36),                    # 코(앞으로 돌출)
        ell(320, 352, 74, 44),                    # 가슴
        "M372 356Q410 300 446 222Q430 310 428 376Z",   # 큰 뿔(코끝)
        "M342 326Q352 302 366 282Q366 308 372 338Z",   # 작은 뿔
        tube([(286, 278), (282, 250), (278, 222)], 22, 8),  # 귀(좌)
        tube([(330, 272), (338, 246), (346, 220)], 20, 8),  # 귀(우)
        leg(280, 330, G, 64), leg(372, 345, G - 2, 58),
        leg(95, 320, GB, 56), leg(155, 330, GB + 4, 56),
        tube([(36, 270), (24, 300), (24, 330)], 10, 6), ell(24, 338, 7, 12),
    ]


def kangaroo34():  # 직립 앉은 자세, 왼쪽 뒤로 길게 뻗은 굵은 꼬리
    return [
        ell(282, 268, 74, 118, 8),                # 상체
        ell(250, 370, 96, 80),                    # 허벅지
        tube([(276, 410), (300, 440), (318, 458)], 46, 30),
        ell(330, 464, 84, 16), ell(250, 456, 70, 13),  # 뒷발 2개(앞/뒤)
        tube([(200, 405), (140, 438), (80, 452), (18, 446)], 62, 16),  # 굵은 꼬리
        tube([(300, 180), (306, 160)], 54, 48),   # 목
        ell(306, 132, 44, 38),                    # 머리(정면 쪽)
        ell(334, 150, 30, 22, 15),                # 주둥이
        tube([(286, 104), (262, 52)], 22, 10),    # 귀(좌)
        tube([(326, 102), (346, 50)], 22, 10),    # 귀(우)
        tube([(318, 228), (348, 262), (352, 290)], 18, 12),  # 앞발
        tube([(262, 232), (252, 270), (262, 296)], 16, 11),
    ]


def camel34():  # 혹 2개가 보이도록 몸을 많이 돌리지 않음, 앞으로 굽은 목
    return [
        ell(200, 262, 128, 62, -4),               # 몸통
        ell(145, 192, 56, 62),                    # 혹 1(뒤)
        ell(245, 188, 56, 64),                    # 혹 2(앞)
        tube([(296, 262), (358, 296), (382, 222), (370, 150)], 54, 36),  # 굽은 목
        ell(384, 138, 40, 28, 18),                # 머리(정면 쪽)
        ell(410, 156, 24, 18, 30),                # 주둥이
        tube([(360, 120), (346, 100)], 12, 6), tube([(400, 118), (410, 98)], 12, 6),  # 양쪽 귀
        leg(292, 300, G, 28, 16), leg(334, 290, G - 2, 27, 16),
        leg(110, 295, GB, 25, 15), leg(140, 295, GB + 4, 25, 15),
        tube([(74, 250), (62, 290), (62, 330)], 9, 5), ell(62, 338, 6, 12),
    ]


ANIMALS_34 = {
    "elephant": elephant34, "giraffe": giraffe34, "lion": lion34, "rabbit": rabbit34,
    "penguin": penguin34, "bear": bear34, "hippo": hippo34, "monkey": monkey34,
    "crocodile": crocodile34, "rhino": rhino34, "kangaroo": kangaroo34, "camel": camel34,
}
OUT34 = os.path.join(ROOT, "assets", "draft_silhouettes", "animals_34")


def svg_file(ko, aid, p, view):
    paths = "\n".join(f'    <path d="{d}"/>' for d in p)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">\n'
            f'  <!-- DRAFT / 검사용 초안: {ko}({aid}) {view} 실루엣. 최종 그림 아님. '
            f'tools/gen_draft_silhouettes.py로 생성한 오리지널 도형 조합. -->\n'
            f'  <g fill="#000">\n{paths}\n  </g>\n</svg>\n')


def inner(x, y, size, p):
    return (f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="0 0 512 512"><g fill="#000">'
            + "".join(f'<path d="{d}"/>' for d in p) + '</g></svg>')


def label_text(x, y, s):
    return (f'<text x="{x}" y="{y}" font-size="40" text-anchor="middle" '
            f'font-family="Apple SD Gothic Neo, sans-serif" fill="#666">{s}</text>')


def write_square(name, content_w, content_h, parts, bg="#fff"):
    """qlmanage 썸네일은 정사각이므로 정사각 캔버스 가운데에 내용을 놓고, 렌더 뒤 sips로 가운데를 잘라낸다.
    잘라낼 크기는 <name>.crop 파일(높이 너비)에 기록."""
    S = max(content_w, content_h)
    ox, oy = (S - content_w) / 2, (S - content_h) / 2
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">',
           f'<rect width="{S}" height="{S}" fill="{bg}"/>', f'<g transform="translate({ox} {oy})">']
    svg += parts + ['</g></svg>']
    with open(os.path.join(SHEET, name + ".svg"), "w") as fp:
        fp.write("\n".join(svg))
    with open(os.path.join(SHEET, name + ".crop"), "w") as fp:
        fp.write(f"{content_h} {content_w}\n")


# ---------------------------------------------------------------- 앞모습 3/4 (정면에서 약 20~30도만 돌림)
# 규칙: 얼굴은 거의 정면(화면 가운데~오른쪽). 몸통은 왼쪽 뒤로 비스듬히 물러나 옆구리가 조금 보인다.
# 앞다리 두 개는 얼굴 아래 좌우로, 뒷다리는 왼쪽 뒤에 작게(지면선 GB).


def elephant_f():  # 양쪽으로 펼친 큰 귀 + 옆으로 들어 올린 코
    return [
        ell(115, 270, 100, 98),                   # 옆구리(왼쪽 뒤)
        ell(170, 190, 92, 112, -12),              # 귀(좌, 펼침)
        ell(392, 190, 86, 108, 12),               # 귀(우, 펼침)
        ell(280, 200, 72, 84),                    # 얼굴(정면)
        ell(250, 300, 78, 42),                    # 가슴(앞다리 윗부분)
        tube([(282, 255), (292, 380), (352, 426), (414, 366)], 54, 28),  # 코(아래로 내려와 옆으로 들어 올림)
        tube([(414, 366), (434, 334), (412, 316), (398, 336)], 28, 18),  # 코끝 말림
        leg(200, 300, G, 62), leg(290, 300, G - 2, 60),   # 앞다리
        leg(80, 320, GB, 50),                     # 뒷다리(옆구리 아래)
    ]


def giraffe_f():  # 정면 머리를 높이 든 수직의 긴 목
    return [
        ell(185, 335, 95, 56, -10),               # 옆구리(왼쪽 뒤)
        tube([(298, 112), (294, 200), (282, 280), (268, 335)], 36, 72),  # 긴 목(수직)
        ell(298, 70, 34, 42),                     # 얼굴(정면, 세로로 긴 타원)
        ell(298, 110, 24, 20),                    # 주둥이
        tube([(284, 36), (278, 10)], 9, 8), circ(278, 10, 9),   # 뿔 2개
        tube([(312, 36), (318, 10)], 9, 8), circ(318, 10, 9),
        tube([(270, 58), (234, 46)], 14, 6), tube([(326, 58), (362, 46)], 14, 6),  # 양쪽 귀
        ell(268, 345, 48, 34),                    # 가슴
        leg(244, 350, G, 24, 18), leg(296, 350, G - 2, 24, 18),
        leg(138, 360, GB, 21, 16), leg(168, 365, GB + 4, 21, 16),
        tube([(96, 325), (86, 380), (88, 420)], 9, 5), ell(90, 428, 9, 15),
    ]


def lion_f():  # 얼굴을 빙 둘러싼 갈기(정면 후광)
    return [
        ell(145, 305, 112, 70, -6),               # 옆구리
        spiky(285, 205, 128, 130, 26, 22, 0),     # 갈기
        ell(285, 285, 52, 40),                    # 주둥이·턱
        ell(286, 322, 72, 40),                    # 가슴
        leg(240, 300, G, 46), leg(330, 300, G - 2, 46),
        leg(80, 330, GB, 38), leg(125, 340, GB + 4, 38),
        tube([(42, 290), (14, 330), (18, 400), (44, 424)], 13, 9),
        ell(50, 430, 16, 20, 30),
    ]


def rabbit_f():  # 곧게 선 긴 귀 2개, 앉은 둥근 몸
    return [
        ell(170, 400, 82, 70),                    # 허벅지(왼쪽 뒤)
        ell(262, 360, 104, 104),                  # 몸통
        ell(272, 232, 74, 62),                    # 얼굴
        ell(236, 102, 27, 96, -8),                # 귀(좌)
        ell(308, 102, 27, 96, 8),                 # 귀(우)
        ell(240, 466, 28, 16), ell(304, 466, 28, 16),  # 앞발 2개
        ell(150, 468, 70, 15),                    # 뒷발
        circ(92, 392, 24),                        # 꼬리(옆으로 살짝)
    ]


def penguin_f():  # 직립, 정면 얼굴, 양쪽 날개
    return [
        ell(256, 300, 116, 178),                  # 몸통
        ell(262, 116, 70, 66),                    # 머리
        poly((270, 128), (312, 146), (270, 160)), # 부리(짧게 앞-오른쪽)
        ell(140, 300, 26, 106, 14),               # 날개(좌)
        ell(374, 300, 26, 106, -14),              # 날개(우)
        ell(218, 476, 42, 13), ell(298, 478, 42, 13),
    ]


def bear_f():  # 큰 둥근 얼굴 + 위쪽 둥근 귀 2개, 뒤로 솟은 둥근 등
    return [
        ell(150, 280, 120, 98),                   # 둥근 등·옆구리(왼쪽 뒤)
        circ(290, 215, 84),                       # 얼굴(정면)
        circ(222, 146, 31), circ(358, 144, 31),   # 둥근 귀 2개
        ell(300, 282, 42, 30),                    # 짧은 주둥이(턱 아래로 살짝)
        ell(286, 320, 92, 52),                    # 가슴
        leg(240, 310, G, 66), leg(340, 310, G - 2, 66),
        leg(80, 330, GB, 56), leg(140, 340, GB + 4, 56),
    ]


def hippo_f():  # 정면 쪽에서 위로 크게 벌린 입(오른쪽으로 벌어진 틈과 이빨)
    return [
        ell(140, 325, 120, 92),                   # 통 옆구리(왼쪽 뒤)
        ell(262, 310, 96, 76),                    # 머리
        tube([(272, 260), (322, 140)], 140, 124), # 위턱(위로 젖힘)
        circ(270, 84, 20), circ(350, 104, 20),    # 콧구멍 돌기 2개
        tube([(240, 376), (378, 390)], 74, 68),   # 아래턱(넓적, 앞으로)
        poly((350, 356), (360, 312), (372, 356)), # 아래 엄니
        poly((392, 360), (400, 322), (410, 362)),
        poly((354, 246), (384, 252), (366, 214)), # 위 이빨(위턱 가장자리에 붙임)
        circ(190, 236, 16), circ(214, 226, 13),   # 작은 귀
        leg(220, 410, G, 62), leg(320, 420, G - 2, 58),
        leg(60, 400, GB, 50), leg(110, 410, GB + 4, 50),
    ]


def monkey_f():  # 정면 얼굴·양쪽 귀, 긴 팔, 옆으로 나온 말린 꼬리
    return [
        ell(258, 292, 64, 96),                    # 몸통
        circ(260, 150, 54),                       # 얼굴
        circ(198, 152, 22), circ(322, 152, 22),   # 양쪽 귀
        ell(262, 184, 32, 22),                    # 주둥이
        tube([(306, 232), (362, 206), (404, 146), (414, 70)], 24, 18),  # 위로 뻗은 팔
        ell(416, 58, 16, 22, 10),
        tube([(212, 232), (186, 312), (176, 392), (182, 462)], 24, 18), # 땅에 닿는 팔
        ell(188, 470, 22, 12),
        tube([(236, 366), (226, 420), (230, 470)], 32, 24),
        tube([(284, 366), (296, 420), (292, 470)], 32, 24),
        ell(226, 476, 24, 10), ell(300, 476, 24, 10),
        tube([(214, 360), (110, 410), (40, 320), (78, 236)], 16, 12),   # 꼬리(옆으로)
        tube([(78, 236), (110, 180), (156, 230), (118, 246)], 12, 9),
    ]


def crocodile_f():  # 입을 쩍 벌린 얼굴이 앞, 몸·꼬리는 뒤로 S자로 물러남
    d = [
        tube([(300, 400), (230, 372), (200, 320), (150, 296)], 96, 66),  # 몸(뒤로 물러남)
        tube([(150, 296), (90, 276), (54, 320), (24, 280)], 66, 8),      # 꼬리(S자)
        ell(318, 408, 62, 44),                    # 머리
        tube([(330, 386), (440, 290)], 70, 36),   # 위턱(위로 벌림, 앞으로 짧아 보임)
        tube([(330, 428), (462, 446)], 52, 30),   # 아래턱
        circ(296, 366, 13), circ(344, 368, 12),   # 눈 돌기 2개
        tube([(364, 440), (386, 474)], 30, 24), ell(392, 476, 24, 8),    # 앞다리(가까운)
        tube([(258, 424), (234, 466)], 30, 24), ell(228, 470, 24, 8),
        tube([(196, 346), (176, 386)], 26, 20), ell(170, 390, 20, 7),    # 뒷다리
    ]
    for x, y in [(360, 334), (390, 308), (418, 284)]:   # 위턱 이빨(아래로)
        d.append(poly((x - 6, y + 10), (x + 10, y + 34), (x + 10, y + 4)))
    for x in (372, 404, 436):                           # 아래턱 이빨(위로)
        d.append(poly((x - 8, 420), (x, 396), (x + 8, 422)))
    for i in range(7):                                  # 등 돌기
        t = i / 6
        x = 270 - 120 * t; y = 352 - 60 * t
        d.append(poly((x - 10, y + 8), (x - 2, y - 14), (x + 8, y + 6)))
    return d


def rhino_f():  # 얼굴 앞에서 윤곽 위로 솟은 큰 뿔, 양쪽 뾰족 귀
    return [
        ell(145, 275, 125, 98),                   # 옆구리(왼쪽 뒤)
        ell(290, 300, 72, 84),                    # 얼굴(정면, 세로로 긴)
        ell(292, 372, 54, 40),                    # 코
        "M270 360Q286 260 300 130Q308 260 320 360Z",   # 큰 뿔(머리 윤곽 위로)
        tube([(246, 236), (226, 210), (204, 186)], 24, 8),  # 귀(좌)
        tube([(334, 236), (354, 210), (376, 186)], 24, 8),  # 귀(우)
        ell(288, 350, 90, 44),                    # 가슴
        leg(246, 340, G, 64), leg(336, 340, G - 2, 62),
        leg(70, 320, GB, 54), leg(125, 330, GB + 4, 54),
        tube([(28, 260), (18, 290), (18, 320)], 10, 6), ell(18, 328, 7, 12),
    ]


def kangaroo_f():  # 정면 직립, 짧은 귀, 옆으로 길게 삐져나온 굵은 꼬리
    return [
        tube([(206, 420), (146, 450), (84, 462), (20, 452)], 62, 16),  # 굵은 꼬리(옆으로)
        ell(262, 380, 92, 76),                    # 허벅지
        ell(270, 276, 70, 116),                   # 상체
        tube([(270, 190), (270, 168)], 52, 48),   # 목
        ell(270, 138, 44, 40),                    # 얼굴
        ell(276, 170, 26, 20),                    # 주둥이
        tube([(248, 112), (226, 62)], 22, 10),    # 귀(짧고 뾰족, 좌)
        tube([(292, 112), (314, 62)], 22, 10),    # 귀(우)
        tube([(236, 234), (222, 272), (230, 296)], 16, 11),  # 앞발 2개(짧게)
        tube([(304, 234), (318, 272), (310, 296)], 16, 11),
        ell(228, 466, 42, 15), ell(312, 466, 42, 15),        # 뒷발 2개
    ]


def camel_f():  # 정면 얼굴, 몸통은 충분히 비스듬해 혹 2개가 옆으로 보임
    return [
        ell(200, 262, 122, 60, -4),               # 몸통(왼쪽 뒤)
        ell(140, 192, 54, 60),                    # 혹 1
        ell(230, 186, 54, 62),                    # 혹 2
        tube([(330, 290), (342, 230), (356, 180), (366, 150)], 56, 34),  # 목
        ell(368, 112, 32, 42),                    # 얼굴(정면)
        ell(370, 150, 26, 20),                    # 주둥이
        circ(342, 84, 11), circ(394, 84, 11),     # 작은 둥근 귀(기린의 가로 귀와 구분)
        ell(330, 296, 40, 32),                    # 가슴
        leg(310, 300, G, 28, 16), leg(354, 300, G - 2, 28, 16),
        leg(110, 295, GB, 25, 15), leg(140, 295, GB + 4, 25, 15),
        tube([(80, 250), (68, 290), (68, 330)], 9, 5), ell(68, 338, 6, 12),
    ]


ANIMALS_F = {
    "elephant": elephant_f, "giraffe": giraffe_f, "lion": lion_f, "rabbit": rabbit_f,
    "penguin": penguin_f, "bear": bear_f, "hippo": hippo_f, "monkey": monkey_f,
    "crocodile": crocodile_f, "rhino": rhino_f, "kangaroo": kangaroo_f, "camel": camel_f,
}
OUTF = os.path.join(ROOT, "assets", "draft_silhouettes", "animals_front34")


# ---------------------------------------------------------------- 앞모습 3/4 톤 시안 (같은 도형 정의에서 채움만 다르게 파생)
# 깊이 레이어: 0=뒤(먼 다리·옆구리·꼬리), 1=중간, 2=앞(얼굴·앞다리 등). 인덱스는 *_f() 반환 목록의 순서.
# 톤은 부위의 앞뒤 깊이만 표현한다. 눈·코·무늬·표정은 넣지 않는다.
DEPTH2 = {  # A안 2톤: 뒤 레이어 인덱스
    "elephant": {0, 9}, "giraffe": {0, 13, 14, 15, 16}, "lion": {0, 6, 7, 8, 9},
    "rabbit": {0, 7, 8}, "penguin": {3}, "bear": {0, 8, 9}, "hippo": {0, 1, 9, 10, 13, 14},
    "monkey": {7, 8, 13, 14}, "crocodile": {1, 9, 10, 11, 12} | set(range(19, 26)),
    "rhino": {0, 9, 10, 11, 12}, "kangaroo": {0}, "camel": {0, 1, 2, 11, 12, 13, 14},
}
DEPTH3 = {  # B안 3톤: (뒤, 중간) 인덱스. 나머지는 앞
    "elephant": ({0, 9}, {1, 2}), "giraffe": ({13, 14, 15, 16}, {0}), "lion": ({6, 7, 8, 9}, {0}),
    "rabbit": ({0, 7, 8}, set()), "penguin": ({3}, set()), "bear": ({0, 8, 9}, {5}),
    "hippo": ({0, 13, 14}, {1, 9, 10}), "monkey": ({13, 14}, {7, 8}),
    "crocodile": ({1, 11, 12}, {0, 9, 10} | set(range(19, 26))),
    "rhino": ({0, 9, 10, 11, 12}, {4, 5, 6}), "kangaroo": ({0}, {1}),
    "camel": ({1, 11, 12, 13, 14}, {0, 2}),
}
TONE2 = {0: "#4D4D4D", 2: "#2B2B2B"}
# B안: 레이어별 세로 그라데이션(위 → 아래로 어두워짐). 외곽은 채움 경계라 그대로 또렷하다.
TONE3 = {0: ("#5E5E5E", "#4A4A4A"), 1: ("#454545", "#363636"), 2: ("#363636", "#222222")}
GROUND = 'fill="#000" fill-opacity="0.13"'


def tone_levels(aid, mode):
    n = len(ANIMALS_F[aid]())
    if mode == "2tone":
        return [0 if i in DEPTH2[aid] else 2 for i in range(n)]
    back, mid = DEPTH3[aid]
    return [0 if i in back else 1 if i in mid else 2 for i in range(n)]


def tone_body(aid, mode, uid):
    """mode: mono | 2tone | shaded. uid는 시트 안에서 그라데이션 id 충돌 방지용."""
    p = ANIMALS_F[aid]()
    if mode == "mono":
        return '<g fill="#000">' + "".join(f'<path d="{d}"/>' for d in p) + '</g>'
    lv = tone_levels(aid, mode)
    out = []
    if mode == "shaded":
        out.append("<defs>" + "".join(
            f'<linearGradient id="{uid}g{k}" gradientUnits="userSpaceOnUse" x1="0" y1="40" x2="0" y2="490">'
            f'<stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
            for k, (a, b) in TONE3.items()) + "</defs>")
        out.append(f'<ellipse cx="250" cy="484" rx="210" ry="18" {GROUND}/>')  # 바닥 그림자
    for k in (0, 1, 2):  # 뒤 → 앞 순서로 칠함
        ds = [d for d, l in zip(p, lv) if l == k]
        if not ds:
            continue
        fill = TONE2[k] if mode == "2tone" else f"url(#{uid}g{k})"
        out.append(f'<g fill="{fill}">' + "".join(f'<path d="{d}"/>' for d in ds) + '</g>')
    return "".join(out)


OUT2T = os.path.join(ROOT, "assets", "draft_silhouettes", "animals_front34_2tone")
OUTSH = os.path.join(ROOT, "assets", "draft_silhouettes", "animals_front34_shaded")


def tone_main(side_lab):
    for d, mode, view in ((OUT2T, "2tone", "앞모습 3/4 2톤(A안)"), (OUTSH, "shaded", "앞모습 3/4 3톤+그림자(B안)")):
        os.makedirs(d, exist_ok=True)
        for aid, ko, _ in ANIMALS:
            body = tone_body(aid, mode, aid)
            with open(os.path.join(d, aid + ".svg"), "w") as fp:
                fp.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">\n'
                         f'  <!-- DRAFT / 검사용 초안: {ko}({aid}) {view}. 최종 그림 아님. animals_front34와 같은 도형 정의에서 '
                         f'채움만 바꿔 파생(tools/gen_draft_silhouettes.py). 톤은 부위 앞뒤 깊이만 표현. -->\n  {body}\n</svg>\n')
    img, gap, lab = 210, 10, 50
    cw, ch = img * 3 + gap * 2 + 24, img + lab + 14
    for name, bg in (("animals_tone_compare", "#fff"), ("animals_tone_compare_warmbg", "#F3EBDD")):
        parts = [f'<rect x="0" y="0" width="{cw*3}" height="{ch*4}" fill="{bg}"/>']
        for i, (aid, ko, _) in enumerate(ANIMALS):
            x, y = (i % 3) * cw, (i // 3) * ch
            parts.append(f'<rect x="{x+6}" y="{y+4}" width="{cw-12}" height="{img+8}" fill="none" stroke="#ccc" stroke-width="2"/>')
            for k, mode in enumerate(("mono", "2tone", "shaded")):
                parts.append(f'<svg x="{x+12+k*(img+gap)}" y="{y+8}" width="{img}" height="{img}" viewBox="0 0 512 512">'
                             + tone_body(aid, mode, f"{name[-6:]}{aid}") + '</svg>')
            parts.append(f'<text x="{x+cw/2}" y="{y+img+44}" font-size="30" text-anchor="middle" '
                         f'font-family="Apple SD Gothic Neo, sans-serif" fill="#666">{i+1}. {ko} — 단색 | 2톤 | 3톤+그림자</text>')
        write_square(name, cw * 3, ch * 4, parts, bg)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(OUT34, exist_ok=True)
    os.makedirs(SHEET, exist_ok=True)
    side, q34 = {}, {}
    for aid, ko, fn in ANIMALS:
        side[aid] = fn()
        q34[aid] = ANIMALS_34[aid]()
        with open(os.path.join(OUT, aid + ".svg"), "w") as fp:
            fp.write(svg_file(ko, aid, side[aid], "측면"))
        with open(os.path.join(OUT34, aid + ".svg"), "w") as fp:
            fp.write(svg_file(ko, aid, q34[aid], "3/4 앞모습"))

    # (기존) 측면 4x3 시트 — 1차 검사 결과 보존용, 형식 그대로
    cell, lab = 512, 170
    W = cell * 4
    for label in (True, False):
        parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">',
                 f'<rect width="{W}" height="{W}" fill="#fff"/>']
        for i, (aid, ko, _) in enumerate(ANIMALS):
            x = (i % 4) * cell
            y = (i // 4) * (cell + lab) + (10 if label else lab // 2)
            parts.append(f'<rect x="{x+4}" y="{y+4}" width="{cell-8}" height="{cell-8}" fill="none" stroke="#ddd" stroke-width="2"/>')
            parts.append(inner(x + 16, y + 16, cell - 32, side[aid]))
            if label:
                parts.append(f'<text x="{x+cell/2}" y="{y+cell+50}" font-size="44" text-anchor="middle" '
                             f'font-family="Apple SD Gothic Neo, sans-serif" fill="#666">{i+1}. {ko} ({aid})</text>')
        parts.append('</svg>')
        name = "animals_sheet" + ("" if label else "_nolabel") + ".svg"
        with open(os.path.join(SHEET, name), "w") as fp:
            fp.write("\n".join(parts))

    # 3/4 전용 4x3 시트 (캔버스 비율을 그리드에 맞춤)
    for label in (True, False):
        lab = 64 if label else 0
        parts = []
        for i, (aid, ko, _) in enumerate(ANIMALS):
            x, y = (i % 4) * cell, (i // 4) * (cell + lab)
            parts.append(f'<rect x="{x+4}" y="{y+4}" width="{cell-8}" height="{cell-8}" fill="none" stroke="#ddd" stroke-width="2"/>')
            parts.append(inner(x + 16, y + 16, cell - 32, q34[aid]))
            if label:
                parts.append(label_text(x + cell / 2, y + cell + 42, f"{i+1}. {ko} ({aid}) 3/4"))
        write_square("animals_34_sheet" + ("" if label else "_nolabel"), cell * 4, (cell + lab) * 3, parts)

    # 측면 | 3/4 나란히: 3열 x 4행, 셀 = 이미지 2장
    img, gap, lab = 330, 14, 56
    cw, ch = img * 2 + gap + 24, img + lab + 16
    parts = []
    for i, (aid, ko, _) in enumerate(ANIMALS):
        x, y = (i % 3) * cw, (i // 3) * ch
        parts.append(f'<rect x="{x+6}" y="{y+4}" width="{cw-12}" height="{img+8}" fill="none" stroke="#ddd" stroke-width="2"/>')
        parts.append(inner(x + 12, y + 8, img, side[aid]))
        parts.append(f'<line x1="{x+12+img+gap/2}" y1="{y+20}" x2="{x+12+img+gap/2}" y2="{y+img-4}" stroke="#ccc" stroke-width="2" stroke-dasharray="6 6"/>')
        parts.append(inner(x + 12 + img + gap, y + 8, img, q34[aid]))
        parts.append(label_text(x + cw / 2, y + img + 50, f"{i+1}. {ko} — 측면 | 3/4"))
    write_square("animals_side_vs_34", cw * 3, ch * 4, parts)

    # 앞모습 3/4
    os.makedirs(OUTF, exist_ok=True)
    fr = {}
    for aid, ko, _ in ANIMALS:
        fr[aid] = ANIMALS_F[aid]()
        with open(os.path.join(OUTF, aid + ".svg"), "w") as fp:
            fp.write(svg_file(ko, aid, fr[aid], "앞모습 3/4(정면에서 20~30도)"))
    parts = []
    for i, (aid, ko, _) in enumerate(ANIMALS):
        x, y = (i % 4) * cell, (i // 4) * cell
        parts.append(f'<rect x="{x+4}" y="{y+4}" width="{cell-8}" height="{cell-8}" fill="none" stroke="#ddd" stroke-width="2"/>')
        parts.append(inner(x + 16, y + 16, cell - 32, fr[aid]))
    write_square("animals_front34_sheet_nolabel", cell * 4, cell * 3, parts)

    # 측면 | 기존 3/4 | 앞모습 3/4 — 3열 x 4행
    img, gap, lab = 210, 10, 50
    cw, ch = img * 3 + gap * 2 + 24, img + lab + 14
    parts = []
    for i, (aid, ko, _) in enumerate(ANIMALS):
        x, y = (i % 3) * cw, (i // 3) * ch
        parts.append(f'<rect x="{x+6}" y="{y+4}" width="{cw-12}" height="{img+8}" fill="none" stroke="#ddd" stroke-width="2"/>')
        for k, src in enumerate((side, q34, fr)):
            parts.append(inner(x + 12 + k * (img + gap), y + 8, img, src[aid]))
        parts.append(f'<text x="{x+cw/2}" y="{y+img+44}" font-size="30" text-anchor="middle" '
                     f'font-family="Apple SD Gothic Neo, sans-serif" fill="#666">{i+1}. {ko} — 측면 | 3/4 | 앞모습3/4</text>')
    write_square("animals_3views", cw * 3, ch * 4, parts)

    # 톤 시안(A안 2톤 / B안 3톤+그림자)
    tone_main(None)


if __name__ == "__main__":
    main()
