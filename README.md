# dev-env-bootstrap

크로스플랫폼 `make` 기반 개발환경 **자동 설치 + 프로젝트 스캐폴딩** 도구.
스택은 2026년 표준 조합인 **uv · Ruff · pytest · Claude Code**를 기본으로 한다.

- `make setup` — 전역 개발 도구 설치 (uv, Ruff, pre-commit, VS Code 익스텐션)
- `make project` — 새 프로젝트 스캐폴딩 (파이썬 버전을 인터랙티브로 질문)
- `make project PROJ_LANG=web` — HTML/CSS/JS 프로젝트 스캐폴딩
- `make test` — `TestCase.txt` 파라미터화 테스트 + 스모크 테스트 실행
- `make help` / `make os-info` — 도움말 / 감지된 OS 출력

## 요구 사항

| OS | 실행 방식 |
| --- | --- |
| **Linux / macOS** | `make`가 네이티브로 동작 |
| **Windows** | `make`를 **WSL2 안에서** 실행 (`bootstrap.ps1`이 WSL2 자동 설치) |

`make setup`은 `curl`로 uv를 내려받으므로 인터넷 연결이 필요하다.

## 빠른 시작

### Linux / macOS

```bash
cd dev-env-bootstrap
make setup            # 전역 도구 설치 (최초 1회)
make project          # 새 파이썬 프로젝트 생성
make test             # 테스트 실행
```

### Windows

관리자 PowerShell에서:

```powershell
cd dev-env-bootstrap
powershell -ExecutionPolicy Bypass -File bootstrap.ps1
```

- WSL2가 없으면 자동 설치 → 재부팅 → 로그인 시 RunOnce 키로 부트스트랩을 이어서 실행한다.
- WSL2가 이미 있으면 곧바로 WSL 내부에서 `make setup`을 실행한다.
- 이후에는 WSL 셸에서 `make project`, `make test`를 사용한다.

> 성능 팁: WSL2에서 `/mnt/c`(Windows NTFS) 경로는 느리다. 실제 개발은 WSL 홈(`~/`)에
> 프로젝트를 두는 것이 I/O상 유리하다.

## 프로젝트 구조

```
dev-env-bootstrap/
├── Makefile                      # 진입점 (OS 감지, setup/project/test 타겟)
├── dev.config                    # 기본값 (파이썬 버전, 언어, 프로젝트명)
├── bootstrap.ps1                 # Windows: WSL2 자동 설치 부트스트랩
├── scripts/
│   ├── install_global.sh         # 전역 도구 설치 (uv, code CLI, 익스텐션)
│   ├── scaffold_project.sh       # 프로젝트 생성 로직
│   ├── run_tests.sh              # TestCase.txt 파싱 + 스모크 테스트
│   └── extensions.txt            # 설치할 VS Code 익스텐션 목록
└── templates/
    ├── vscode/{settings.json, extensions.json}
    ├── python/{pyproject.toml, .pre-commit-config.yaml,
    │           smoke_test.py, tests/test_from_testcases.py}
    └── web/{package.json, index.html}
```

## 설정 (`dev.config`)

`make`가 include하는 `KEY = VALUE` 파일. 값을 바꾸거나 커맨드라인으로 덮어쓸 수 있다.

```makefile
DEFAULT_PYTHON_VERSION = 3.13   # 파이썬 기본 버전
PROJ_LANG = python              # 기본 언어 (python | web) — 로케일 LANG 과 구분
TEST_FRAMEWORK = pytest         # 테스트 프레임워크
PROJECT_NAME = my-project       # 기본 프로젝트 이름
```

커맨드라인 덮어쓰기 예시:

```bash
make project PROJ_LANG=web PROJECT_NAME=my-site
make setup DEFAULT_PYTHON_VERSION=3.12
```

## 도구 스택 (왜 이 조합인가)

| 역할 | 도구 | 비고 |
| --- | --- | --- |
| 파이썬·패키지·버전 관리 | **uv** | pip/venv/pyenv/pipx 통합, Rust 단일 바이너리 |
| 린터 + 포매터 | **Ruff** | Flake8·Black·isort 대체, 저장 시 자동 수정 |
| 타입 체크 | **Pylance** | Ruff와 역할 분담 (중복 린팅은 끔) |
| 테스트 | **pytest** / **Vitest** | 파이썬 / JS |
| 커밋 훅 | **pre-commit** | 커밋 시 Ruff 자동 검사·수정 |
| AI 코딩 | **Claude Code** | `anthropic.claude-code` 익스텐션 |

저장 시 자동 포맷·임포트 정렬·lint 자동수정은 `templates/vscode/settings.json`에서 켜진다.

## 테스트 방식 (`TestCase.txt`)

각 줄을 `함수인자 => 기대값` 형식으로 적으면 pytest 파라미터화 테스트로 변환된다.

```
# 형식: 함수인자 => 기대값
add 2 3 => 5
add -1 1 => 0
```

- `tests/test_from_testcases.py`가 위 파일을 읽어 자동으로 케이스를 생성한다.
- 루트에 `smoke_test.py`가 있으면 `make test`가 이어서 실행한다.
- 파서는 정수 인자 예시 기준으로 단순화돼 있으니, 문자열/실수/리스트가 필요하면 파싱 로직을 확장하라.

## 다음 단계 (선택)

- 프로젝트가 3개 이상, 도구 버전이 제각각이면 → **mise** (`mise.toml` 하나로 버전+태스크 통합)
- 협업/완전 재현성이 필요하면 → **devcontainer** (OS별 설치 문제 소멸)
- 템플릿을 자주 개선하면 → **copier** (`copier update`로 기존 프로젝트에 반영)

## 주의 사항

- uv/Ruff 버전 값은 작성 시점 기준이며 릴리스가 잦다. `pre-commit autoupdate`로 갱신 권장.
- Windows 무인 재개(RunOnce)는 재부팅 후 **사용자 로그인**이 있어야 실행된다.
- WSL2는 BIOS/UEFI 가상화 활성화와 SLAT 지원 CPU가 필요하다.
- Claude Code 익스텐션은 유료 Claude 구독 또는 API 키가 있어야 실제 동작한다.
- `code` CLI가 없으면 VS Code 명령팔레트에서 "Shell Command: Install 'code' command in PATH"를 먼저 실행하라.
