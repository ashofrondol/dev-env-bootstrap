# dev-env-bootstrap

크로스플랫폼 `make` 기반 개발환경 **자동 설치 + 프로젝트 스캐폴딩** 도구.
스택은 2026년 표준 조합인 **uv · Ruff · pytest · Claude Code**를 기본으로 한다.

- `make setup` — 전역 개발 도구 설치 (uv, Ruff, pre-commit, VS Code 익스텐션)
- `make project` — 새 프로젝트 스캐폴딩 (파이썬 버전을 인터랙티브로 질문)
- `make project PROJ_LANG=web` — HTML/CSS/JS 프로젝트 스캐폴딩
- `make test` — `TestCase.txt` 파라미터화 테스트 + 스모크 테스트 실행
- `make report` — 실행 프로파일 보고서 생성 (시간·메모리·구간별·입력별 → `reports/*.md`)
- `make help` / `make os-info` — 도움말 / 감지된 OS 출력

## 문서

- **사용 가이드 (사람용)**: [docs/USAGE.html](docs/USAGE.html) — 브라우저로 열어 보세요.
- **AI 작업 지침 (Claude Code용)**: [docs/AI-WORKFLOW.md](docs/AI-WORKFLOW.md) —
  `cp docs/AI-WORKFLOW.md CLAUDE.md` 로 복사하거나 프롬프트에서 `@docs/AI-WORKFLOW.md` 로 참조.

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
│   ├── run_report.sh             # 실행 프로파일 보고서 생성
│   └── extensions.txt            # 설치할 VS Code 익스텐션 목록
└── templates/
    ├── vscode/{settings.json, extensions.json}
    ├── python/{pyproject.toml, .pre-commit-config.yaml, perf.py,
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

각 줄을 `함수명 인자... => 기대값` 형식으로 적으면 pytest 파라미터화 테스트로 변환된다.
인자와 기대값은 **파이썬 리터럴**로 해석된다 (정수·실수·불리언·None·문자열·리스트·튜플·딕셔너리).

```
# 형식: 함수명 인자... => 기대값
add 2 3 => 5
add 0.1 0.2 => 0.3                       # 실수는 근사 비교(pytest.approx)
concat "hello world" "!" => "hello world!"
head [10, 20, 30] => 10
merge {"a": 1} {"b": 2} => {"a": 1, "b": 2}
```

- `tests/test_from_testcases.py`가 위 파일을 읽어 자동으로 케이스를 생성한다.
  따옴표/괄호 안의 공백과 `=>`는 구분자로 취급하지 않으며, 리터럴이 아닌 토큰은
  문자열로 취급한다 (`upper hello => HELLO` 가능).
- 루트에 `smoke_test.py`가 있으면 `make test`가 이어서 실행한다.
- `make test`는 저장소 루트에서 실행하면 `PROJECT_NAME` 디렉터리로 이동해 실행하고,
  테스트 실패를 종료코드로 그대로 전파한다 (CI 게이트 가능).

## 실행 프로파일 보고서 (`make report`)

`make report`(또는 프로젝트 안에서 `uv run python perf.py`)를 실행하면
`reports/<날짜>.md` 보고서가 생성되고 `reports/history.csv`에 요약이 누적된다.

| 섹션 | 내용 |
| --- | --- |
| 1. 테스트 | pytest 요약 + 가장 느린 테스트 Top 10 |
| 2. 실행 계측 | 대상 스크립트(기본 `smoke_test.py`)의 벽시계/CPU 시간, 최대 메모리 |
| 3. 구간별 측정 | `with span("이름"):` 으로 감싼 구간의 시간·메모리 증가 |
| 4. 프로파일 | cProfile 누적시간 상위 함수 (별도 실행이라 §2보다 느림 — 상대 비교용) |
| 5. 입력 변동 벤치 | `TestCase.txt` 케이스별 시간/메모리 — 입력 크기에 따른 변동 확인 |

```python
# 코드에서 특정 구간을 측정하려면:
from perf import span

with span("파싱"):
    parse(...)
```

옵션: `uv run python perf.py --target main.py --repeat 7 --no-profile` 등.
측정 수치는 환경 부하에 따라 변동하므로 절대값보다 `history.csv` 추세 비교에 쓰는 것을 권장.
더 깊은 분석이 필요하면 scalene(라인 수준), memray(메모리 심층),
pytest-benchmark(마이크로벤치), hyperfine(CLI 비교)을 검토하라.

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
