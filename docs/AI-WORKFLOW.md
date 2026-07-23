# AI-WORKFLOW.md — Claude Code 작업 지침 (dev-env-bootstrap)

> **사람을 위한 안내 (이 블록은 AI 지침이 아님)**
>
> 이 문서는 Claude Code(Opus 등)에게 dev-env-bootstrap 관련 작업을 시키기 전에
> **언제든 주입할 수 있는 컨텍스트 문서**다. 주입 방법은 셋 중 하나:
>
> 1. **상시 주입(권장)** — 이 파일을 프로젝트 루트에 `CLAUDE.md`로 복사한다.
>    Claude Code가 매 세션 시작 시 자동으로 읽는다.
>    ```bash
>    cp docs/AI-WORKFLOW.md CLAUDE.md
>    ```
> 2. **세션 중 참조** — 프롬프트에서 `@docs/AI-WORKFLOW.md` 로 언급하면
>    Claude가 해당 파일을 읽고 따른다.
> 3. **비대화형 실행** — `claude -p "..."` 스크립트/CI에서 쓸 때 프롬프트 앞에
>    이 파일 내용을 붙여 넣는다.
>
> 아래부터가 Claude에게 전달되는 본문이다. CLAUDE.md 모범사례에 따라
> "지웠을 때 실수가 생기는 규칙"만 남기고 짧게 유지했다. 규칙을 추가할 때도
> 같은 기준을 적용할 것.

---

## 프로젝트 컨텍스트

- 이 저장소는 **Makefile 기반 크로스플랫폼 개발환경 자동화 도구**다.
  `make setup`(전역 도구 설치) / `make project`(스캐폴딩) / `make test`(테스트)가 진입점.
- 표준 스택: **uv**(파이썬·패키지·버전 통합관리) + **Ruff**(린터+포매터) +
  **pytest** + VS Code(+ Claude Code 익스텐션). 웹은 **Prettier + ESLint + Vitest**.
- Windows에서는 make를 **WSL2 안에서** 실행한다. `bootstrap.ps1`이 WSL2를 자동 설치한다.

## 자주 쓰는 명령

```bash
make help                          # 타겟 목록 + 감지된 OS
make setup                         # 전역 도구 설치 (uv, Ruff, pre-commit, VS Code 익스텐션)
make project                       # 파이썬 프로젝트 스캐폴딩 (버전 인터랙티브 질문)
make project PROJ_LANG=web         # 웹(HTML/CSS/JS) 프로젝트 스캐폴딩
make test                          # PROJECT_NAME 디렉터리의 테스트 실행 (실패 시 exit≠0)
make test PROJECT_NAME=demo        # 특정 프로젝트의 테스트 실행
make report                        # 실행 프로파일 보고서 -> reports/<날짜>.md
uv run pytest -v                   # 생성된 프로젝트 안에서 테스트 직접 실행
uv add --dev <pkg>                 # dev 의존성 추가 (pip 대신 반드시 uv)
uvx ruff check --fix . && uvx ruff format .   # 커밋 전 린트+포맷
make diagram                       # UML 클래스/패키지 다이어그램 (pyreverse -> docs/*.mmd)
make metrics                       # 인지복잡도(complexipy) + 순환복잡도/MI(radon)
make arch                          # 아키텍처 규칙 검사 (tach; 최초 1회 `uvx tach init` 필요)
```

## 하드 규칙 (어기면 빌드/실행이 깨진다)

- **Makefile recipe 줄은 반드시 TAB 들여쓰기.** 스페이스로 바꾸면 `missing separator` 에러.
- **모든 셸 스크립트·Makefile·설정 파일은 LF 줄바꿈.** CRLF면 WSL/bash에서 실행 실패.
  Windows에서 편집 후에는 줄바꿈을 확인할 것.
- **bootstrap.ps1은 UTF-8 (BOM 포함)으로 저장.** Windows PowerShell 5.1은 BOM이 없으면
  파일을 ANSI(CP949)로 읽어 한국어 주석이 깨지고 **파스 에러로 실행 자체가 실패**한다.
  반대로 **셸 스크립트(.sh)에는 BOM 금지** (shebang 파괴).
- **언어 선택 변수는 `PROJ_LANG`이다. `LANG`이 아니다.** `LANG`은 Unix 로케일
  환경변수와 충돌하므로 리네임했다. Makefile/dev.config/문서 어디에도 `LANG`을 되돌리지 말 것.
- **파이썬 패키지 작업은 uv만 사용.** `pip install`, `python -m venv`, `pyenv` 금지.
  전역 CLI 도구는 `uv tool install`, 프로젝트 의존성은 `uv add`.
