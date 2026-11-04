#!/usr/bin/env python3
"""Inject measured benchmark tables into problem READMEs.

For each bench/results/<dir>.json, replaces the region between
`<!-- BENCH:<dir> -->` and `<!-- /BENCH -->` in problems/<dir>/README.md
(inserting the closing marker if it is missing). Idempotent.

    python scripts/render_bench.py            # all results
    python scripts/render_bench.py --check    # exit 1 if any README is out of date
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from harness.spec import BENCH_CLOSE, BENCH_OPEN_RE, bench_open  # noqa: E402

PHASE_TITLES = {"no_indexes": "Without indexes", "with_indexes": "With `indexes.sql`"}
NOISE_NOTE = ("GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, "
              "not the absolute times.")


def fmt_time(seconds: float) -> str:
    if seconds < 0.001:
        return f"{seconds * 1e6:.0f} µs"
    if seconds < 1:
        return f"{seconds * 1e3:.3g} ms"
    return f"{seconds:.3g} s"


def fmt_size(n: int) -> str:
    return f"{n:,}"


def cell(rec: dict | None) -> str:
    if rec is None:
        return "—"
    if rec["status"] == "ok":
        return fmt_time(rec["median_s"])
    if rec["status"] == "skipped":
        return f"{rec['display']} †"
    return rec.get("display", rec["status"])


def ratio(rec: dict | None, opt: dict | None, timeout_ms: int) -> str:
    if rec is None or opt is None or opt.get("status") != "ok" or opt["median_s"] <= 0:
        return "n/a"
    if rec["status"] == "ok":
        return f"{rec['median_s'] / opt['median_s']:.1f}×"
    if rec["status"] in ("timeout", "skipped"):
        return f"> {timeout_ms / 1000 / opt['median_s']:.0f}×"
    return "n/a"


def render_phase(result: dict, phase: str) -> list[str]:
    runs = {r["size"]: r for r in result["runs"] if r["phase"] == phase}
    sizes = [s for s in result["settings"]["sizes"] if s in runs]
    if not sizes:
        return []
    largest = sizes[-1]
    timeout_ms = result["settings"]["timeout_ms"]
    by_size = {s: {rec["solution"]: rec for rec in runs[s]["solutions"]} for s in sizes}
    optimal = result["optimal"]
    header = ["Solution"] + [f"{fmt_size(s)} rows" for s in sizes] + [f"× slower than optimal @ {fmt_size(largest)}"]
    lines = [f"**{PHASE_TITLES.get(phase, phase)}**", "",
             "| " + " | ".join(header) + " |",
             "|" + "|".join(["---"] + ["---:"] * (len(header) - 1)) + "|"]
    any_skipped = any_faster = False
    for sol in result["solutions"]:
        cells = []
        for s in sizes:
            rec = by_size[s].get(sol)
            any_skipped |= bool(rec and rec["status"] == "skipped")
            cells.append(cell(rec))
        r = ratio(by_size[largest].get(sol), by_size[largest].get(optimal), timeout_ms)
        any_faster |= r.endswith("×") and not r.startswith(">") and float(r[:-1]) < 1.0
        name = f"`{sol}`" + (" (optimal)" if sol == optimal else "")
        lines.append("| " + " | ".join([name] + cells + [r]) + " |")
    if any_skipped:
        lines += ["", "† not run at this size: it already timed out at a smaller size."]
    if any_faster:
        lines += ["", "A ratio below 1.0× means that approach was faster than the one labelled optimal here."]
    if not all(runs[s].get("results_agree", True) for s in sizes):
        lines += ["", "**Warning:** solutions returned different results in this benchmark run."]
    return lines


def render_table(result: dict) -> str:
    st, m = result["settings"], result.get("machine", {})
    mysql = (m.get("mysql") or {}).get("version", "?")
    cpu = m.get("cpu_model", "unknown CPU")
    out = [f"_Measured {result['generated_at'][:10]} by the bench workflow: MySQL {mysql}, {cpu}, "
           f"{m.get('cpu_count', '?')} vCPU. Median of {st['timed_runs']} runs after {st['warmup_runs']} warm-up; "
           f"each statement capped at {st['timeout_ms'] // 1000} s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: "
           f"`bench/results/{result['problem']}.json`._", ""]
    for phase in st.get("phases", ["no_indexes"]):
        block = render_phase(result, phase)
        if block:
            out += block + [""]
    out.append(f"> {NOISE_NOTE}")
    return "\n".join(out)


def inject(readme: str, problem_dir: str, table: str) -> str:
    """Replace every BENCH region for `problem_dir`; add the closing marker where missing."""
    opener = bench_open(problem_dir)
    out, pos = [], 0
    while True:
        i = readme.find(opener, pos)
        if i == -1:
            out.append(readme[pos:])
            break
        j = i + len(opener)
        out.append(readme[pos:j])
        close = readme.find(BENCH_CLOSE, j)
        nxt = BENCH_OPEN_RE.search(readme, j)
        if close != -1 and (nxt is None or close < nxt.start()):
            pos = close + len(BENCH_CLOSE)
        else:  # no closing marker for this region: insert one, keep what follows
            pos = j
        out.append("\n" + table + "\n" + BENCH_CLOSE)
    return "".join(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", type=Path, default=REPO / "bench" / "results")
    ap.add_argument("--problems", type=Path, default=REPO / "problems")
    ap.add_argument("--check", action="store_true", help="do not write; exit 1 if anything would change")
    args = ap.parse_args(argv)

    stale = []
    for path in sorted(args.results.glob("*.json")):
        result = json.loads(path.read_text(encoding="utf-8"))
        readme = args.problems / result["problem"] / "README.md"
        if not readme.exists():
            print(f"skip {path.name}: {readme} does not exist")
            continue
        text = readme.read_text(encoding="utf-8")
        if bench_open(result["problem"]) not in text:
            print(f"warning: {readme} has no {bench_open(result['problem'])} marker")
            continue
        new = inject(text, result["problem"], render_table(result))
        if new != text:
            stale.append(readme)
            if not args.check:
                readme.write_text(new, encoding="utf-8")
                print(f"updated {readme.relative_to(args.problems.parent) if readme.is_relative_to(args.problems.parent) else readme}")
    if args.check and stale:
        print("out of date:", *map(str, stale), sep="\n  ")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
