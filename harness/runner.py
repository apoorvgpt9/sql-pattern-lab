"""Shared test procedures (used by the reference tests and by --mine)."""
from __future__ import annotations

from collections import Counter
from pathlib import Path

from . import db
from .compare import (compare_results, display_row, multiset_diff, normalize_row,
                      read_expected)
from .discovery import Problem

DIFF_SEEDS = range(1, 6)
DIFF_ROWS = 300
# Input sizes tried, smallest first, when shrinking a differential failure.
SHRINK_SIZES = (3, 5, 8, 12, 20, 35, 60, 100, 200)
SHRINK_SEEDS = range(1, 11)


def check_edge(problem: Problem, edge: str, solution: Path) -> None:
    """Fresh DB -> schema.sql -> tests/<edge>.sql -> solution -> compare to expected/<edge>.csv."""
    exp_cols, exp_rows = read_expected(problem.expected_csv(edge))
    with db.fresh_database() as conn:
        db.run_file(conn, problem.schema_sql)
        db.run_file(conn, problem.edge_sql(edge))
        result = db.run_solution(conn, solution)
    problem_txt = compare_results(result.columns, result.rows, exp_cols, exp_rows,
                                  exact_order=problem.exact_order)
    if problem_txt:
        order = "exact order" if problem.exact_order else "any order"
        raise AssertionError(f"{problem.name} {edge} with {solution.name} ({order}):\n{problem_txt}")


def run_on_generated(problem: Problem, solutions: list[Path], n_rows: int, seed: int):
    """Load gen.py data once, run every solution; return ({solution: rows}, columns, input data)."""
    data = {t: list(rows) for t, rows in problem.generate(n_rows=n_rows, seed=seed).items()}
    results, columns = {}, {}
    with db.fresh_database() as conn:
        db.run_file(conn, problem.schema_sql)
        db.load_generated(conn, data)
        for sol in solutions:
            res = db.run_solution(conn, sol)
            results[sol.stem] = [normalize_row(r) for r in res.rows]
            columns[sol.stem] = [c.lower() for c in res.columns]
    return results, columns, data


def _groups(results: dict[str, list]) -> list[list[str]]:
    by_value: dict[tuple, list[str]] = {}
    for name, rows in results.items():
        key = tuple(sorted(Counter(rows).items(), key=repr))
        by_value.setdefault(key, []).append(name)
    return list(by_value.values())


def _reference_group(groups: list[list[str]], reference: str) -> list[str]:
    """Majority result; ties go to the group holding the reference (optimal) solution."""
    return max(groups, key=lambda g: (len(g), reference in g))


def _diverges(results, columns) -> bool:
    return len(_groups(results)) > 1 or len({tuple(c) for c in columns.values()}) > 1


def _describe(results, columns, reference: str, limit: int = 10) -> str:
    lines = []
    col_sets = {tuple(c) for c in columns.values()}
    if len(col_sets) > 1:
        lines.append("column names differ: " + "; ".join(f"{k}={v}" for k, v in columns.items()))
    groups = _groups(results)
    ref = _reference_group(groups, reference)
    ref_rows = results[ref[0]]
    lines.append(f"agree ({len(ref_rows)} rows): {', '.join(ref)}")
    for g in groups:
        if g is ref:
            continue
        rows = results[g[0]]
        only_g, only_ref = multiset_diff(rows, ref_rows)
        lines.append(f"DIVERGED ({len(rows)} rows): {', '.join(g)}")
        if only_g:
            lines.append(f"  rows only in {g[0]} ({len(only_g)}):")
            lines += ["    " + display_row(r) for r in only_g[:limit]]
        if only_ref:
            lines.append(f"  rows only in {ref[0]} ({len(only_ref)}):")
            lines += ["    " + display_row(r) for r in only_ref[:limit]]
    return "\n".join(lines)


def _format_input(data: dict[str, list]) -> str:
    lines = []
    for table, rows in data.items():
        lines.append(f"  {table} ({len(rows)} rows):")
        lines += [f"    {r!r}" for r in rows]
    return "\n".join(lines)


def shrink(problem: Problem, solutions: list[Path]) -> str:
    """Find the smallest generated input that still shows the divergence."""
    for n in SHRINK_SIZES:
        for seed in SHRINK_SEEDS:
            results, columns, data = run_on_generated(problem, solutions, n, seed)
            if _diverges(results, columns):
                total = sum(len(r) for r in data.values())
                body = _format_input(data) if total <= 80 else f"  ({total} input rows; too many to print)"
                return (f"smallest reproduction found: generate(n_rows={n}, seed={seed})\n{body}\n"
                        + _describe(results, columns, solutions[-1].stem))
    return "could not reproduce with a smaller input"


def check_differential(problem: Problem, solutions: list[Path], reference: str) -> None:
    """All `solutions` must return the same multiset on gen.py data for every seed."""
    any_rows = False
    for seed in DIFF_SEEDS:
        results, columns, _ = run_on_generated(problem, solutions, DIFF_ROWS, seed)
        any_rows = any_rows or any(results.values())
        if _diverges(results, columns):
            raise AssertionError(
                f"{problem.name}: results differ on generate(n_rows={DIFF_ROWS}, seed={seed})\n"
                + _describe(results, columns, reference) + "\n\n" + shrink(problem, solutions))
    if not any_rows:
        raise AssertionError(
            f"{problem.name}: every solution returned 0 rows for every seed - gen.py does not exercise "
            f"the logic, so the differential test proves nothing")
