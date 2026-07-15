#!/usr/bin/env bash
set -euo pipefail
LANG_TYPE="${1:-python}"
PROJECT_NAME="${2:-my-project}"
DEFAULT_PY="${3:-3.13}"

# 스크립트 위치 기준으로 templates 디렉터리를 계산 (어디서 호출해도 동작)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TPL="$ROOT_DIR/templates"

echo "==> 프로젝트 생성: $PROJECT_NAME ($LANG_TYPE)"
mkdir -p "$PROJECT_NAME/.vscode"
cp "$TPL/vscode/settings.json"   "$PROJECT_NAME/.vscode/"
cp "$TPL/vscode/extensions.json" "$PROJECT_NAME/.vscode/"

if [[ "$LANG_TYPE" == "python" ]]; then
  # 파이썬 버전 인터랙티브 입력 (미입력 시 기본값)
  read -rp "사용할 파이썬 버전 [$DEFAULT_PY]: " PY_VER
  PY_VER="${PY_VER:-$DEFAULT_PY}"
  echo "    -> 파이썬 $PY_VER 사용"

  cd "$PROJECT_NAME"
  uv init --python "$PY_VER"
  uv python pin "$PY_VER"          # .python-version 고정
  uv add --dev pytest              # 테스트 프레임워크 설치
  mkdir -p tests
  cp "$TPL/python/smoke_test.py" . 2>/dev/null || true
  cp "$TPL/python/tests/test_from_testcases.py" tests/ 2>/dev/null || true
  touch TestCase.txt               # 빈 테스트케이스 파일 생성
  cp "$TPL/python/.pre-commit-config.yaml" . 2>/dev/null || true

elif [[ "$LANG_TYPE" == "web" ]]; then
  cd "$PROJECT_NAME"
  cp "$TPL/web/package.json" .
  cp "$TPL/web/index.html" .
  if command -v npm &>/dev/null; then
    npm install -D vitest prettier eslint
  fi
  touch TestCase.txt
fi
echo "==> 완료: cd $PROJECT_NAME && code ."