- **Ruff가 린터+포매터 전부다.** Black, Flake8, isort, pydocstyle을 추가하지 말 것.
  pre-commit 훅 순서는 `ruff-check`(--fix) → `ruff-format` 고정 (공식 권장 순서).
  complexipy 훅은 **반드시 그 뒤에** 온다 (순서를 건드리지 말 것).
- **OOP 분석 3종은 린터가 아니다** — 시각화기(pyreverse)/지표(complexipy·radon)/아키텍처 강제기(tach).
  `make diagram/metrics/arch`에서 `uvx`로 즉석 실행되며 Ruff의 "유일 린터" 원칙과 무관하다.
  - `pyreverse`는 pylint 패키지에 들어있으나 **`pylint`을 린터로 실행하지 말 것** (pyreverse만 호출).
  - 아키텍처 강제기는 **tach 하나만**. import-linter/pytestarch를 함께 추가하지 말 것 (역할 중복).
  - complexipy(인지 복잡도, 커밋 게이트)와 Ruff `C901`(순환 복잡도)은 **다른 지표다. 둘 다 유지**.
- **셸 스크립트는 `#!/usr/bin/env bash` + `set -euo pipefail`** 로 시작하고,
  경로는 CWD 가정 없이 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  기준으로 계산한다 (scripts/ 기존 코드와 동일 패턴).
- **Windows 네이티브에서 make 실행을 허용하지 말 것.** `bootstrap-check` 가드를
  우회하는 변경 금지. Windows 경로는 항상 bootstrap.ps1 → WSL 경유.

## 코드 컨벤션

- Python: Ruff 기준 line-length 88, target py313, lint 규칙
  `E,F,I,UP,B,C901,PLR0911/0912/0913/0915` + `mccabe.max-complexity=10`
  (templates/python/pyproject.toml 참조). 저장 시 자동 포맷을 전제로 작성.
  (`C901`은 순환 복잡도, `PLR09xx`는 too-many-args/branches/returns/statements 설계 냄새.
  소음성 `PLR2004`(매직넘버) 등은 일부러 제외했다 — 전체 `PLR`로 넓히지 말 것.)
- **`templates/python/pyproject.toml`의 `[tool.*]` 섹션은 스캐폴드가 자동 병합한다.**
  `scaffold_project.sh`가 `uv init` 산출물에 `awk '/^\[tool\.ruff\]/{f=1} f'`로 추출·병합한다
  (`[project]`/`[dependency-groups]`는 uv가 관리). Ruff/pytest 설정을 바꾸려면 이 템플릿만 고치면
  새 프로젝트에 반영된다. 병합 앵커(`[tool.ruff]`가 첫 `[tool.*]` 섹션이라는 전제)를 깨지 말 것.
- 웹(JS/HTML/CSS/JSON): Prettier가 포맷, ESLint가 코드 규칙. 역할을 섞지 말 것.
- 새 템플릿 파일을 추가하면 `scripts/scaffold_project.sh`의 복사 로직에도 반영할 것.
- VS Code 익스텐션 목록 변경 시 `scripts/extensions.txt`와
  `templates/vscode/extensions.json` **두 곳을 함께** 갱신할 것.

## 테스트 규약 (TestCase.txt)

- 형식: 한 줄에 `함수명 인자... => 기대값`. `#` 시작 줄과 빈 줄은 무시.
  ```
  add 2 3 => 5
  add 0.1 0.2 => 0.3
  concat "hello world" "!" => "hello world!"
  head [10, 20, 30] => 10
  ```
- `tests/test_from_testcases.py`가 이를 pytest 파라미터화 테스트로 변환한다.
  인자와 기대값은 **파이썬 리터럴**(ast.literal_eval)로 해석: 정수·실수·불리언·None·
  문자열·리스트·튜플·딕셔너리. 리터럴이 아닌 토큰은 문자열 취급.
  따옴표/괄호 안의 공백과 `=>`는 구분자가 아니다. 기대값이 실수면 pytest.approx 근사 비교.
- 파서를 더 확장할 때는(예: 예외 기대 문법) 기존 리터럴 케이스가 깨지지 않음을
  테스트로 증명할 것.

## 성능 측정 규약 (make report / perf.py)

- `make report`가 `reports/<날짜>.md`(테스트·실행 시간·최대 메모리·구간별·입력별 벤치)를
  생성하고 `reports/history.csv`에 요약을 누적한다.
- 특정 구문의 처리 시간을 측정할 때는 코드를 `from perf import span` 후
  `with span("이름"):` 으로 감싼다. perf.py가 없는 프로젝트에서도 동작해야 하는
  코드라면 smoke_test.py처럼 ImportError 시 nullcontext 폴백을 쓸 것.
