#!/usr/bin/env bash
set -euo pipefail
# 비-UTF8 콘솔(예: Windows cp949)에서 유니코드 출력이 죽지 않도록 인코딩 고정.
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

LANG_TYPE="${1:-python}"
PROJECT_NAME="${2:-}"
TARGET="${3:-}"          # 임의 경로(외부/절대경로 포함)

if [[ "$LANG_TYPE" != "python" ]]; then
  echo "[!] 실행 보고서는 현재 python 프로젝트만 지원합니다."
  exit 1
fi

# ---------- 실행 위치 결정 ----------
# 우선순위: TARGET(임의 경로) > 현재 디렉터리가 프로젝트 > PROJECT_NAME(하위 디렉터리)
if [[ -n "$TARGET" ]]; then
  if [[ -d "$TARGET" ]]; then
    echo "==> 대상 디렉터리로 이동: $TARGET"
    cd "$TARGET"
  else
    echo "[!] TARGET 경로가 존재하지 않습니다: $TARGET"
    exit 1
  fi
elif [[ ! -f pyproject.toml ]]; then
  if [[ -n "$PROJECT_NAME" && -d "$PROJECT_NAME" ]]; then
    echo "==> 프로젝트 디렉터리로 이동: $PROJECT_NAME"
    cd "$PROJECT_NAME"
  else
    echo "[!] 여기는 python 프로젝트 디렉터리가 아닙니다."
    echo "    make report PROJECT_NAME=<이름> 또는 make report TARGET=<경로> 로 실행하거나,"
    echo "    프로젝트 디렉터리 안에서 실행하세요."
    exit 1
  fi
fi

if [[ ! -f perf.py ]]; then
  echo "[!] perf.py 가 없어 실행 보고서를 만들 수 없습니다."
  echo "    'make report'는 프로젝트에 내장된 perf.py 계측 하네스(+ uv 환경)를 사용하므로"
  echo "    bootstrap으로 만든 프로젝트에서만 동작합니다."
  echo "    - 외부(비-bootstrap) 프로젝트의 정적 품질은 'make metrics TARGET=<경로>' 를 쓰세요(파일 불필요)."
  echo "    - 런타임 프로파일이 꼭 필요하면 대상에 perf.py를 복사하고 psutil을 추가하세요:"
  echo "        cp <bootstrap>/templates/python/perf.py . && uv add --dev psutil"
  exit 1
fi

echo "==> 실행 보고서 생성 (perf.py)"
uv run python perf.py
