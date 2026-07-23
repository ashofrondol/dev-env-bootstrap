#!/usr/bin/env bash
# ============================================================
# 블랙박스 그레이더 자동 발견 & 실행.
#
# dev-env-bootstrap 의 '루트 바로 위 상위 디렉터리'(= 이 저장소의 부모)에서
# GRADER_DIRNAME 폴더(기본: blackbox-tests)를 찾아, 그 안의 grade.sh 로
# 대상 구현을 채점한다. Makefile 의 grade / grade-detect 타겟이 호출한다.
#
# 사용:
#   run_graders.sh --detect <그레이더경로>
#   run_graders.sh <그레이더경로> <대상경로> [과제ID] [모듈명]
# ============================================================
set -euo pipefail

# ---------- --detect: 존재 여부만 확인 ----------
if [[ "${1:-}" == "--detect" ]]; then
  GP="${2:-}"
  if [[ -n "$GP" && -d "$GP" && -f "$GP/grade.sh" ]]; then
    echo "[OK] 블랙박스 그레이더 발견: $GP"
    if [[ -d "$GP/assignments" ]]; then
      echo "     과제: $(ls "$GP/assignments" 2>/dev/null | tr '\n' ' ')"
    fi
    echo "     실행: make grade TARGET=<대상경로> [ASSIGNMENT=<과제ID>] [MODULE=<모듈명>]"
    exit 0
  fi
  echo "[--] 그레이더를 찾지 못했습니다: ${GP:-<미지정>}"
  echo "     이 저장소의 상위 폴더에 그레이더(grade.sh 포함)를 두거나,"
  echo "     make grade-detect GRADER_DIRNAME=<폴더명> 으로 이름을 지정하세요."
  exit 1
fi

# ---------- 실제 채점 ----------
GP="${1:-}"
TARGET="${2:-}"
ASSIGNMENT="${3:-}"
MODULE="${4:-}"

if [[ -z "$GP" || ! -f "$GP/grade.sh" ]]; then
  echo "[!] 그레이더를 찾지 못했습니다: ${GP:-<미지정>}" >&2
  echo "    상위 폴더에 그레이더를 두거나 GRADER_DIRNAME 을 조정하세요." >&2
  echo "    (먼저 'make grade-detect' 로 발견 여부를 확인해 보세요.)" >&2
  exit 1
fi
if [[ -z "$TARGET" ]]; then
  echo "[!] 채점할 대상 경로가 필요합니다:" >&2
  echo "    make grade TARGET=<대상경로> [ASSIGNMENT=<과제ID>] [MODULE=<모듈명>]" >&2
  exit 2
fi

echo "==> 그레이더: $GP"
# 과제ID/모듈명은 비어 있으면 grade.sh 의 기본값/자동탐지에 맡긴다.
exec bash "$GP/grade.sh" "$TARGET" "${ASSIGNMENT:-b2_1_budget_app}" "$MODULE"
