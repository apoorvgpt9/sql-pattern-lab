"""Unit tests for the harness itself. No database needed."""
import datetime as dt
import importlib.util
import json
from decimal import Decimal

import pytest
import yaml

from harness.compare import compare_results, normalize, read_expected
from harness.config import REPO_ROOT
from harness.discovery import load_problems_yaml, ordering_is_exact
from harness.spec import README_SECTIONS, problem_dir_name, readme_h2
from harness.sqlsplit import is_blank, split_statements, strip_comments


def _script(name):
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / "scripts" / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------- sqlsplit

def test_split_handles_strings_and_comments():
    sql = """
    -- leading comment; with semicolon
    INSERT INTO t VALUES ('a;b', "c;d", 'it''s', 'x\\';y');  # trailing; comment
    /* block ; comment */ SELECT `we;ird` FROM t;
    SELECT 1--1
    ;
    -- only a comment;
    """
    stmts = split_statements(sql)
    assert len(stmts) == 3
    assert stmts[0].startswith("-- leading") and "'x\\';y'" in stmts[0]
    assert "`we;ird`" in stmts[1]
    assert stmts[2].endswith("SELECT 1--1")  # '--1' is not a comment in MySQL


def test_blank_and_strip():
    assert is_blank("-- nothing\n/* here */\n# at all\n")
    assert not is_blank("-- c\nSELECT 1")
    assert strip_comments("SELECT 1 -- x\n").strip() == "SELECT 1"


# ---------------------------------------------------------------- compare

@pytest.mark.parametrize("a,b", [
    (1, "1"), (Decimal("2.50"), "2.5"), (2.0000001, "2"), (0.1 + 0.2, "0.3"),
    (Decimal("-0.000001"), "0"), (dt.date(2019, 1, 1), "2019-01-01"),
    (dt.datetime(2019, 1, 1, 10, 0), "2019-01-01T10:00:00"), (dt.timedelta(hours=1, minutes=2), "01:02:00"),
    (None, None),
])
def test_normalize_equal(a, b):
    assert normalize(a) == normalize(b)


@pytest.mark.parametrize("a,b", [(1, "1.0001"), ("", None), ("abc", "ABC"), (0, None), ("a", "a ")])
def test_normalize_different(a, b):
    assert normalize(a) != normalize(b)


def test_read_expected_null_and_empty(tmp_path):
    p = tmp_path / "e.csv"
    p.write_text('a,b,c\nNULL,,"x,y"\n\n', encoding="utf-8")
    header, rows = read_expected(p)
    assert header == ["a", "b", "c"] and rows == [(None, "", "x,y")]


def test_compare_multiset_vs_exact():
    cols = ["ID", "v"]
    act = [(2, "b"), (1, "a"), (1, "a")]
    assert compare_results(cols, act, ["id", "V"], [("1", "a"), ("1", "a"), ("2", "b")], exact_order=False) is None
    assert "wrong order" in compare_results(cols, act, ["id", "v"], [("1", "a"), ("1", "a"), ("2", "b")],
                                            exact_order=True)
    assert "missing" in compare_results(cols, act[:2], ["id", "v"], act, exact_order=False)  # duplicates count
    assert "column names" in compare_results(["x", "v"], act, ["id", "v"], act, exact_order=False)


@pytest.mark.parametrize("text,exact", [
    ("any order", False), ("single row", False), ("Any", False), (None, False),
    ("customer_id ascending", True), ("streak_length DESC, user_id ASC", True),
])
def test_ordering_is_exact(text, exact):
    assert ordering_is_exact(text) is exact


def test_every_ordering_in_problems_yaml_is_classified():
    """Guards against a new free-text ordering being misread; extend _UNORDERED if this fails."""
    seen = {e["output"]["ordering"] for e in load_problems_yaml()}
    unordered = {o for o in seen if not ordering_is_exact(o)}
    assert unordered == {"any order", "single row"}, unordered


# ---------------------------------------------------------------- new_problem

