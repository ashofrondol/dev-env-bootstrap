#!/usr/bin/env bash
set -euo pipefail
LANG_TYPE="${1:-python}"
PROJECT_NAME="${2:-}"

if [[ "$LANG_TYPE" != "python" ]]; then
  echo "[!] 실행 보고서는 현재 python 프로젝트만 지원합니다."
  exit 1
fi

# ---------- 실행 위치 결정 (run_tests.sh와 동일 규칙) ----------
if [[ ! -f pyproject.toml ]]; then
  if [[ -n "$PROJECT_NAME" && -d "$PROJECT_NAME" ]]; then
    echo "==> 프로젝트 디렉터리로 이동: $PROJECT_NAME"
    cd "$PROJECT_NAME"
  else
    echo "[!] 여기는 python 프로젝트 디렉터리가 아닙니다."
    echo "    make report PROJECT_NAME=<프로젝트명> 으로 실행하거나,"
    echo "    생성된 프로젝트 디렉터리 안에서 실행하세요."
    exit 1
  fi
fi

if [[ ! -f perf.py ]]; then
  echo "[!] perf.py 가 없습니다. (구버전 프로젝트라면 템플릿에서 복사하세요:"
  echo "    cp <bootstrap>/templates/python/perf.py .)"
  exit 1
fi

echo "==> 실행 보고서 생성 (perf.py)"
uv run python perf.py
