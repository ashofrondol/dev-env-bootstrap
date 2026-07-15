#!/usr/bin/env bash
set -euo pipefail
DEFAULT_PY="${1:-3.13}"

# 스크립트 위치 기준으로 프로젝트 루트를 계산 (어디서 호출해도 동작)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1) uv 설치"
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

echo "==> 2) 기본 파이썬 설치"
uv python install "$DEFAULT_PY"

echo "==> 3) 전역 CLI 도구 설치 (Ruff, pre-commit)"
# Astral 공식 권장 설치법 (@latest로 최신 고정)
uv tool install ruff@latest
uv tool install pre-commit

echo "==> 4) VS Code 익스텐션 설치"
if command -v code &>/dev/null; then
  while read -r ext; do
    [[ -z "$ext" || "$ext" == \#* ]] && continue
    code --install-extension "$ext" --force
  done < "$SCRIPT_DIR/extensions.txt"
else
  echo "[!] 'code' CLI를 찾을 수 없습니다. VS Code에서 명령팔레트 >"
  echo "    'Shell Command: Install code command in PATH' 실행 후 재시도하세요."
fi
echo "==> 전역 설치 완료"
