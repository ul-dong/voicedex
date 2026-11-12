#!/bin/sh
# cute 일러스트 전체 빌드 + 검사 시트 렌더 (tools/cute/ 패키지 사용)
#   종 하나만 + 확대 검사: python3 tools/cute/build.py --only <id> --zoom <폴더>
set -e
cd "$(dirname "$0")/.."
python3 tools/cute/build.py
python3 tools/cute/sheet.py
