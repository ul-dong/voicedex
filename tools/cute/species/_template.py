"""말하는 도감 cute 일러스트 - <id> (템플릿).

사용법
  1. 이 파일을 species/<id>.py 로 복사한다(파일 이름 = ANIMAL["id"]). '_'로 시작하는 파일은 빌드에서 제외된다.
  2. docs/STYLE_GUIDE.md 의 수치·자세 배정표·혼동 쌍 조건을 따라 path 를 손으로 그린다.
     오리지널만. 외부 이미지·기존 캐릭터·특정 작품을 보거나 흉내내지 않는다.
  3. 빌드 + 확대 검사(다른 종 파일은 건드리지 않음):
       python3 tools/cute/build.py --only <id> --zoom <스크래치 폴더>
     → <스크래치 폴더>/zoom_<id>.png (왼쪽 컬러 | 오른쪽 그림자) 를 직접 보고 체크리스트 확인.
  4. common.py, build.py, sheet.py, 다른 종 파일은 수정하지 않는다.

좌표: viewBox 0 0 400 400, 왼쪽을 본다, 발바닥(바닥선) y ≈ 360.
path 는 절대좌표 M/C/L/Z 만 쓴다(필렛 계산기가 이 형식만 읽는다). 소문자 상대명령·A(호)·Q 금지.
"""
from common import blob, eye, cheek  # noqa: F401

BASE = "#C8B49A"   # 본체 파스텔 자연색 (STYLE_GUIDE 팔레트 규칙)

_body = "M150 200C190 180 290 180 320 220C340 250 336 300 300 320C260 336 190 336 160 316C130 296 126 236 150 200Z"
_head = "M120 90C150 60 230 60 250 100C266 132 256 180 220 196C190 208 140 204 116 180C96 156 96 114 120 90Z"

ANIMAL = dict(
    id="template", no=99,              # id = 파일 이름, no = 도감 번호(docs/MASTER_PROMPT.md)
    name="템플릿", base=BASE,
    ground=(230, 360, 140, 8),         # 바닥 그림자 타원 (cx, cy, rx, ry): cy = 발바닥 y
    r=11,                              # 기본 필렛 반지름 10~13
    r_pairs={},                        # {(i, j): r} shapes 인덱스 쌍별 반지름. 의도한 틈(겨드랑이 등)은 3~5, 0이면 필렛 없음
    shapes=[                           # 뒤 → 앞 순서. 같은 본체색으로 합집합 처리됨
        _body,
        _head,
    ],
    accents=[],                        # [(path, color)] 본체색이 아닌 실루엣 부위(뿔·이빨·부리·발 등)
    creases=[],                        # [열린 path] 몸 위에 겹친 앞 부위의 경계 주름선(끝이 열린 선 하나)
    details=[                          # 컬러 전용(그림자에 안 나옴)
        *eye(160, 130), *eye(206, 132),
        *cheek(200, 166),
    ],
)
