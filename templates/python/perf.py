"""실행 프로파일 보고서 생성기 + 구간 측정 헬퍼.

사용법 (프로젝트 루트에서)::

    uv run python perf.py                     # 보고서 -> reports/<날짜>.md
    uv run python perf.py --target main.py --repeat 7
    make report                               # 위와 동일 (저장소 루트에서도 가능)

코드 안의 특정 구간을 측정하려면::

    from perf import span

    with span("파싱"):
        parse(...)

보고서 구성:
  1. pytest 요약 + 가장 느린 테스트 (--durations)
  2. 대상 스크립트 실행 계측 (벽시계/CPU 시간, 최대 메모리)
  3. cProfile 누적시간 상위 함수 (오버헤드가 있어 별도 실행)
  4. span() 구간별 시간/메모리 증가
  5. TestCase.txt 입력별 벤치마크 (반복 실행 중앙값)
실행마다 reports/history.csv 에 한 줄 요약이 누적된다 (추세 추적용).
"""

import argparse
import atexit
import csv
import datetime
import importlib.util
import io
import json
import os
import pathlib
import pstats
import re
import statistics
import subprocess
import sys
import tempfile
import time
import tracemalloc
from contextlib import contextmanager

try:
    import psutil
except ImportError:  # 자원 측정은 psutil 우선, 없으면 POSIX resource로 폴백
    psutil = None

try:
    import resource
except ImportError:  # Windows 네이티브에는 resource 모듈이 없다
    resource = None

# ---------- 구간 측정 (import해서 쓰는 부분) ----------

_SPANS: list[dict] = []


@contextmanager
def span(name: str):
    """`with span("이름"):` 으로 감싼 구간의 시간과 메모리 증가를 기록한다."""
    started_tracing = False
    if not tracemalloc.is_tracing():
        tracemalloc.start()
        started_tracing = True
    mem0 = tracemalloc.get_traced_memory()[0]
    t0 = time.perf_counter()
    try:
        yield
    finally:
        elapsed = time.perf_counter() - t0
        mem_delta = tracemalloc.get_traced_memory()[0] - mem0
        _SPANS.append({"name": name, "seconds": elapsed, "mem_bytes": mem_delta})
        if started_tracing:
            tracemalloc.stop()


def _dump_spans():
    """PERF_SPANS_FILE 환경변수가 있으면 종료 시 구간 기록을 JSON으로 남긴다."""
    out = os.environ.get("PERF_SPANS_FILE")
    if out and _SPANS:
        pathlib.Path(out).write_text(
            json.dumps(_SPANS, ensure_ascii=False), encoding="utf-8"
        )


atexit.register(_dump_spans)

# ---------- 포맷 헬퍼 ----------


def fmt_time(seconds: float) -> str:
    if seconds < 1e-6:
        return f"{seconds * 1e9:.0f}ns"
    if seconds < 1e-3:
        return f"{seconds * 1e6:.1f}µs"
    if seconds < 1:
        return f"{seconds * 1e3:.1f}ms"
    return f"{seconds:.2f}s"


def fmt_bytes(n: float, signed: bool = False) -> str:
    sign = ("+" if n >= 0 else "-") if signed else ""
    n = abs(n)
    for unit in ("B", "KB", "MB"):
        if n < 1024:
            return f"{sign}{n:.0f}{unit}" if unit == "B" else f"{sign}{n:.1f}{unit}"
        n /= 1024
    return f"{sign}{n:.1f}GB"


# ---------- 보고서 섹션 ----------


def section_pytest() -> tuple[str, dict]:
    cmd = [sys.executable, "-m", "pytest", "-q", "--durations=10"]
    proc = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    out = (proc.stdout + proc.stderr).strip()
    if "No module named pytest" in out:
        return "## 1. 테스트\n\npytest 미설치 -> 건너뜀 (`uv add --dev pytest`)\n", {}
    passed = failed = 0
    m = re.search(r"(\d+) passed", out)
    if m:
        passed = int(m.group(1))
    m = re.search(r"(\d+) failed", out)
    if m:
        failed = int(m.group(1))
    tail = "\n".join(out.splitlines()[-15:])
    md = (
        f"## 1. 테스트\n\n- **{passed} passed, {failed} failed**"
        f" (exit={proc.returncode})\n\n```\n{tail}\n```\n"
    )
    return md, {"passed": passed, "failed": failed}


