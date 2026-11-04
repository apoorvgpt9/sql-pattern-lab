"""Benchmark every solution of selected problems at several data sizes.

    python -m harness.bench --problems '01-*' --sizes 1000,100000,1000000
    python -m harness.bench --batch B1

For each problem and size: load gen.py data with LOAD DATA LOCAL INFILE, then for
each solution take 1 warm-up run and 3 timed runs (median reported), plus
EXPLAIN ANALYZE of the final statement. Done first without indexes, then again
after indexes.sql (if the problem has one). Statements are capped at 60 s; a
timeout is recorded as a result, and a solution that timed out is not re-run at
larger sizes in the same phase.

Writes bench/results/<problem_dir>.json. The server must allow local_infile
(the script tries SET GLOBAL local_infile=1 itself).
"""
from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import json
import os
import platform
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from decimal import Decimal
from pathlib import Path

import pymysql
import pymysql.cursors

from . import db
from .compare import result_digest
from .config import BENCH_RESULTS_DIR, REPO_ROOT, SQL_MODE, MySQLConfig
from .discovery import Problem, solved_problems
from .sqlsplit import split_statements, strip_comments

DEFAULT_SIZES = (1000, 100000, 1000000)
TIMEOUT_MS = 60000
TIMEOUT_LABEL = "timeout >60s"
EXPLAIN_MAX_CHARS = 20000
# MySQL errors meaning "stopped by max_execution_time / KILL QUERY".
TIMEOUT_ERRNOS = {3024, 1317, 1028}


# ---------------------------------------------------------------- data loading

def _tsv_cell(v) -> str:
    """MySQL LOAD DATA default format: tab-separated, backslash escapes, \\N for NULL."""
    if v is None:
        return r"\N"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (dt.datetime, dt.date, dt.time, int, Decimal)):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, (bytes, bytearray)):
        v = v.decode("utf-8")
    return str(v).replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")


def load_with_infile(conn, data: dict, tmpdir: Path) -> dict[str, int]:
    """Stream each table to a TSV file, then LOAD DATA LOCAL INFILE it."""
    counts = {}
    with conn.cursor() as cur:
        cur.execute("SET SESSION unique_checks = 0")
        cur.execute("SET SESSION foreign_key_checks = 0")
        for table, rows in data.items():
            cols = db.table_columns(conn, table)
            path = tmpdir / f"{table}.tsv"
            n = 0
            with path.open("w", encoding="utf-8", newline="\n") as fh:
                for row in rows:
                    if len(row) != len(cols):
                        raise ValueError(f"gen.py row for {table} has {len(row)} values, expected {len(cols)}")
                    fh.write("\t".join(_tsv_cell(v) for v in row))
                    fh.write("\n")
                    n += 1
            col_sql = ", ".join(f"`{c}`" for c in cols)
            cur.execute(
                f"LOAD DATA LOCAL INFILE %s INTO TABLE `{table}` CHARACTER SET utf8mb4 "
                f"FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n' ({col_sql})",
                (str(path),),
            )
            cur.execute("SHOW COUNT(*) WARNINGS")
            warnings = cur.fetchone()[0]
            cur.execute(f"SELECT COUNT(*) FROM `{table}`")
            loaded = cur.fetchone()[0]
            if loaded != n or warnings:
                cur.execute("SHOW WARNINGS LIMIT 5")
                sample = cur.fetchall()
                raise RuntimeError(f"LOAD DATA into {table}: wrote {n} rows, loaded {loaded}, "
                                   f"{warnings} warnings, e.g. {sample}")
            counts[table] = n
            path.unlink()
        cur.execute("SET SESSION unique_checks = 1")
        cur.execute("SET SESSION foreign_key_checks = 1")
        for table in counts:
            cur.execute(f"ANALYZE TABLE `{table}`")
            cur.fetchall()
    return counts


