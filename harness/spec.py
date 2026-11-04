"""Repository conventions shared by scripts/new_problem.py and the structure tests."""
from __future__ import annotations

import re

# README level-2 headings, in order (CLAUDE.md "Study guide template").
README_SECTIONS = [
    "1. Problem & trigger phrases",
    "2. Schema & grain",
    "3. Hint ladder",
    "4. Decomposition",
    "5. Approaches: brute force → optimal",
    "6. At scale",
    "7. Edge cases",
    "8. Interviewer follow-ups",
    "9. Snowflake notes (UNVERIFIED)",
    "10. Pattern links",
]
# Optional between sections 2 and 3; required when confidence != high.
ASSUMPTIONS_SECTION = "Assumptions"

MIN_EDGE_DATASETS = 4
MIN_SOLUTIONS = 2
MAX_EDGE_ROWS_PER_TABLE = 15
HINT_COUNT = 3

BENCH_CLOSE = "<!-- /BENCH -->"


def bench_open(problem_dir: str) -> str:
    return f"<!-- BENCH:{problem_dir} -->"


BENCH_OPEN_RE = re.compile(r"<!-- BENCH:([^\s>]+) -->")
HINT_RE = re.compile(r"<details>\s*<summary>\s*Hint (\d+)\s*</summary>", re.I)

# One comment per expected row in tests/edge_*.sql (rule 4):
#   -- expect: <row> | <why it is in the output>
# and, for a dataset whose expected output is empty:
#   -- expect-empty: <why nothing qualifies>
EXPECT_RE = re.compile(r"^\s*--\s*expect:\s*\S", re.M)
EXPECT_EMPTY_RE = re.compile(r"^\s*--\s*expect-empty:\s*\S", re.M)

# First line(s) of a mistakes/*.sql file: which edge datasets it must fail.
BREAKS_RE = re.compile(r"^\s*--\s*breaks:\s*(.+)$", re.M)


def slugify(title: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def problem_dir_name(entry: dict) -> str:
    return f"{int(entry['id']):02d}-{slugify(entry['title'])}"


def readme_h2(text: str) -> list[str]:
    """Level-2 headings outside fenced code blocks."""
    out, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced and line.startswith("## "):
            out.append(line[3:].strip())
    return out