def _win_child_usage(proc) -> tuple[float | None, int | None]:
    """종료된 자식의 CPU 시간·peak RSS를 프로세스 핸들로 조회한다 (Windows).

    샘플링은 종료 직전 값을 놓치지만, subprocess가 쥔 핸들로는 종료 후에도
    GetProcessTimes / GetProcessMemoryInfo 가 정확한 최종값을 준다.
    """
    try:
        import ctypes
        import ctypes.wintypes as wt

        class FILETIME(ctypes.Structure):
            _fields_ = [("lo", wt.DWORD), ("hi", wt.DWORD)]

        class PMC(ctypes.Structure):
            _fields_ = [
                ("cb", wt.DWORD),
                ("PageFaultCount", wt.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t),
            ]

        def _ft_seconds(ft: FILETIME) -> float:
            return ((ft.hi << 32) | ft.lo) / 1e7  # 100ns 단위

        k32 = ctypes.windll.kernel32
        handle = wt.HANDLE(int(proc._handle))  # subprocess가 보유한 OS 핸들
        c, e, kt, ut = FILETIME(), FILETIME(), FILETIME(), FILETIME()
        cpu = None
        if k32.GetProcessTimes(
            handle,
            ctypes.byref(c),
            ctypes.byref(e),
            ctypes.byref(kt),
            ctypes.byref(ut),
        ):
            cpu = _ft_seconds(kt) + _ft_seconds(ut)
        pmc = PMC()
        pmc.cb = ctypes.sizeof(PMC)
        peak = None
        if k32.K32GetProcessMemoryInfo(handle, ctypes.byref(pmc), pmc.cb):
            peak = int(pmc.PeakWorkingSetSize)
        return cpu, peak
    except Exception:
        return None, None


def _measure_child(cmd: list[str], env: dict) -> dict:
    """자식 프로세스를 실행하며 벽시계/CPU 시간과 최대 RSS를 측정한다."""
    r0 = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
    t0 = time.perf_counter()
    proc = subprocess.Popen(cmd, env=env)
    max_rss = 0
    cpu_sampled = 0.0
    watcher = psutil.Process(proc.pid) if psutil else None
    while proc.poll() is None:
        if watcher is not None:
            try:
                mem = watcher.memory_info()
                max_rss = max(max_rss, mem.rss, getattr(mem, "peak_wset", 0))
                t = watcher.cpu_times()
                cpu_sampled = t.user + t.system
            except Exception:  # 프로세스가 방금 종료된 경우 등
                pass
        time.sleep(0.02)
    wall = time.perf_counter() - t0
    cpu = cpu_sampled
    if r0 is not None:
        # POSIX: getrusage 델타가 샘플링보다 정확 (CPU 시간은 누적치라 델타 유효)
        r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
        cpu = (r1.ru_utime + r1.ru_stime) - (r0.ru_utime + r0.ru_stime)
    elif sys.platform == "win32":
        win_cpu, win_peak = _win_child_usage(proc)
        if win_cpu is not None:
            cpu = win_cpu
        if win_peak:
            max_rss = max(max_rss, win_peak)
    return {
        "wall": wall,
        "cpu": cpu,
        "max_rss": max_rss or None,
        "exit": proc.returncode,
    }


def section_target(target: str) -> tuple[str, dict]:
    if not pathlib.Path(target).exists():
        return f"## 2. 실행 계측\n\n대상 없음: `{target}` -> 건너뜀\n", {}
    spans_file = tempfile.NamedTemporaryFile(suffix=".spans.json", delete=False)
    spans_file.close()
    env = dict(os.environ, PERF_SPANS_FILE=spans_file.name)
    m = _measure_child([sys.executable, target], env)
    rss = fmt_bytes(m["max_rss"]) if m["max_rss"] else "측정 불가 (psutil 설치 필요)"
    md = (
        f"## 2. 실행 계측: `{target}`\n\n"
        f"- 벽시계 **{fmt_time(m['wall'])}** · CPU {fmt_time(m['cpu'])}"
        f" · 최대 메모리 {rss} · exit={m['exit']}\n"
    )
    # span 구간 기록 회수
    spans_md = "\n## 3. 구간별 시간/메모리 (span)\n\n"
    spans_path = pathlib.Path(spans_file.name)
    try:
        if spans_path.stat().st_size > 0:
            spans = json.loads(spans_path.read_text(encoding="utf-8"))
            spans_md += "| 구간 | 시간 | 메모리 증가 |\n|---|---|---|\n"
            for s in spans:
                spans_md += (
                    f"| {s['name']} | {fmt_time(s['seconds'])}"
                    f" | {fmt_bytes(s['mem_bytes'], signed=True)} |\n"
                )
        else:
            spans_md += (
                '기록 없음 — 측정할 구간을 `with span("이름"):` 으로 감싸세요.\n'
            )
    finally:
        spans_path.unlink(missing_ok=True)
    return md + spans_md, m


def section_profile(target: str) -> str:
    if not pathlib.Path(target).exists():
        return ""
    prof = tempfile.NamedTemporaryFile(suffix=".prof", delete=False)
    prof.close()
    subprocess.run(
        [sys.executable, "-m", "cProfile", "-o", prof.name, target],
        capture_output=True,
    )
    prof_path = pathlib.Path(prof.name)
    try:
        if prof_path.stat().st_size == 0:
            return "\n## 4. 프로파일\n\ncProfile 결과 없음 -> 건너뜀\n"
        buf = io.StringIO()
        stats = pstats.Stats(prof.name, stream=buf)
        stats.strip_dirs().sort_stats("cumulative").print_stats(10)
        body = "\n".join(buf.getvalue().splitlines()[4:])
        return (
            "\n## 4. 프로파일 (cProfile 누적시간 상위 10)\n\n"
            "> 프로파일 실행은 계측 오버헤드로 §2보다 느립니다."
            " 상대 비교용으로만 보세요.\n\n"
            f"```\n{body}\n```\n"
        )
    finally:
        prof_path.unlink(missing_ok=True)