def ensure_local_infile(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("SELECT @@GLOBAL.local_infile")
        if cur.fetchone()[0]:
            return
        try:
            cur.execute("SET GLOBAL local_infile = 1")
        except pymysql.err.MySQLError as exc:
            raise SystemExit(f"server has local_infile=OFF and it cannot be enabled ({exc}); "
                             f"start mysqld with --local-infile=1") from exc


# ---------------------------------------------------------------- timing

class Timeout(Exception):
    pass


def _killer(conn_id: int, delay_s: float) -> threading.Timer:
    """Backstop for statements max_execution_time does not cover (non-SELECT, multi-statement)."""
    def kill():
        try:
            k = db.connect()
            with k.cursor() as cur:
                cur.execute(f"KILL QUERY {int(conn_id)}")
            k.close()
        except pymysql.err.MySQLError:
            pass
    t = threading.Timer(delay_s, kill)
    t.daemon = True
    return t


def execute_timed(conn, statements: list[str], timeout_ms: int) -> tuple[float, list]:
    """Run statements; return (wall seconds, rows of the last result set). Raises Timeout."""
    rows: list = []
    timer = _killer(conn.thread_id(), timeout_ms / 1000 + 5)
    start = time.perf_counter()
    timer.start()
    try:
        cur = conn.cursor(pymysql.cursors.SSCursor)
        for stmt in statements:
            cur.execute(stmt)
            if cur.description is not None:
                rows = []
                while True:
                    chunk = cur.fetchmany(10000)
                    if not chunk:
                        break
                    rows.extend(chunk)
        cur.close()
    except pymysql.err.MySQLError as exc:
        if exc.args and exc.args[0] in TIMEOUT_ERRNOS:
            raise Timeout() from exc
        raise
    finally:
        timer.cancel()
    elapsed = time.perf_counter() - start
    if elapsed * 1000 > timeout_ms:
        raise Timeout()
    return elapsed, rows


def explain_analyze(conn, statements: list[str], timeout_ms: int) -> str | None:
    last = statements[-1]
    code = strip_comments(last).lstrip()
    head = code[:6].upper()
    if not (head.startswith("SELECT") or head.startswith("WITH") or head.startswith("(")):
        return None
    try:
        _, rows = execute_timed(conn, statements[:-1] + ["EXPLAIN ANALYZE " + last], timeout_ms)
    except Timeout:
        reset_session(conn, timeout_ms)
        return "EXPLAIN ANALYZE timed out"
    except pymysql.err.MySQLError as exc:
        reset_session(conn, timeout_ms)
        return f"EXPLAIN ANALYZE failed: {exc}"
    text = "\n".join(str(r[0]) for r in rows)
    return text if len(text) <= EXPLAIN_MAX_CHARS else text[:EXPLAIN_MAX_CHARS] + "\n... (truncated)"


def reset_session(conn, timeout_ms: int) -> None:
    """After an interrupted statement, make sure the connection and its session settings are usable."""
    conn.ping(reconnect=True)
    with conn.cursor() as cur:
        cur.execute("SET SESSION sql_mode = %s", (SQL_MODE,))
        cur.execute("SET SESSION time_zone = '+00:00'")
        cur.execute(f"SET SESSION max_execution_time = {int(timeout_ms)}")


def bench_solution(conn, sol: Path, repeats: int, timeout_ms: int) -> dict:
    statements = split_statements(sol.read_text(encoding="utf-8"))
    rec: dict = {"solution": sol.stem}
    try:
        _, rows = execute_timed(conn, statements, timeout_ms)  # warm-up
        times = []
        for _ in range(repeats):
            t, rows = execute_timed(conn, statements, timeout_ms)
            times.append(t)
    except Timeout:
        reset_session(conn, timeout_ms)
        rec.update(status="timeout", display=TIMEOUT_LABEL)
        return rec
    except pymysql.err.MySQLError as exc:
        reset_session(conn, timeout_ms)
        rec.update(status="error", display="error", error=str(exc))
        return rec
    rec.update(status="ok", median_s=statistics.median(times), times_s=times,
               result_rows=len(rows), result_digest=result_digest(rows),
               explain_analyze=explain_analyze(conn, statements, timeout_ms))
    return rec


# ---------------------------------------------------------------- driver

def machine_info(conn) -> dict:
    info = {
        "platform": platform.platform(),
        "python": platform.python_version(),
        "pymysql": pymysql.__version__,
        "cpu_count": os.cpu_count(),
    }
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                info["cpu_model"] = line.split(":", 1)[1].strip()
                break
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal"):
                info["mem_total"] = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    with conn.cursor() as cur:
        cur.execute("SELECT VERSION(), @@innodb_buffer_pool_size, @@join_buffer_size, @@tmp_table_size")
        v, bp, jb, tt = cur.fetchone()
    info["mysql"] = {"version": v, "innodb_buffer_pool_size": int(bp), "join_buffer_size": int(jb),
                     "tmp_table_size": int(tt)}
    for k in ("RUNNER_OS", "RUNNER_ARCH", "ImageOS", "ImageVersion", "GITHUB_RUN_ID", "GITHUB_SHA"):
        if os.environ.get(k):
            info.setdefault("github", {})[k] = os.environ[k]
    try:
        info["git_sha"] = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, capture_output=True,
                                         text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        pass
    return info


def bench_problem(problem: Problem, sizes: list[int], repeats: int, timeout_ms: int, log) -> dict:
    solutions = problem.solutions()
    phases = ["no_indexes"] + (["with_indexes"] if problem.indexes_sql else [])
    runs = []
    timed_out: dict[tuple[str, str], int] = {}  # (phase, solution) -> size that timed out
    with db.fresh_database("spl_bench", local_infile=True) as conn:
        machine = machine_info(conn)
        for size in sizes:
            with conn.cursor() as cur:
                for t in db.table_row_counts(conn):
                    cur.execute(f"DROP TABLE `{t}`")
            db.run_file(conn, problem.schema_sql)
            t0 = time.perf_counter()
            with tempfile.TemporaryDirectory(prefix="spl_bench_") as tmp:
                counts = load_with_infile(conn, problem.generate(n_rows=size, seed=1), Path(tmp))
            load_s = time.perf_counter() - t0
            log(f"  size {size:>9,}: loaded {counts} in {load_s:.1f}s")
            for phase in phases:
                if phase == "with_indexes":
                    db.run_file(conn, problem.indexes_sql)
                    with conn.cursor() as cur:
                        for t in counts:
                            cur.execute(f"ANALYZE TABLE `{t}`")
                            cur.fetchall()
                with conn.cursor() as cur:
                    cur.execute(f"SET SESSION max_execution_time = {int(timeout_ms)}")
                recs = []
                for sol in solutions:
                    key = (phase, sol.stem)
                    if key in timed_out:
                        rec = {"solution": sol.stem, "status": "skipped", "display": TIMEOUT_LABEL,
                               "reason": f"timed out at size {timed_out[key]}"}
                    else:
                        rec = bench_solution(conn, sol, repeats, timeout_ms)
                        if rec["status"] == "timeout":
                            timed_out[key] = size
                    shown = f"{rec['median_s']:.4f}s" if rec["status"] == "ok" else rec["display"]
                    log(f"    {phase:<12} {sol.stem:<32} {shown}")
                    recs.append(rec)
                digests = {r["result_digest"] for r in recs if r["status"] == "ok"}
                runs.append({"size": size, "phase": phase, "rows_loaded": counts,
                             "load_seconds": round(load_s, 3), "results_agree": len(digests) <= 1,
                             "solutions": recs})
                if len(digests) > 1:
                    log(f"    WARNING: solutions returned different results at size {size} ({phase})")
    return {
        "problem": problem.name,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "settings": {"sizes": sizes, "warmup_runs": 1, "timed_runs": repeats, "statistic": "median",
                     "timeout_ms": timeout_ms, "gen_seed": 1, "phases": phases},
        "solutions": [s.stem for s in solutions],
        "optimal": problem.optimal.stem,
        "machine": machine,
        "runs": runs,
    }


def select_problems(pattern: str, batch: str | None) -> list[Problem]:
    out = []
    for p in solved_problems():
        if not fnmatch.fnmatch(p.name, pattern):
            continue
        if batch and str(p.meta.get("batch")) != batch:
            continue
        out.append(p)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m harness.bench", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--problems", default="*", help="glob over problem folder names (default: all)")
    ap.add_argument("--batch", help="only problems whose meta.yaml batch equals this, e.g. B1")
    ap.add_argument("--sizes", default=",".join(map(str, DEFAULT_SIZES)), help="comma-separated n_rows values")
    ap.add_argument("--repeats", type=int, default=3, help="timed runs per solution (median reported)")
    ap.add_argument("--timeout-ms", type=int, default=TIMEOUT_MS)
    ap.add_argument("--out", type=Path, default=BENCH_RESULTS_DIR)
    args = ap.parse_args(argv)

    sizes = [int(s.replace("_", "")) for s in args.sizes.split(",") if s.strip()]
    problems = select_problems(args.problems, args.batch)
    log = lambda msg: print(msg, flush=True)  # noqa: E731
    if not problems:
        log(f"no solved problems match --problems {args.problems!r} --batch {args.batch!r}; nothing to bench")
        return 0
    version = db.wait_for_server()
    log(f"MySQL {version} at {MySQLConfig.from_env().describe()}")
    conn = db.connect()
    ensure_local_infile(conn)
    conn.close()
    args.out.mkdir(parents=True, exist_ok=True)
    failed = []
    for p in problems:
        log(f"{p.name}: sizes {sizes}, solutions {[s.stem for s in p.solutions()]}")
        try:
            result = bench_problem(p, sizes, args.repeats, args.timeout_ms, log)
        except Exception as exc:  # keep going; other problems' results are still useful
            log(f"  FAILED: {exc}")
            failed.append(p.name)
            continue
        out = args.out / f"{p.name}.json"
        out.write_text(json.dumps(result, indent=2, default=str) + "\n", encoding="utf-8")
        log(f"  wrote {out.relative_to(REPO_ROOT) if out.is_relative_to(REPO_ROOT) else out}")
    if failed:
        log(f"benchmark failed for: {failed}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
