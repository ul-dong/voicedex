#!/usr/bin/env bash
# 웹(내부 테스트용) 빌드를 GitHub Pages(gh-pages 브랜치)로 배포한다.
#
#   tools/deploy_web.sh            # 빌드 + 배포
#   tools/deploy_web.sh --no-build # build/web 그대로 배포
#
# - GitHub Actions를 쓰지 않는다. 로컬 build/web 내용을 gh-pages 고아 브랜치에 커밋해 푸시한다.
# - 작업 트리를 건드리지 않도록 임시 git worktree에서 작업한다.
# - FLUTTER 환경 변수로 flutter 실행 파일을 바꿀 수 있다(기본: PATH의 flutter).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-flutter}"
BRANCH=gh-pages
REMOTE="${REMOTE:-origin}"
BASE_HREF=/voicedex/

if [[ "${1:-}" != "--no-build" ]]; then
  "$FLUTTER" build web --release --base-href "$BASE_HREF"
fi
[[ -f build/web/index.html ]] || { echo "build/web 이 없다" >&2; exit 1; }

SRC_REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
WT="$(mktemp -d "${TMPDIR:-/tmp}/voicedex-gh-pages.XXXXXX")"
cleanup() {
  git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
  git worktree prune
}
trap cleanup EXIT

git fetch "$REMOTE" "$BRANCH" 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
  git worktree add --force -B "$BRANCH" "$WT" "$REMOTE/$BRANCH"
elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add --force "$WT" "$BRANCH"
else
  # 처음: 고아 브랜치
  git worktree add --detach "$WT"
  git -C "$WT" checkout --orphan "$BRANCH"
fi

# 이전 내용을 지우고 새 빌드로 교체(.git 파일은 유지)
find "$WT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R build/web/. "$WT/"
touch "$WT/.nojekyll"

git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then
  echo "변경 없음 — 배포할 것이 없다."
  exit 0
fi
git -C "$WT" commit -q -m "Deploy web build from $SRC_REV

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C "$WT" push "$REMOTE" "$BRANCH"
echo "배포 완료: https://ul-dong.github.io/voicedex/ (Pages 반영까지 1~2분)"
