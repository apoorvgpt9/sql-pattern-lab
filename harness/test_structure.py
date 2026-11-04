"""Static checks that every problem folder follows CLAUDE.md. No database needed.

Runs for every problems/<dir>/ with a meta.yaml, so a half-built problem fails CI
until it is complete.
"""
import json

import pytest
import yaml

from harness.compare import read_expected
from harness.config import BENCH_RESULTS_DIR
from harness.discovery import load_problems_yaml
from harness.sqlsplit import is_blank
from harness.spec import (ASSUMPTIONS_SECTION, BENCH_CLOSE, EXPECT_EMPTY_RE, EXPECT_RE, HINT_COUNT,
                          HINT_RE, MIN_EDGE_DATASETS, MIN_SOLUTIONS, README_SECTIONS, bench_open,
                          problem_dir_name, readme_h2)

ENTRIES = {e["id"]: e for e in load_problems_yaml()}


def _readme(p):
    path = p.path / "README.md"
    assert path.exists(), f"{p.name}: README.md missing"
    return path.read_text(encoding="utf-8")


def test_meta_matches_problems_yaml(any_problem):
    entry = ENTRIES.get(any_problem.meta.get("id"))
    assert entry is not None, f"{any_problem.name}: meta.yaml id not in problems.yaml"
    assert any_problem.meta == entry, f"{any_problem.name}: meta.yaml must be an exact copy of its problems.yaml entry"
    assert any_problem.name == problem_dir_name(entry), \
        f"folder should be named {problem_dir_name(entry)} (scripts/new_problem.py {entry['id']})"


def test_required_files(any_problem):
    p = any_problem.path
    for f in ("schema.sql", "gen.py", "snowflake.sql", "my_answer.sql", "README.md"):
        assert (p / f).exists(), f"{any_problem.name}: {f} missing"
    assert not is_blank((p / "schema.sql").read_text(encoding="utf-8")), \
        f"{any_problem.name}: schema.sql has no executable statements (the draft is commented out)"
    head = "\n".join((p / "snowflake.sql").read_text(encoding="utf-8").splitlines()[:5])
    assert "UNVERIFIED" in head, f"{any_problem.name}: snowflake.sql must say UNVERIFIED in its first lines"
    assert len(any_problem.solutions()) >= MIN_SOLUTIONS, \
        f"{any_problem.name}: needs >= {MIN_SOLUTIONS} solutions/*.sql"


def test_edge_datasets_and_expected(any_problem):
    edges = any_problem.edge_datasets()
    assert len(edges) >= MIN_EDGE_DATASETS, f"{any_problem.name}: needs >= {MIN_EDGE_DATASETS} tests/edge_*.sql"
    csvs = sorted(p.stem for p in (any_problem.path / "expected").glob("edge_*.csv"))
    assert csvs == edges, f"{any_problem.name}: tests/ and expected/ do not pair up: {edges} vs {csvs}"
    for edge in edges:
        header, rows = read_expected(any_problem.expected_csv(edge))
        assert [h.lower() for h in header] == [c.lower() for c in any_problem.output_columns], \
            f"{edge}.csv header {header} != meta output.columns {any_problem.output_columns}"
        sql = any_problem.edge_sql(edge).read_text(encoding="utf-8")
        n_expect = len(EXPECT_RE.findall(sql))
        if rows:
            assert n_expect == len(rows), (
                f"{edge}.sql needs one '-- expect: <row> | <reason>' comment per expected row "
                f"({len(rows)} rows, {n_expect} comments)")
        else:
            assert EXPECT_EMPTY_RE.search(sql) and n_expect == 0, \
                f"{edge}.sql expects no rows: explain why with one '-- expect-empty: <reason>' comment"


def test_readme_sections(any_problem):
    text = _readme(any_problem)
    heads = readme_h2(text)
    needs_assumptions = any_problem.meta.get("confidence") != "high"
    expected = list(README_SECTIONS)
    if needs_assumptions or ASSUMPTIONS_SECTION in heads:
        expected.insert(2, ASSUMPTIONS_SECTION)
    assert heads == expected, (
        f"{any_problem.name}: README level-2 headings must be exactly, in order:\n  {expected}\n"
        f"got:\n  {heads}" + ("\n(confidence is not high, so Assumptions is required)" if needs_assumptions else ""))
    assert "TODO" not in text, f"{any_problem.name}: README still contains TODO placeholders"
    hints = [int(n) for n in HINT_RE.findall(text)]
    assert hints == list(range(1, HINT_COUNT + 1)), f"{any_problem.name}: need exactly Hint 1..3 in <details>, got {hints}"


def test_readme_source_and_license(any_problem):
    text = _readme(any_problem)
    meta = any_problem.meta
    first_section = text.split("\n## ", 2)[1] if "\n## " in text else ""
    if meta.get("url"):
        assert meta["url"] in first_section, f"{any_problem.name}: section 1 must link to {meta['url']}"
    if meta.get("source") == "pgexercises":
        lic = any_problem.path / "LICENSE.md"
        assert lic.exists(), f"{any_problem.name}: pgexercises problems need LICENSE.md"
        lic_text = lic.read_text(encoding="utf-8")
        assert "CC BY-SA 3.0" in lic_text and meta["attribution"] in lic_text
        assert meta["attribution"] in first_section, f"{any_problem.name}: section 1 must repeat the attribution"


def test_bench_marker_untouched_without_results(any_problem):
    """Rule 3: no hand-written numbers inside the bench region."""
    text = _readme(any_problem)
    marker = bench_open(any_problem.name)
    assert marker in text, f"{any_problem.name}: README needs the placeholder {marker}"
    if (BENCH_RESULTS_DIR / f"{any_problem.name}.json").exists():
        return
    after = text.split(marker, 1)[1]
    if BENCH_CLOSE in after:
        region = after.split(BENCH_CLOSE, 1)[0]
        assert not region.strip(), (
            f"{any_problem.name}: the BENCH region must stay empty until bench/results/{any_problem.name}.json exists")


def test_gen_contract(any_problem):
    data = any_problem.generate(n_rows=50, seed=1)
    again = any_problem.generate(n_rows=50, seed=1)
    as_lists = {t: list(r) for t, r in data.items()}
    assert as_lists == {t: list(r) for t, r in again.items()}, "generate() must be deterministic for a seed"
    assert any(as_lists.values()), "generate(50, 1) produced no rows"


def test_problems_yaml_is_consistent():
    entries = load_problems_yaml()
    ids = [e["id"] for e in entries]
    assert ids == sorted(set(ids)), "problems.yaml ids must be unique and ascending"
    dirs = [problem_dir_name(e) for e in entries]
    assert len(dirs) == len(set(dirs)), "two problems map to the same folder name"
    for e in entries:
        assert e.get("batch"), f"id {e['id']} has no batch"
        assert (e.get("output") or {}).get("columns"), f"id {e['id']} has no output.columns"
        json.dumps(e, default=str)  # serialisable for the app build
        yaml.safe_dump(e)
