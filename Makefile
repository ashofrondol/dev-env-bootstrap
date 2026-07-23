# ============================================================
# 크로스플랫폼 개발환경 자동화 Makefile
# 사용법:
#   make setup              # 전역 도구 설치 (uv, VS Code 익스텐션 등)
#   make project            # 새 프로젝트 스캐폴딩 (기본 언어 = python)
#   make project PROJ_LANG=web   # HTML/CSS/JS 프로젝트
#   make test               # TestCase.txt + 스모크 테스트 실행
#   make help               # 사용 가능한 타겟 목록
# ============================================================

# ---------- 설정 파일 로드 ----------
CONFIG ?= dev.config
ifneq (,$(wildcard $(CONFIG)))
include $(CONFIG)
endif

# 기본값 (dev.config에서 재정의 가능)
# 주의: 언어 변수는 Unix 로케일 환경변수 LANG 과 충돌하지 않도록 PROJ_LANG 사용
DEFAULT_PYTHON_VERSION ?= 3.13
PROJ_LANG ?= python
PROJECT_NAME ?= my-project

# 블랙박스 그레이더 폴더 이름 — '루트 바로 위 상위 디렉터리'(이 저장소의 부모)에서 찾는다.
GRADER_DIRNAME ?= blackbox-tests

# ---------- OS 감지 ----------
# Windows cmd에서 실행 시 OS 환경변수 = Windows_NT
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        # WSL 내부인지 확인 (커널 릴리스에 microsoft 포함)
        ifneq (,$(findstring microsoft,$(shell uname -r 2>/dev/null)))
            DETECTED_OS := WSL
        else
            DETECTED_OS := Linux
        endif
    endif
    ifeq ($(UNAME_S),Darwin)
        DETECTED_OS := macOS
    endif
endif

SHELL := /bin/bash

.PHONY: help setup project test report diagram metrics arch grade grade-detect os-info bootstrap-check

help:
	@echo "감지된 OS: $(DETECTED_OS)"
	@echo ""
	@echo "사용 가능한 명령:"
	@echo "  make setup            - 전역 개발도구 설치 (uv, VS Code 익스텐션)"
	@echo "  make project               - 새 프로젝트 생성 (PROJ_LANG=python 기본)"
	@echo "  make project PROJ_LANG=web - 웹(HTML/CSS/JS) 프로젝트 생성"
	@echo "  make test             - TestCase.txt 및 스모크 테스트 실행"
	@echo "  make report           - 실행 프로파일 보고서 생성 (reports/*.md)"
	@echo "  make diagram          - UML 클래스/패키지 다이어그램 생성 (pyreverse, Mermaid → docs/*.mmd)"
	@echo "  make metrics          - OOP 지표: 인지 복잡도(complexipy) + 순환복잡도/MI(radon)"
	@echo "  make arch             - 아키텍처 규칙 검사 (tach check; 최초 1회 'uvx tach init' 필요)"
	@echo "     └ 외부(비-bootstrap) 프로젝트 분석: diagram/metrics/arch 에 TARGET=<경로> 추가"
	@echo "        예) make metrics TARGET=../../codyssey_B2-1 SRC=src"
	@echo "  make grade-detect     - 상위 폴더의 블랙박스 그레이더 발견 여부 확인"
	@echo "  make grade TARGET=<경로> [ASSIGNMENT=<과제ID>] [MODULE=<모듈명>]"
	@echo "                        - 발견한 그레이더로 대상 구현을 블랙박스 채점"

os-info:
	@echo "OS = $(DETECTED_OS), 기본 파이썬 = $(DEFAULT_PYTHON_VERSION)"

# ---------- Windows 가드 ----------
# Windows 네이티브(cmd/pwsh)에서 make를 직접 부른 경우 안내
bootstrap-check:
ifeq ($(DETECTED_OS),Windows)
	@echo "[!] Windows 네이티브 환경입니다. WSL2 안에서 실행해야 합니다."
	@echo "    PowerShell(관리자)에서 다음을 실행하세요:"
	@echo "    powershell -ExecutionPolicy Bypass -File bootstrap.ps1"
	@exit 1
endif

# ---------- 전역 도구 설치 ----------
setup: bootstrap-check
	@bash scripts/install_global.sh "$(DEFAULT_PYTHON_VERSION)"

# ---------- 프로젝트 스캐폴딩 ----------
# 파이썬 버전을 인터랙티브로 묻고, 미입력 시 config 기본값 사용
project: bootstrap-check
	@bash scripts/scaffold_project.sh "$(PROJ_LANG)" "$(PROJECT_NAME)" "$(DEFAULT_PYTHON_VERSION)"

# ---------- 테스트 실행 ----------
# 저장소 루트에서 실행하면 PROJECT_NAME 디렉터리의 테스트를 돌린다
test: bootstrap-check
	@bash scripts/run_tests.sh "$(PROJ_LANG)" "$(PROJECT_NAME)"

# ---------- 실행 프로파일 보고서 ----------
# 시간/메모리/구간별 측정 결과를 reports/<날짜>.md 로 남긴다
report: bootstrap-check
	@bash scripts/run_report.sh "$(PROJ_LANG)" "$(PROJECT_NAME)" "$(TARGET)"

# ---------- OOP 구조 분석 (시각화 / 지표 / 아키텍처) ----------
# 도구는 모두 uvx로 즉석 실행(pyreverse/complexipy/radon/tach) → 전역 설치 불필요.
# 대상 지정:  TARGET=<경로>  (bootstrap 밖 프로젝트, 절대/상대경로 모두 가능)
#            SRC=<하위경로> (패키지가 src/ 등 하위에 있을 때 좁히기)
#   예) make metrics TARGET=../../codyssey_B2-1 SRC=src
diagram: bootstrap-check
	@bash scripts/run_analysis.sh diagram "$(PROJ_LANG)" "$(PROJECT_NAME)" "$(TARGET)" "$(SRC)"

metrics: bootstrap-check
	@bash scripts/run_analysis.sh metrics "$(PROJ_LANG)" "$(PROJECT_NAME)" "$(TARGET)" "$(SRC)"

arch: bootstrap-check
	@bash scripts/run_analysis.sh arch "$(PROJ_LANG)" "$(PROJECT_NAME)" "$(TARGET)" "$(SRC)"

# ---------- 블랙박스 그레이더 자동 발견 & 실행 ----------
# 이 저장소의 '루트 바로 위 상위 디렉터리'(= 부모 폴더)에서 GRADER_DIRNAME 을 찾아,
# 그 안의 grade.sh 로 대상 구현(내 것/남의 것)을 블랙박스 채점한다.
#   make grade-detect
#   make grade TARGET=~/Desktop/codyssey_B2-1
#   make grade TARGET=~/classmates/kim ASSIGNMENT=b2_1_budget_app MODULE=my_app
PARENT_DIR := $(abspath $(CURDIR)/..)
GRADER_PATH := $(PARENT_DIR)/$(GRADER_DIRNAME)

grade-detect:
	@bash scripts/run_graders.sh --detect "$(GRADER_PATH)"

grade: bootstrap-check
	@bash scripts/run_graders.sh "$(GRADER_PATH)" "$(TARGET)" "$(ASSIGNMENT)" "$(MODULE)"
