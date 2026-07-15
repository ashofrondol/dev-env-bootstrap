"""TestCase.txt를 읽어 자동으로 파라미터화 테스트를 생성한다."""

import pathlib

import pytest


# 테스트 대상 함수 (실제 프로젝트에서는 import로 교체)
def add(a, b):
    return a + b


def _load_cases():
    path = pathlib.Path(__file__).parent.parent / "TestCase.txt"
    cases = []
    if not path.exists():
        return cases
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=>" not in line:
            continue
        left, expected = line.split("=>")
        parts = left.split()
        func, args = parts[0], [int(x) for x in parts[1:]]
        cases.append((func, args, int(expected.strip())))
    return cases


@pytest.mark.parametrize("func,args,expected", _load_cases())
def test_from_testcases(func, args, expected):
    fn = globals()[func]
    assert fn(*args) == expected
