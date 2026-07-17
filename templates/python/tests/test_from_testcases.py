"""TestCase.txt를 읽어 자동으로 파라미터화 테스트를 생성한다.

형식: 한 줄에 ``함수명 인자... => 기대값``

- 인자와 기대값은 파이썬 리터럴로 해석한다 (ast.literal_eval):
  정수, 실수, 불리언(True/False), None, 문자열("..." 또는 '...'),
  리스트, 튜플, 딕셔너리.
- 리터럴로 해석할 수 없는 토큰은 문자열 그대로 취급한다.
  (하위호환: ``add 2 3 => 5`` 같은 기존 정수 케이스는 그대로 동작)
- 따옴표/괄호 안의 공백과 "=>"는 구분자로 취급하지 않는다.
  (``concat "a => b" [1, 2] => ...`` 가능)
- 기대값이 실수면 pytest.approx로 근사 비교한다 (0.1+0.2 문제 방지).
- ``#`` 로 시작하는 줄과 빈 줄은 무시한다.

예시::

    add 2 3 => 5
    add 0.1 0.2 => 0.3
    concat "hello world" "!" => "hello world!"
    head [10, 20, 30] => 10
"""

import ast
import pathlib

import pytest


# 테스트 대상 함수 (실제 프로젝트에서는 import로 교체)
def add(a, b):
    return a + b


def _split_arrow(line):
    """따옴표/괄호 밖에 있는 첫 '=>' 에서 줄을 (왼쪽, 오른쪽)으로 나눈다."""
    depth = 0
    quote = None
    prev = ""
    for i, ch in enumerate(line):
        if quote is not None:
            if ch == quote and prev != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == ">" and prev == "=" and depth == 0:
            return line[: i - 1], line[i + 1 :]
        prev = ch
    return None


def _tokenize(text):
    """공백으로 토큰을 나누되, 따옴표/괄호 내부의 공백은 유지한다."""
    tokens = []
    buf = []
    depth = 0
    quote = None
    for ch in text:
        if quote is not None:
            buf.append(ch)
            if ch == quote and (len(buf) < 2 or buf[-2] != "\\"):
                quote = None
        elif ch in "\"'":
            quote = ch
            buf.append(ch)
        elif ch in "([{":
            depth += 1
            buf.append(ch)
        elif ch in ")]}":
            depth -= 1
            buf.append(ch)
        elif ch.isspace() and depth == 0:
            if buf:
                tokens.append("".join(buf))
                buf = []
        else:
            buf.append(ch)
    if buf:
        tokens.append("".join(buf))
    return tokens


def _parse_value(token):
    """토큰을 파이썬 리터럴로 해석하고, 실패하면 문자열 그대로 반환한다."""
    try:
        return ast.literal_eval(token)
    except (ValueError, SyntaxError):
        return token


def _load_cases():
    path = pathlib.Path(__file__).parent.parent / "TestCase.txt"
    cases = []
    if not path.exists():
        return cases
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        split = _split_arrow(line)
        if split is None:
            continue  # '=>' 가 없는 줄은 무시
        left, expected = split
        parts = _tokenize(left.strip())
        if not parts:
            continue  # 함수명이 없는 잘못된 줄은 무시
        func = parts[0]
        args = [_parse_value(t) for t in parts[1:]]
        cases.append((func, args, _parse_value(expected.strip())))
    return cases


def _case_id(case):
    func, args, expected = case
    arg_str = ", ".join(repr(a) for a in args)
    return f"{func}({arg_str}) => {expected!r}"


_CASES = _load_cases()


@pytest.mark.parametrize(
    "func,args,expected", _CASES, ids=[_case_id(c) for c in _CASES]
)
def test_from_testcases(func, args, expected):
    fn = globals().get(func)
    if not callable(fn):
        pytest.fail(
            f"TestCase.txt의 함수 '{func}' 를 찾을 수 없습니다. "
            "이 파일에 정의하거나 import 하세요."
        )
    result = fn(*args)
    if isinstance(expected, float):
        assert result == pytest.approx(expected)
    else:
        assert result == expected
