#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# run_analysis.sh - OOP 구조 분석 (시각화 / 지표 / 아키텍처)
# 사용: bash scripts/run_analysis.sh <diagram|metrics|arch> <lang> <project_name>
# 도구는 모두 uvx로 즉석 실행 → 전역 설치 불필요, 버전 드리프트 없음.
# ============================================================
MODE="${1:-metrics}"
LANG_TYPE="${2:-python}"
PROJECT_NAME="${3:-}"

if [[ "$LANG_TYPE" != "python" ]]; then
  echo "[!] OOP 분석(다이어그램/지표/아키텍처)은 현재 python 프로젝트만 지원합니다."
  exit 1
fi

# ---------- 실행 위치 결정 (run_report.sh와 동일 규칙) ----------
# 저장소 루트에서 부르면 PROJECT_NAME 디렉터리로 이동, 프로젝트 안에서 부르면 그대로.
if [[ ! -f pyproject.toml ]]; then
  if [[ -n "$PROJECT_NAME" && -d "$PROJECT_NAME" ]]; then
    echo "==> 프로젝트 디렉터리로 이동: $PROJECT_NAME"
    cd "$PROJECT_NAME"
  else
    echo "[!] 여기는 python 프로젝트 디렉터리가 아닙니다."
    echo "    make $MODE PROJECT_NAME=<프로젝트명> 으로 실행하거나,"
    echo "    생성된 프로젝트 디렉터리 안에서 실행하세요."
    exit 1
  fi
fi

# 분석 대상 소스. 기본은 현재 디렉터리 전체(.).
# 패키지/모듈이 하위 폴더에 있으면 SRC=경로 로 좁힐 수 있다: make metrics SRC=src
SRC="${SRC:-.}"
PKG="$(basename "$(pwd)")"

run_diagram() {
  echo "==> UML 클래스/패키지 다이어그램 생성 (pyreverse, Mermaid — Graphviz 불필요)"
  mkdir -p docs
  # pyreverse는 astroid 기반 정적 분석이라 코드를 실행하지 않는다(안전).
  # 가상환경/테스트/산출물 폴더는 제외. pylint은 절대 실행하지 않는다(pyreverse만).
  uvx --from pylint pyreverse -o mmd -p "$PKG" \
      --ignore=.venv,tests,docs,reports "$SRC" -d docs/
  echo "    생성된 파일:"
  ls -1 docs/*.mmd 2>/dev/null | sed 's/^/      /' \
    || echo "      (클래스가 없어 다이어그램이 비어 있을 수 있습니다)"
  echo "    -> VS Code(내장 Mermaid 미리보기) 또는 Claude Code에서 .mmd 파일을 여세요."
}

run_metrics() {
  echo "==> [1/2] 인지 복잡도 (complexipy, Rust) — 보고 전용(게이트는 pre-commit 훅이 담당)"
  # --ignore-complexity: 임계 초과여도 실패시키지 않고 표만 출력. .venv는 .gitignore로 자동 제외.
  uvx complexipy "$SRC" --ignore-complexity
  echo ""
  echo "==> [2/2] 순환 복잡도(A~F 등급) + 유지보수지수(MI) (radon)"
  uvx radon cc -s -a -i ".venv" "$SRC"
  uvx radon mi -i ".venv" "$SRC"
}

run_arch() {
  if [[ ! -f tach.toml ]]; then
    echo "[!] tach.toml 이 없습니다. 아키텍처 계약을 먼저 1회 정의하세요:"
    echo "    1) uvx tach init   # 현재 모듈 구조를 스캔해 tach.toml 생성"
    echo "    2) tach.toml 에서 계층/의존 규칙 정의"
    echo "       (예: models 는 services 를 import 금지, cli->services->repository->models 방향)"
    echo "    3) make arch       # 규칙 위반 검사 (위반 시 exit≠0 → CI 게이트 가능)"
    exit 1
  fi
  echo "==> 아키텍처 규칙 검사 (tach check)"
  uvx tach check
}

case "$MODE" in
  diagram) run_diagram ;;
  metrics) run_metrics ;;
  arch)    run_arch ;;
  *) echo "[!] 알 수 없는 모드: $MODE (diagram | metrics | arch)"; exit 1 ;;
esac
