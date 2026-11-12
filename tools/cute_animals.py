#!/usr/bin/env python3
"""(이전 위치) cute 일러스트 생성기는 tools/cute/ 패키지로 옮겨졌다.
  종 정의: tools/cute/species/<id>.py   빌드: tools/cute/build.py   시트: tools/cute/sheet.py
이 파일은 호환용으로 남겨 두며, 실행하면 새 빌드+시트를 그대로 부른다.
"""
import os
import subprocess
import sys

here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cute")
subprocess.run([sys.executable, os.path.join(here, "build.py")] + sys.argv[1:], check=True)
subprocess.run([sys.executable, os.path.join(here, "sheet.py")], check=True)
