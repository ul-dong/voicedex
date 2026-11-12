#!/bin/zsh
# voicedex(말하는 도감) - 무료 음성 모델(MeloTTS, MIT)로 녹음 목소리 만들기.
# 알록달록 꼬마 놀이터의 tool/gen_voice.command 를 voicedex 경로로 옮긴 것(같은 목소리·같은 설정).
#
# 1) assets/data/voice_lines_ko.json 의 모든 대사(+ 종별 대사를 모든 종으로 펼친 통문장)를
#    tools/voice/lines.json 으로 내보내고 (tools/voice/export_lines_test.dart)
# 2) assets/voice 에 녹음(mp3)이 없는 문장만 새로 만들어 넣은 뒤
# 3) assets/voice/manifest.json 을 갱신한다 (기존 녹음·번호는 건드리지 않는다).
# 새 녹음은 모두 tools/voice/child_voice.py 의 처리(어린이 느낌 음색 + 서울 말투 억양 + 따뜻한 EQ + -16 LUFS)를
# 거친다 (기존 녹음과 같은 목소리). 목소리 설정을 바꿨다면 --all 로 전부 다시 녹음해야 섞이지 않는다.
#
# 사용: tools/voice/gen_voice.command          # 새 문장만 (증분)
#       tools/voice/gen_voice.command --all    # 전부 다시
#       VOICEDEX_NONINTERACTIVE=1 tools/voice/gen_voice.command   # 끝에 Enter 를 기다리지 않음
# 필요: ffmpeg, Flutter(~/alokdev/flutter), 음성 모델 venv(~/alokdev/melo-venv — 알록달록과 같이 쓴다.
#       없으면 Homebrew python@3.10 으로 새로 만든다).
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
ROOT="$HOME/alokdev"
OUT="$REPO/assets/voice"
mkdir -p "$REPO/build"
LOG="$REPO/build/voice_log.txt"
exec > >(tee "$LOG") 2>&1
# 작업하는 동안만 맥이 잠자기로 넘어가지 않게 한다 (끝나면 kill 로 푼다)
caffeinate -dimsu -w $$ & CAF=$!
finish() { kill $CAF 2>/dev/null || true; [ "${VOICEDEX_NONINTERACTIVE:-0}" = "1" ] || read -r "?창을 닫으려면 Enter를 누르세요"; }
fail() { echo ""; echo "오류: $1"; finish; exit 1; }
step() { echo ""; echo "==== $1 ===="; }
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$ROOT/flutter/bin:$PATH"
command -v flutter > /dev/null || fail "Flutter가 없어요 ($ROOT/flutter)"

step "1/4 문장 목록 내보내기"
cd "$REPO"
flutter pub get > /dev/null || fail "pub get 실패"
flutter test tools/voice/export_lines_test.dart || fail "문장 목록 내보내기 실패"

step "2/4 ffmpeg"
if ! command -v ffmpeg > /dev/null; then
  command -v brew > /dev/null || fail "ffmpeg 가 없어요 (Homebrew로 설치: brew install ffmpeg)"
  brew install ffmpeg || fail "ffmpeg 설치 실패"
fi

step "3/4 음성 모델 (없으면 설치, 처음엔 10분 정도)"
VENV="$ROOT/melo-venv"
if [ ! -x "$VENV/bin/python" ]; then
  command -v brew > /dev/null || fail "Homebrew가 없어요 (https://brew.sh 에서 먼저 설치)"
  brew list python@3.10 > /dev/null 2>&1 || brew install python@3.10 || fail "python 설치 실패"
  "$(brew --prefix python@3.10)/bin/python3.10" -m venv "$VENV" || fail "venv 실패"
fi
source "$VENV/bin/activate"
export TOKENIZERS_PARALLELISM=false
if ! pip show melotts > /dev/null 2>&1; then
  pip install -U pip wheel "setuptools<70" || fail "pip 업데이트 실패"
  pip install "numpy==1.26.4" "git+https://github.com/myshell-ai/MeloTTS.git" "python-mecab-ko" || fail "MeloTTS 설치 실패"
  python -m unidic download || fail "사전 받기 실패"
fi
python -c "import setuptools, numpy; assert numpy.__version__ == '1.26.4'" 2>/dev/null \
  || pip install -q "setuptools<70" "numpy==1.26.4" || fail "setuptools/numpy 고정 실패"
# 어린이 느낌 목소리 처리(child_voice.py)에 쓰는 Praat
python -c "import parselmouth" 2>/dev/null || pip install -q "praat-parselmouth==0.4.7" "numpy==1.26.4" || fail "parselmouth 설치 실패"
python -c "import nltk; [nltk.download(p, quiet=True) for p in ['averaged_perceptron_tagger','averaged_perceptron_tagger_eng','cmudict']]" > /dev/null 2>&1 || true
# 맥은 대소문자를 구분하지 않아 일본어용 MeCab 과 한국어용 mecab 폴더가 겹친다.
# 한국어용만 남기고, 일본어용은 gen_voice.py 안에서 가짜로 채운다.
if ! python -c "import mecab; mecab.MeCab().pos('안녕')" 2>/dev/null; then
  pip uninstall -y mecab-python3 python-mecab-ko
  pip install --force-reinstall --no-deps python-mecab-ko || fail "mecab-ko 설치 실패"
fi
python -c "import mecab; mecab.MeCab().pos('안녕하세요')" > /dev/null || fail "mecab 확인 실패"

step "4/4 없는 문장만 녹음 → assets/voice"
python "$HERE/gen_voice.py" "$HERE/lines.json" "$OUT" 0.82 "$@" || fail "음성 만들기 실패 (위 메시지 참고)"
python "$HERE/check_voice.py" "$OUT" || fail "녹음 확인 실패 (위 메시지 참고)"

echo ""
echo "완료: 녹음 파일 $(ls "$OUT" | grep -c mp3)개, $(du -sh "$OUT" | cut -f1)."
echo "확인: flutter test (녹음 팩 테스트가 빠진 문장을 알려 줘요)"
finish