- **성능 관련 작업(최적화·회귀 확인)은 변경 전후로 `make report`를 실행**해
  보고서 경로와 핵심 수치(벽시계/CPU/peak 메모리) 변화를 증거로 제시할 것.
  단일 수치의 절대값은 노이즈가 있으므로 history.csv 추세나 전후 상대 비교로 판단.
- perf.py를 수정하면 `uvx ruff check --select E,F,I,UP,B --line-length 88` 와
  실제 보고서 생성 1회로 검증할 것.
- 루트에 `smoke_test.py`가 있으면 `make test`가 자동 실행한다. 실패 시 0이 아닌
  종료코드를 반환해야 한다 (assert 사용).

## 작업 완료 전 검증 (반드시 실행하고 결과를 보고할 것)

1. 셸 스크립트를 수정했다면: `bash -n scripts/*.sh` (문법 검사)
2. Makefile을 수정했다면: TAB 들여쓰기 유지 확인 + `make help` 실행 (가능한 환경에서)
3. 파이썬 템플릿을 수정했다면: `python -m py_compile <파일>` + 관련 테스트 실행
4. 전체 흐름을 바꿨다면: 임시 디렉터리에서 `make project` → `make test` 스모크 확인
5. 성공을 주장하지 말고 **실행한 명령과 출력을 증거로 제시**할 것.
   테스트가 실패하면 실패했다고 출력과 함께 보고한다.

## 작업 방식

- **탐색 → 계획 → 구현 → 검증 → 커밋** 순서를 지킨다. 여러 파일을 건드리거나
  접근법이 불확실하면 먼저 plan mode로 계획을 세우고 승인받는다.
  한 문장으로 diff를 설명할 수 있는 작은 수정은 계획 없이 바로 한다.
- 커밋은 요청받았을 때만. 커밋 전 pre-commit 훅(Ruff)이 통과해야 한다.
  훅 실패 시 `--no-verify`로 우회하지 말고 원인을 고친다.
- 넓은 코드베이스 조사가 필요하면 서브에이전트에 위임해 메인 컨텍스트를 아낀다.
- 같은 문제로 두 번 이상 교정받으면 접근법을 바꾸고, 무엇이 잘못됐는지 요약한 뒤
  새로 시작할 것을 제안한다.

---

## 부록: 사람이 Claude Code에게 시킬 때의 프롬프트 요령

> 이 부록은 사용자를 위한 참고다. Claude는 이 요령대로 **요청받는다고 가정**하고,
> 요청이 모호하면 아래 수준의 정보를 되물어 확보한 뒤 작업하라.

| 원칙 | 나쁜 예 | 좋은 예 |
|---|---|---|
| 검증 기준을 함께 준다 | "테스트 기능 개선해줘" | "TestCase.txt에 예외 기대 문법을 추가해줘. `div 1 0 => raises ZeroDivisionError`가 통과해야 하고, 기존 리터럴 케이스도 깨지면 안 돼. 수정 후 `uv run pytest -v` 실행해서 결과 보여줘" |
| 파일·위치를 특정한다 | "설치 스크립트에 버그 있어" | "scripts/install_global.sh 4단계에서 code CLI가 없을 때도 exit 0이 되는지 확인하고, 익스텐션 설치 실패가 전체 setup을 중단시키지 않게 해줘" |
| 기존 패턴을 가리킨다 | "Go 템플릿 추가해줘" | "templates/web이 scaffold_project.sh에 연결된 방식을 보고, 같은 패턴으로 PROJ_LANG=go 지원을 추가해줘" |
| 증상+재현+기대를 준다 | "Windows에서 안 돼" | "bootstrap.ps1 실행 시 'no installed distributions' 상태에서 Test-Wsl2Ready가 true를 반환해. UTF-16 파싱 부분을 확인하고, 재현 케이스와 수정 근거를 보여줘" |

- 큰 기능은 구현 전에 인터뷰를 시켜라: *"…을 만들고 싶어. AskUserQuestion으로
  나를 인터뷰해서 SPEC.md를 만들어줘"* → 새 세션에서 SPEC.md만 주고 구현.
- 무관한 작업 사이에는 `/clear`로 컨텍스트를 비운다.
- 완료 판정 전 리뷰를 시켜라: *"서브에이전트로 이 diff를 검토해서 하드 규칙
  (TAB/LF/PROJ_LANG/uv) 위반과 엣지 케이스만 보고해줘"*.

**출처**: [Anthropic — Claude Code Best Practices](https://code.claude.com/docs/en/best-practices),
[CLAUDE.md 메모리 문서](https://code.claude.com/docs/en/memory),
프로젝트 설계 근거는 `../compass_artifact_wf-c9c9c6c5-29b6-4cbf-bfa1-4eb4b08d8724_text_markdown.md` 참조.
