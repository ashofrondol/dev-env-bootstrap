#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# run_analysis.sh - OOP 구조 분석 (시각화 / 지표 / 아키텍처)
# 사용: bash scripts/run_analysis.sh <diagram|metrics|arch> <lang> <project_name>
# 도구는 모두 uvx로 즉석 실행 → 전역 설치 불필요, 버전 드리프트 없음.
# ============================================================
# 분석 도구(complexipy 등)는 결과에 유니코드(✅/트리문자)를 출력한다. 비-UTF8 콘솔
# (예: Windows cp949)에서 UnicodeEncodeError로 죽지 않도록 파이썬 출력 인코딩을 고정.
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

MODE="${1:-metrics}"
LANG_TYPE="${2:-python}"
PROJECT_NAME="${3:-}"
TARGET="${4:-}"          # 임의 경로(외부/절대경로 포함). bootstrap 밖 프로젝트 분석용.
SRC="${5:-}"             # 분석 대상 하위 경로 (예: src). 미지정 시 프로젝트 전체(.).
[[ -z "$SRC" ]] && SRC="."

if [[ "$LANG_TYPE" != "python" ]]; then
  echo "[!] OOP 분석(다이어그램/지표/아키텍처)은 현재 python 프로젝트만 지원합니다."
  exit 1
fi

# ---------- 분석 위치 결정 ----------
# 우선순위: TARGET(임의 경로) > 현재 디렉터리가 프로젝트 > PROJECT_NAME(하위 디렉터리)
# 분석 도구(pyreverse/radon/complexipy/tach)는 uvx로 독립 실행되므로 대상이
# bootstrap/uv 프로젝트가 아니어도(pyproject.toml 이 없어도) 그대로 동작한다.
if [[ -n "$TARGET" ]]; then
  if [[ -d "$TARGET" ]]; then
    echo "==> 분석 대상(TARGET)으로 이동: $TARGET"
    cd "$TARGET"
  else
    echo "[!] TARGET 경로가 존재하지 않습니다: $TARGET"
    exit 1
  fi
elif [[ -f pyproject.toml ]]; then
  :  # 현재 디렉터리가 프로젝트 루트 → 그대로 분석
elif [[ -n "$PROJECT_NAME" && -d "$PROJECT_NAME" ]]; then
  echo "==> 프로젝트 디렉터리로 이동: $PROJECT_NAME"
  cd "$PROJECT_NAME"
else
  echo "[!] 분석할 프로젝트를 찾지 못했습니다. 다음 중 하나로 지정하세요:"
  echo "    - bootstrap으로 만든 하위 프로젝트:  make $MODE PROJECT_NAME=<이름>"
  echo "    - 임의 경로(외부/절대경로 포함):      make $MODE TARGET=<경로>"
  echo "        예) make $MODE TARGET=../../codyssey_B2-1"
  echo "    - 또는 프로젝트 디렉터리 안에서 직접 실행"
  exit 1
fi

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
  mkdir -p docs
  local out="docs/metrics_${PKG}.md"
  echo "==> OOP 지표 측정 (complexipy + radon) — 콘솔 출력 + ${out} 저장"
  echo "    (보고 전용: 커밋 게이트는 pre-commit 훅이 담당. .venv는 제외)"

  # 각 도구를 1회씩 실행해 결과를 캡처(콘솔엔 그대로, docs엔 Markdown으로 저장).
  # --ignore-complexity: 임계 초과여도 실패시키지 않고 표만 출력. --sort desc: 복잡한 것부터.
  local cx rcc rmi
  cx="$(uvx complexipy "$SRC" --ignore-complexity --sort desc 2>&1 || true)"
  rcc="$(uvx radon cc -s -a -i ".venv" "$SRC" 2>&1 || true)"
  rmi="$(uvx radon mi -i ".venv" "$SRC" 2>&1 || true)"

  # 콘솔 출력
  echo; echo "--- 인지 복잡도 (complexipy, 임계 15) ---"; echo "$cx"
  echo; echo "--- 순환 복잡도 (radon cc, A~F) ---";       echo "$rcc"
  echo; echo "--- 유지보수 지수 (radon mi) ---";           echo "$rmi"

  # docs/ 저장 (diagram과 동일하게 대상 프로젝트 안에 남긴다)
  {
    printf '# 코드 품질 지표 — %s\n\n' "$PKG"
    printf '_생성: %s · 대상: `%s`_\n\n' "$(date '+%Y-%m-%d %H:%M')" "$SRC"
    printf '> 인지 복잡도(complexipy)와 순환 복잡도(radon cc)는 서로 다른 지표다.\n'
    printf '> complexipy의 `FAILED`, radon의 `C`~`F` 등급을 우선 점검할 것.\n\n'
    printf '## 인지 복잡도 · complexipy (임계 15)\n\n```text\n%s\n```\n\n' "$cx"
    printf '## 순환 복잡도 · radon cc (A~F 등급)\n\n```text\n%s\n```\n\n' "$rcc"
    printf '## 유지보수 지수 · radon mi\n\n```text\n%s\n```\n' "$rmi"
  } > "$out"
  echo; echo "    -> ${out} 저장됨"
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
