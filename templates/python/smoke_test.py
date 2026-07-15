"""스모크 테스트: 프로젝트가 최소한 실행되는지 빠르게 확인한다.

`make test` 실행 시 프로젝트 루트에 이 파일이 있으면 자동으로
`uv run python smoke_test.py` 로 실행된다. 실패 시 0이 아닌 종료코드를
반환하도록 assert 를 사용한다.
"""

import sys


def add(a, b):
    return a + b


def main() -> int:
    # 기본 동작 확인 (실제 프로젝트 로직으로 교체하세요)
    assert add(2, 3) == 5, "add(2, 3) 가 5가 아닙니다"
    assert add(-1, 1) == 0, "add(-1, 1) 가 0이 아닙니다"
    print("[OK] 스모크 테스트 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