def section_bench(repeat: int) -> str:
    head = "\n## 5. 입력 변동 벤치마크 (TestCase.txt)\n\n"
    tests_path = pathlib.Path("tests/test_from_testcases.py")
    if not tests_path.exists():
        return head + "tests/test_from_testcases.py 없음 -> 건너뜀\n"
    spec = importlib.util.spec_from_file_location("_testcases", tests_path)
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception as e:  # 예: pytest 미설치
        return head + f"테스트 모듈 로드 실패 ({e}) -> 건너뜀\n"
    cases = mod._load_cases()
    if not cases:
        return head + "TestCase.txt 에 케이스 없음 -> 건너뜀\n"
    rows = []
    for func, fargs, _expected in cases:
        fn = vars(mod).get(func)
        label = f"{func}({', '.join(repr(a) for a in fargs)})"
        if not callable(fn):
            rows.append((label, "함수 없음", "-"))
            continue
        # 시간: 짧은 호출은 루프로 증폭해 측정 후 반복 중앙값
        t0 = time.perf_counter()
        fn(*fargs)
        t1 = time.perf_counter() - t0
        iters = 1 if t1 >= 1e-3 else max(1, min(10000, int(0.005 / max(t1, 1e-9))))
        samples = []
        for _ in range(repeat):
            s0 = time.perf_counter()
            for _ in range(iters):
                fn(*fargs)
            samples.append((time.perf_counter() - s0) / iters)
        median = statistics.median(samples)
        # 메모리: tracemalloc 1회 측정 (파이썬 객체 peak)
        tracemalloc.start()
        m0 = tracemalloc.get_traced_memory()[0]
        fn(*fargs)
        peak = tracemalloc.get_traced_memory()[1] - m0
        tracemalloc.stop()
        rows.append((label, fmt_time(median), fmt_bytes(peak, signed=True)))
    md = head + (
        f"각 {repeat}회 반복(증폭 루프 포함)의 중앙값. 메모리는 파이썬 객체 peak.\n\n"
        "| 입력 | 시간/호출 | peak 메모리 |\n|---|---|---|\n"
    )
    for label, t, m in rows:
        md += f"| `{label}` | {t} | {m} |\n"
    return md


# ---------- 메인 ----------


def _default_target() -> str:
    for cand in ("smoke_test.py", "main.py"):
        if pathlib.Path(cand).exists():
            return cand
    return "smoke_test.py"


def main() -> int:
    parser = argparse.ArgumentParser(description="실행 프로파일 보고서 생성")
    parser.add_argument("--target", default=None, help="계측할 스크립트")
    parser.add_argument("--repeat", type=int, default=5, help="벤치 반복 횟수")
    parser.add_argument("--no-pytest", action="store_true")
    parser.add_argument("--no-profile", action="store_true")
    parser.add_argument("--no-bench", action="store_true")
    opts = parser.parse_args()
    target = opts.target or _default_target()

    reports = pathlib.Path("reports")
    reports.mkdir(exist_ok=True)
    ts = datetime.datetime.now()
    name = pathlib.Path.cwd().name

    md = [f"# 실행 보고서 — {name} ({ts:%Y-%m-%d %H:%M:%S})\n"]
    summary: dict = {}

    if not opts.no_pytest:
        sec, tests = section_pytest()
        md.append(sec)
        summary.update(tests)
    sec, run = section_target(target)
    md.append(sec)
    summary.update(run)
    if not opts.no_profile:
        md.append(section_profile(target))
    if not opts.no_bench:
        md.append(section_bench(opts.repeat))
    md.append(
        "\n---\n측정 주의: tracemalloc은 파이썬 객체 할당만 계산합니다(C 확장 제외)."
        " 수치는 실행 환경 부하에 따라 변동하므로 추세 비교에 사용하세요.\n"
    )

    report_path = reports / f"{ts:%Y-%m-%d_%H%M%S}.md"
    report_path.write_text("\n".join(md), encoding="utf-8")

    history = reports / "history.csv"
    new_file = not history.exists()
    with history.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new_file:
            w.writerow(
                [
                    "timestamp",
                    "target",
                    "passed",
                    "failed",
                    "wall_s",
                    "cpu_s",
                    "max_rss_mb",
                ]
            )
        w.writerow(
            [
                f"{ts:%Y-%m-%d %H:%M:%S}",
                target,
                summary.get("passed", ""),
                summary.get("failed", ""),
                f"{summary.get('wall', 0):.3f}" if "wall" in summary else "",
                f"{summary.get('cpu', 0):.3f}" if "cpu" in summary else "",
                f"{summary['max_rss'] / 1048576:.1f}" if summary.get("max_rss") else "",
            ]
        )

    print(f"[OK] 보고서 생성: {report_path}")
    print(f"[OK] 추세 누적: {history}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
