#!/usr/bin/env python3
"""Scaffold problems/<NN>-<slug>/ for a problems.yaml entry.

    python scripts/new_problem.py 7

Creates only files that do not exist yet (safe to re-run). It never creates
solutions/*.sql: a folder enters the correctness tests once you add the first
solution, and the structure tests fail until the folder is complete.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from harness.spec import (ASSUMPTIONS_SECTION, BENCH_CLOSE, README_SECTIONS, bench_open,  # noqa: E402
                          problem_dir_name)

TYPE_MAP = {"int": "INT", "integer": "INT", "bigint": "BIGINT", "date": "DATE", "datetime": "DATETIME",
            "timestamp": "DATETIME", "varchar": "VARCHAR(100)", "text": "TEXT", "float": "FLOAT",
            "decimal": "DECIMAL(10,2)", "numeric": "DECIMAL(10,2)", "boolean": "BOOLEAN", "time": "TIME"}


def _sql_type(t: str) -> str:
    t = str(t).strip()
    if t.lower() in TYPE_MAP:
        return TYPE_MAP[t.lower()]
    base, paren, rest = t.partition("(")  # keep enum('a','b') values as written
    return base.upper() + paren + rest


def _table_name(name: str) -> str:
    return name.split(".")[-1]  # cd.bookings -> bookings (one database per test run)


def schema_draft(entry: dict) -> str:
    lines = [f"-- {entry['title']}: tables for MySQL 8.0. Names mirror the original.",
             "-- DRAFT generated from problems.yaml: check every type and nullability, then uncomment.",
             "-- The harness runs this in a fresh, empty database: no CREATE DATABASE / USE here.", ""]
    for tbl in entry.get("schema") or []:
        name = _table_name(tbl["table"])
        if name != tbl["table"]:
            lines.append(f"-- original name: {tbl['table']} (schema prefix dropped for MySQL)")
        lines.append(f"-- grain: {tbl.get('grain', '?')}")
        defs = [(f"{c['name']} {_sql_type(c['type'])}", c.get("note")) for c in tbl["columns"]]
        pks = [c["name"] for c in tbl["columns"] if c.get("pk")]
        if pks:
            defs.append((f"PRIMARY KEY ({', '.join(pks)})", None))
        lines.append(f"-- CREATE TABLE {name} (")
        for i, (d, note) in enumerate(defs):
            comma = "," if i < len(defs) - 1 else ""
            lines.append(f"--   {d}{comma}" + (f"  -- {note}" if note else ""))
        lines.append("-- );")
        lines.append("")
    return "\n".join(lines)


def readme(entry: dict, folder: str) -> str:
    src = entry.get("source")
    link = (f"Original: [{entry['title']}]({entry['url']}) ({src}, {entry.get('difficulty', '?')})."
            if entry.get("url") else f"Original problem written for this repo ({entry.get('source_id')}).")
    first = [link]
    if src == "pgexercises":
        first += ["", f"> {entry['attribution']} See `LICENSE.md`."]
    first += ["", "| Trigger phrase | What it forces in SQL |", "|---|---|"]
    first += [f"| \"{t['phrase']}\" | TODO |" for t in entry.get("trigger_phrases") or []]
    body = {
        README_SECTIONS[0]: "\n".join(first),
        README_SECTIONS[2]: "\n\n".join(
            f"<details><summary>Hint {i}</summary>\n\nTODO\n\n</details>" for i in (1, 2, 3)),
        README_SECTIONS[4]: f"TODO: approaches.\n\n{bench_open(folder)}\n{BENCH_CLOSE}\n\n### Why the optimal one wins\n\nTODO",
    }
    parts = [f"# {int(entry['id']):02d} · {entry['title']}", ""]
    for i, sec in enumerate(README_SECTIONS):
        parts += [f"## {sec}", "", body.get(sec, "TODO"), ""]
        if i == 1 and entry.get("confidence") != "high":
            note = entry.get("confidence_note", "")
            parts += [f"## {ASSUMPTIONS_SECTION}", "",
                      f"Confidence is `{entry.get('confidence')}`. {note}".strip(), "",
                      "TODO: state each interpretation and the edge dataset that tests it.", ""]
    return "\n".join(parts).rstrip() + "\n"


def license_md(entry: dict) -> str:
    return (f"# License\n\nThe content of this folder is adapted from PostgreSQL Exercises "
            f"(pgexercises.com) and is licensed under CC BY-SA 3.0 "
            f"(https://creativecommons.org/licenses/by-sa/3.0/).\n\n{entry['attribution']}\n\n"
            f"Source exercise: {entry.get('url')}\n\nSample data in this folder was generated for this "
            f"repo using the exercise's schema; it is not the original clubdata dump.\n")


def my_answer(entry: dict, folder: str) -> str:
    return (f"-- Your answer for {entry['title']}. Write a MySQL 8.0 query below, then run:\n"
            f"--   pytest -q harness -k {folder} --mine\n"
            f"-- Output columns: {', '.join(entry['output']['columns'])}\n")


GEN_STUB = '''"""Random data for {title}.

Contract (harness/discovery.py): generate(n_rows, seed) returns {{table_name: rows}}, where rows is
a list or iterator of tuples in schema.sql column order. n_rows is the size of the main table.
Must be deterministic for a seed and stream (yield) rows so that n_rows=1_000_000 fits in memory.
"""
import random


def generate(n_rows: int, seed: int) -> dict:
    rng = random.Random(seed)
    raise NotImplementedError("write the generator")
'''

SNOWFLAKE_STUB = "-- UNVERIFIED: Snowflake version of the optimal approach; CI cannot run it.\n"


def scaffold(entry: dict, root: Path) -> tuple[Path, list[str]]:
    folder = problem_dir_name(entry)
    base = root / folder
    files = {
        "meta.yaml": yaml.safe_dump(entry, sort_keys=False, allow_unicode=True, width=110),
        "README.md": readme(entry, folder),
        "schema.sql": schema_draft(entry),
        "gen.py": GEN_STUB.format(title=entry["title"]),
        "snowflake.sql": SNOWFLAKE_STUB,
        "my_answer.sql": my_answer(entry, folder),
        "tests/.gitkeep": "",
        "expected/.gitkeep": "",
        "solutions/.gitkeep": "",
    }
    if entry.get("source") == "pgexercises":
        files["LICENSE.md"] = license_md(entry)
    created = []
    for rel, content in files.items():
        path = base / rel
        if path.exists():
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        created.append(rel)
    return base, created


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("id", type=int, help="problem id from problems.yaml")
    ap.add_argument("--root", type=Path, default=REPO / "problems", help="where problem folders live")
    ap.add_argument("--yaml", type=Path, default=REPO / "problems.yaml")
    args = ap.parse_args(argv)
    entries = yaml.safe_load(args.yaml.read_text(encoding="utf-8"))
    entry = next((e for e in entries if e["id"] == args.id), None)
    if entry is None:
        print(f"no problem with id {args.id} in {args.yaml}", file=sys.stderr)
        return 2
    base, created = scaffold(entry, args.root)
    print(f"{base}: created {created or 'nothing (all files exist)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
