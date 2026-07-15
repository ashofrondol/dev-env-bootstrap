#!/usr/bin/env bash
set -euo pipefail
LANG_TYPE="${1:-python}"

if [[ "$LANG_TYPE" == "python" ]]; then
  echo "==> pytest 실행 (TestCase.txt 포함)"
  uv run pytest -v || true

  # 스모크 테스트 자동 감지
  if [[ -f smoke_test.py ]]; then
    echo "==> 스모크 테스트 감지됨 -> 실행"
    uv run python smoke_test.py
  fi
elif [[ "$LANG_TYPE" == "web" ]]; then
  echo "==> Vitest 실행"
  npx vitest run || true
fi