def test_new_problem_scaffolds_every_entry(tmp_path):
    np = _script("new_problem")
    for entry in load_problems_yaml():
        base, created = np.scaffold(entry, tmp_path)
        assert base.name == problem_dir_name(entry)
        assert yaml.safe_load((base / "meta.yaml").read_text(encoding="utf-8")) == entry
        readme = (base / "README.md").read_text(encoding="utf-8")
        heads = [h for h in readme_h2(readme) if h != "Assumptions"]
        assert heads == README_SECTIONS
        assert ("Assumptions" in readme_h2(readme)) == (entry["confidence"] != "high")
        assert f"<!-- BENCH:{base.name} -->" in readme and "<!-- /BENCH -->" in readme
        assert is_blank((base / "my_answer.sql").read_text(encoding="utf-8"))
        assert is_blank((base / "schema.sql").read_text(encoding="utf-8"))  # draft stays commented out
        assert not list((base / "solutions").glob("*.sql"))
        if entry["source"] == "pgexercises":
            assert entry["attribution"] in (base / "LICENSE.md").read_text(encoding="utf-8")
            assert entry["attribution"] in readme.split("\n## ")[1]
        if entry.get("url"):
            assert entry["url"] in readme.split("\n## ")[1]
    # re-running never overwrites
    _, created = np.scaffold(load_problems_yaml()[0], tmp_path)
    assert created == []


# ---------------------------------------------------------------- render_bench

def _fake_result(problem="99-x"):
    def rec(sol, status, t=None):
        r = {"solution": sol, "status": status}
        if status == "ok":
            r["median_s"] = t
        else:
            r["display"] = "timeout >60s"
        return r
    return {
        "problem": problem, "generated_at": "2026-01-01T00:00:00+00:00", "optimal": "03_b",
        "solutions": ["01_a", "03_b"],
        "settings": {"sizes": [1000, 100000], "timed_runs": 3, "warmup_runs": 1, "timeout_ms": 60000,
                     "phases": ["no_indexes"]},
        "machine": {"cpu_model": "cpu", "cpu_count": 2, "mysql": {"version": "8.0.40"}},
        "runs": [
            {"size": 1000, "phase": "no_indexes", "solutions": [rec("01_a", "ok", 0.5), rec("03_b", "ok", 0.01)]},
            {"size": 100000, "phase": "no_indexes", "solutions": [rec("01_a", "timeout"), rec("03_b", "ok", 0.2)]},
        ],
    }


def test_render_bench_inject_and_idempotent(tmp_path):
    rb = _script("render_bench")
    table = rb.render_table(_fake_result())
    assert "| `01_a` | 500 ms | timeout >60s | > 300× |" in table
    assert "| `03_b` (optimal) | 10 ms | 200 ms | 1.0× |" in table
    assert "noisy" in table and "ratios" in table

    missing_close = "# R\n\nbefore\n<!-- BENCH:99-x -->\n\nafter\n"
    out = rb.inject(missing_close, "99-x", "TABLE")
    assert out == "# R\n\nbefore\n<!-- BENCH:99-x -->\nTABLE\n<!-- /BENCH -->\n\nafter\n"
    assert rb.inject(out, "99-x", "TABLE") == out
    assert rb.inject(out, "99-x", "NEW").count("NEW") == 1 and "TABLE" not in rb.inject(out, "99-x", "NEW")
    # a closing marker after a *different* opener does not belong to this region
    other = "<!-- BENCH:99-x -->\nx\n<!-- BENCH:98-y -->\n<!-- /BENCH -->"
    assert rb.inject(other, "99-x", "T") == "<!-- BENCH:99-x -->\nT\n<!-- /BENCH -->\nx\n<!-- BENCH:98-y -->\n<!-- /BENCH -->"

    results, problems = tmp_path / "results", tmp_path / "problems"
    (problems / "99-x").mkdir(parents=True)
    results.mkdir()
    (problems / "99-x" / "README.md").write_text(missing_close, encoding="utf-8")
    (results / "99-x.json").write_text(json.dumps(_fake_result()), encoding="utf-8")
    argv = ["--results", str(results), "--problems", str(problems)]
    assert rb.main(argv + ["--check"]) == 1
    assert rb.main(argv) == 0
    assert rb.main(argv + ["--check"]) == 0
