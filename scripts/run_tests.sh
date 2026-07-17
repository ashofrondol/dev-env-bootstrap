#!/usr/bin/env bash
set -euo pipefail
LANG_TYPE="${1:-python}"
PROJECT_NAME="${2:-}"

# ---------- 실행 위치 결정 ----------
# 저장소 루트에서 make test를 부르면 프로젝트 파일이 없으므로
# PROJECT_NAME 디렉터리로 이동한다. 프로젝트 안에서 직접 부르면 그대로 실행.
_is_project_here() {
  if [[ "$LANG_TYPE" == "python" ]]; then
    [[ -f pyproject.toml ]]
  else
    [[ -f package.json ]]
  fi
}

if ! _is_project_here; then
  if [[ -n "$PROJECT_NAME" && -d "$PROJECT_NAME" ]]; then
    echo "==> 프로젝트 디렉터리로 이동: $PROJECT_NAME"
    cd "$PROJECT_NAME"
  else
    echo "[!] 여기는 $LANG_TYPE 프로젝트 디렉터리가 아닙니다."
    echo "    make test PROJECT_NAME=<프로젝트명> 으로 실행하거나,"
    echo "    생성된 프로젝트 디렉터리 안에서 실행하세요."
    exit 1
  fi
fi

# ---------- 테스트 실행 ----------
# pytest가 실패해도 스모크 테스트까지 실행하되, 실패는 종료코드로 전파한다
status=0

if [[ "$LANG_TYPE" == "python" ]]; then
  echo "==> pytest 실행 (TestCase.txt 포함)"
  uv run pytest -v || status=$?

  # 스모크 테스트 자동 감지
  if [[ -f smoke_test.py ]]; then
    echo "==> 스모크 테스트 감지됨 -> 실행"
    uv run python smoke_test.py || status=$?
  fi
elif [[ "$LANG_TYPE" == "web" ]]; then
  echo "==> Vitest 실행"
  npx vitest run || status=$?
fi

if [[ "$status" -ne 0 ]]; then
  echo "[!] 테스트 실패 (exit=$status)"
fi
exit "$status"
