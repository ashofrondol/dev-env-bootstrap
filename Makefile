# ============================================================
# 크로스플랫폼 개발환경 자동화 Makefile
# 사용법:
#   make setup              # 전역 도구 설치 (uv, VS Code 익스텐션 등)
#   make project            # 새 프로젝트 스캐폴딩 (기본 언어 = python)
#   make project LANG=web   # HTML/CSS/JS 프로젝트
#   make test               # TestCase.txt + 스모크 테스트 실행
#   make help               # 사용 가능한 타겟 목록
# ============================================================

# ---------- 설정 파일 로드 ----------
CONFIG ?= dev.config
ifneq (,$(wildcard $(CONFIG)))
include $(CONFIG)
endif

# 기본값 (dev.config에서 재정의 가능)
DEFAULT_PYTHON_VERSION ?= 3.13
LANG ?= python
PROJECT_NAME ?= my-project

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

.PHONY: help setup project test os-info bootstrap-check

help:
	@echo "감지된 OS: $(DETECTED_OS)"
	@echo ""
	@echo "사용 가능한 명령:"
	@echo "  make setup            - 전역 개발도구 설치 (uv, VS Code 익스텐션)"
	@echo "  make project          - 새 프로젝트 생성 (LANG=python 기본)"
	@echo "  make project LANG=web - 웹(HTML/CSS/JS) 프로젝트 생성"
	@echo "  make test             - TestCase.txt 및 스모크 테스트 실행"

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
	@bash scripts/scaffold_project.sh "$(LANG)" "$(PROJECT_NAME)" "$(DEFAULT_PYTHON_VERSION)"

# ---------- 테스트 실행 ----------
test: bootstrap-check
	@bash scripts/run_tests.sh "$(LANG)"
