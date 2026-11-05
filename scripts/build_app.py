#!/usr/bin/env python3
"""Compile problems/* into app/index.html: one self-contained study page.

Inputs, per problems/<dir>/: meta.yaml, README.md (split on its 10 section headings),
schema.sql, solutions/*.sql, and bench/results/<dir>.json. The page template is
app/template.html; this script embeds the data as a JSON <script> block and renders
all markdown to HTML here, so the output needs no server, no fetch and no external
files, and works when opened straight from disk.

    python scripts/build_app.py                       # write app/index.html
    python scripts/build_app.py --out /tmp/x.html     # write elsewhere
    python scripts/build_app.py --check               # exit 1 if app/index.html is stale

Errors (exit 1): anything that would make the page wrong or incomplete: a README whose
headings are not the 10 sections, a hint ladder that is not exactly 3 hints, a trigger
table that cannot be parsed, a bench JSON for the wrong problem, missing attribution
on a CC BY-SA problem. Warnings (exit 0) are printed and listed at the end.

The build is deterministic (no timestamps), so --check can detect a stale commit.
Bench figures come only from bench/results/*.json, rendered by scripts/render_bench.py.
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

import yaml
from markdown_it import MarkdownIt

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "scripts"))

import render_bench  # noqa: E402
from harness.spec import ASSUMPTIONS_SECTION, BENCH_CLOSE, README_SECTIONS, bench_open  # noqa: E402

PROBLEMS_DIR = REPO / "problems"
RESULTS_DIR = REPO / "bench" / "results"
TEMPLATE = REPO / "app" / "template.html"
DEFAULT_OUT = REPO / "app" / "index.html"
DATA_TOKEN = "__APP_DATA__"

# README section index (0-based, within README_SECTIONS) -> app key.
SECTION_KEYS = ["problem", "schema", "hints", "decomposition", "approaches", "scale",
                "edge", "followups", "snowflake", "links"]
# The reveal ladder, in study order. (key, title shown in the app.)
LADDER = [("hint1", "Hint 1"), ("hint2", "Hint 2"), ("hint3", "Hint 3"),
          ("decomposition", "Decomposition"), ("approaches", "Approaches: brute force → optimal"),
          ("scale", "At scale"), ("edge", "Edge cases"), ("followups", "Interviewer follow-ups"),
          ("snowflake", "Snowflake notes (UNVERIFIED)"), ("links", "Pattern links")]

PATTERN_LABELS = {
    "anti_join": "Anti-join / outer-join preservation",
    "conditional_aggregation": "Conditional aggregation",
    "pivot": "Pivot and scaffold fill",
    "self_join": "Pairwise self-join",
    "relational_division": "Relational division",
    "ranking_per_group": "Ranking per group",
    "dedup_latest": "First / latest row per key",
    "retention_cohort": "Retention and cohorts",
    "lag_lead": "LAG / LEAD",
    "running_totals": "Running and moving windows",
    "date_spine": "Calendar spine",
    "gaps_and_islands": "Gaps and islands",
    "sessionization": "Sessionization and sequencing",
    "recursive_cte": "Recursive CTE (hierarchy, graph)",
    "median_percentile": "Median and percentile",
}

NO_BENCH_NOTE = ("_No benchmark results yet: `bench/results/{dir}.json` has not been written by the "
                 "bench workflow for this problem._")

errors: list[str] = []
warnings: list[str] = []


def err(dir_: str, msg: str) -> None:
    errors.append(f"{dir_}: {msg}")


def warn(dir_: str, msg: str) -> None:
    warnings.append(f"{dir_}: {msg}")


# ---------------------------------------------------------------- SQL highlighting

SQL_KEYWORDS = """
select from where group by order having join left right inner outer full cross on using as with
recursive union all intersect except distinct and or not null is in exists between like case when
then else end over partition rows range unbounded preceding following current row limit offset asc
desc insert into values update set delete create table index primary key default duplicate merge
matched qualify lateral true false interval unique references foreign if drop alter add view
temporary engine database use constraint check
""".split()
SQL_TOKEN_RE = re.compile(
    r"(?P<com>--[^\n]*|/\*.*?\*/)"
    r"|(?P<str>'(?:[^'\\]|\\.|'')*')"
    r"|(?P<id>`[^`\n]*`)"
    r"|(?P<num>\b\d+(?:\.\d+)?\b)"
    r"|(?P<kw>\b(?:" + "|".join(SQL_KEYWORDS) + r")\b)"
    r"|(?P<fn>\b[A-Za-z_][A-Za-z0-9_]*(?=\s*\())",
    re.I | re.S,
)
SQL_CLASS = {"com": "sx-c", "str": "sx-s", "id": "sx-i", "num": "sx-n", "kw": "sx-k", "fn": "sx-f"}


def highlight_sql(code: str) -> str:
    """Single-pass tokenizer: every character is emitted exactly once, escaped."""
    out, pos = [], 0
    for m in SQL_TOKEN_RE.finditer(code):
        out.append(html.escape(code[pos:m.start()], quote=False))
        out.append(f'<span class="{SQL_CLASS[m.lastgroup]}">{html.escape(m.group(), quote=False)}</span>')
        pos = m.end()
    out.append(html.escape(code[pos:], quote=False))
    result = "".join(out)
    # Guard: highlighting must never change the text a learner copies.
    if html.unescape(re.sub(r"<[^>]+>", "", result)) != code:
        raise AssertionError("SQL highlighter altered the source text")
    return result


# ---------------------------------------------------------------- markdown

def make_markdown() -> MarkdownIt:
    # commonmark + GFM tables, the dialect the READMEs were written and reviewed against.
    # html=False: raw HTML in the source is escaped, never passed through.
    md = MarkdownIt("commonmark", {"html": False, "linkify": False}).enable("table")

    def fence(self, tokens, idx, options, env):
        tok = tokens[idx]
        lang = (tok.info or "").strip().split(" ")[0].lower()
        body = highlight_sql(tok.content) if lang in ("sql", "mysql", "snowflake") \
            else html.escape(tok.content, quote=False)
        return f'<pre class="code"><code class="language-{html.escape(lang or "text")}">{body}</code></pre>\n'

    def link_open(self, tokens, idx, options, env):
        tok = tokens[idx]
        if re.match(r"https?://", tok.attrGet("href") or ""):
            tok.attrSet("target", "_blank")
            tok.attrSet("rel", "noopener noreferrer")
        return self.renderToken(tokens, idx, options, env)

    md.add_render_rule("fence", fence)
    md.add_render_rule("link_open", link_open)
    return md


MD = make_markdown()
PROBLEM_REF_RE = re.compile(r"<code>(\d{2}-[a-z0-9][a-z0-9-]*)</code>")


def strip_tags(s: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def label_table(table_html: str) -> str:
    """Add data-label to every <td> so CSS can stack rows on a phone (no sideways scrolling)."""
    heads = [strip_tags(h) for h in re.findall(r"<th[^>]*>(.*?)</th>", table_html, re.S)]

    def row(m: re.Match) -> str:
        i = 0

        def cell(mm: re.Match) -> str:
            nonlocal i
            label = heads[i] if i < len(heads) else ""
            i += 1
            return f'<td{mm.group(1)} data-label="{html.escape(label, quote=True)}">'

        return re.sub(r"<td([^>]*)>", cell, m.group(0))

    return re.sub(r"<tr>.*?</tr>", row, table_html, flags=re.S)


def finish(html_: str, known: set[str], dir_: str, titles: dict[str, str]) -> str:
    """Post-process rendered HTML: in-app links for problem folders, stackable tables."""
    def link(m: re.Match) -> str:
        d = m.group(1)
        if d == dir_:
            return m.group(0)
        if d not in known:
            warn(dir_, f"references `{d}`, which is not a problem folder")
            return m.group(0)
        return (f'<a class="plink" href="#/p/{d}" title="{html.escape(titles[d], quote=True)}">'
                f'<code>{d}</code></a>')

    html_ = PROBLEM_REF_RE.sub(link, html_)
    html_ = re.sub(r"<table>.*?</table>",
                   lambda m: f'<div class="tbl">{label_table(m.group(0))}</div>', html_, flags=re.S)
    return html_


# ---------------------------------------------------------------- README parsing

def split_sections(text: str) -> tuple[dict[str, str], list[str]]:
    """Split on level-2 headings outside fenced code (same rule as harness.spec.readme_h2)."""
    bodies: dict[str, list[str]] = {}
    order: list[str] = []
    cur, fenced = None, False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced and line.startswith("## "):
            cur = line[3:].strip()
            order.append(cur)
            bodies[cur] = []
            continue
        if cur is not None:
            bodies[cur].append(line)
    return {k: "\n".join(v).strip("\n") for k, v in bodies.items()}, order


HINT_BLOCK_RE = re.compile(r"<details>\s*<summary>\s*Hint (\d+)\s*</summary>(.*?)</details>", re.I | re.S)


def parse_trigger_section(md_text: str, render, dir_: str, n_meta_phrases: int) -> dict | None:
    """Section 1 -> visible prose, [(phrase, meaning)] rows, and the prose after the table."""
    rendered = MD.render(md_text)
    tables = re.findall(r"<table>.*?</table>", rendered, re.S)
    if len(tables) != 1:
        err(dir_, f"section 1 must contain exactly one trigger-phrase table, found {len(tables)}")
        return None
    before, rest = rendered.split("<table>", 1)
    table, after = rest.split("</table>", 1)
    rows = []
    for tr in re.findall(r"<tr>(.*?)</tr>", table, re.S):
        if "<th" in tr:
            continue
        cells = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)
        if len(cells) != 2:
            err(dir_, f"trigger table row has {len(cells)} cells, expected 2")
            return None
        rows.append({"phrase": render(cells[0]), "meaning": render(cells[1])})
    if not rows:
        err(dir_, "trigger table has no rows")
        return None
    if len(rows) != n_meta_phrases:
        warn(dir_, f"README lists {len(rows)} trigger phrases, meta.yaml lists {n_meta_phrases}")
    return {"prose": render(before), "phrases": rows, "after": render(after)}


# ---------------------------------------------------------------- per problem

def load_bench(dir_: str) -> dict | None:
    path = RESULTS_DIR / f"{dir_}.json"
    if not path.exists():
        return None
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
        if result.get("problem") != dir_:
            err(dir_, f"{path.name} is for problem {result.get('problem')!r}")
            return None
        render_bench.render_table(result)  # fail now, not in the browser
    except (KeyError, ValueError, TypeError) as e:
        err(dir_, f"cannot render {path.name}: {e!r}")
        return None
    return result


def render_approaches(md_text: str, dir_: str, bench: dict | None, render) -> str:
    """Render section 5 with the BENCH region filled from the JSON, wrapped in .bench."""
    opener = bench_open(dir_)
    if opener not in md_text or BENCH_CLOSE not in md_text:
        warn(dir_, f"section 5 has no {opener} ... {BENCH_CLOSE} region")
        return render(md_text)
    table = render_bench.render_table(bench) if bench else NO_BENCH_NOTE.format(dir=dir_)
    head, tail = md_text.split(opener, 1)
    old_region, tail = tail.split(BENCH_CLOSE, 1)
    if bench and old_region.strip() != table.strip():
        warn(dir_, "README bench table differs from bench/results JSON (run scripts/render_bench.py); "
                   "the app uses the JSON")
    return render(head) + f'<div class="bench">{render(table)}</div>' + render(tail)


def build_problem(pdir: Path, known: set[str], titles: dict[str, str]) -> dict | None:
    dir_ = pdir.name
    try:
        meta = yaml.safe_load((pdir / "meta.yaml").read_text(encoding="utf-8"))
        readme = (pdir / "README.md").read_text(encoding="utf-8")
        schema_sql = (pdir / "schema.sql").read_text(encoding="utf-8")
    except (OSError, yaml.YAMLError) as e:
        err(dir_, f"cannot read inputs: {e}")
        return None

    if f"{int(meta['id']):02d}" != dir_.split("-", 1)[0]:
        err(dir_, f"meta.yaml id {meta['id']} does not match the folder prefix")
        return None

    sections, order = split_sections(readme)
    want = list(README_SECTIONS)
    if ASSUMPTIONS_SECTION in order:
        want.insert(2, ASSUMPTIONS_SECTION)
    if order != want:
        err(dir_, f"README headings are not the 10 sections in order.\n    found:    {order}\n    expected: {want}")
        return None

    def render(md_text: str) -> str:
        return finish(MD.render(md_text), known, dir_, titles)

    def render_inline(html_: str) -> str:
        return finish(html_, known, dir_, titles)

    # Section 1: prose / trigger rows / post-table prose (held back until meanings are revealed).
    trig = parse_trigger_section(sections[README_SECTIONS[0]], render_inline, dir_,
                                 len(meta.get("trigger_phrases") or []))
    # Section 3: exactly three hints, each its own reveal step.
    hint_src = sections[README_SECTIONS[2]]
    hints = HINT_BLOCK_RE.findall(hint_src)
    if [n for n, _ in hints] != ["1", "2", "3"]:
        err(dir_, f"hint ladder must be exactly Hint 1, 2, 3 in <details> blocks; found {[n for n, _ in hints]}")
        return None
    if HINT_BLOCK_RE.sub("", hint_src).strip():
        warn(dir_, "text outside the <details> hints in section 3 is not shown in the app")

    bench = load_bench(dir_)
    html_by_key: dict[str, str] = {"hint1": render(hints[0][1].strip()),
                                   "hint2": render(hints[1][1].strip()),
                                   "hint3": render(hints[2][1].strip())}
    for idx, key in enumerate(SECTION_KEYS):
        if key in ("problem", "hints"):
            continue
        body = sections[README_SECTIONS[idx]]
        html_by_key[key] = render_approaches(body, dir_, bench, render) if key == "approaches" else render(body)

    solutions = []
    for f in sorted((pdir / "solutions").glob("*.sql")):
        solutions.append({"file": f.name, "optimal": bool(bench and f.stem == bench.get("optimal")),
                          "html": highlight_sql(f.read_text(encoding="utf-8"))})
    if not solutions:
        err(dir_, "no solutions/*.sql")

    source = meta["source"]
    if source == "pgexercises" and not (meta.get("attribution") and (pdir / "LICENSE.md").exists()):
        err(dir_, "pgexercises problem needs `attribution` in meta.yaml and a LICENSE.md (CC BY-SA 3.0)")

    if trig is None:
        return None
    rules = {k: str(v) for k, v in (meta.get("rules") or {}).items()}
    return {
        "dir": dir_,
        "id": int(meta["id"]),
        "title": meta["title"],
        "source": source,
        "source_id": str(meta.get("source_id", "")),
        "url": meta.get("url"),
        "difficulty": meta["difficulty"],
        "batch": meta["batch"],
        "confidence": meta.get("confidence", "high"),
        "pattern": meta["pattern_primary"],
        "pattern_secondary": list(meta.get("pattern_secondary") or []),
        "attribution": meta.get("attribution"),
        "output": {"columns": list(meta["output"]["columns"]), "ordering": str(meta["output"]["ordering"]),
                   "grain": str(meta["output"]["grain"])},
        "rules": rules,
        "problem": trig,
        "assumptions": render(sections[ASSUMPTIONS_SECTION]) if ASSUMPTIONS_SECTION in sections else None,
        "schema": render(sections[README_SECTIONS[1]]),
        "schema_sql": highlight_sql(schema_sql),
        "steps": [{"key": k, "title": t, "html": html_by_key[k]} for k, t in LADDER],
        "solutions": solutions,
        "has_bench": bench is not None,
    }


# ---------------------------------------------------------------- assemble

def build() -> str:
    dirs = sorted(p for p in PROBLEMS_DIR.iterdir() if p.is_dir() and re.match(r"\d{2}-", p.name))
    if not dirs:
        raise SystemExit("error: no problems/<NN>-<slug> folders found")
    known = {p.name for p in dirs}
    titles: dict[str, str] = {}
    for p in dirs:
        try:
            titles[p.name] = yaml.safe_load((p / "meta.yaml").read_text(encoding="utf-8"))["title"]
        except (OSError, yaml.YAMLError, KeyError, TypeError):
            titles[p.name] = p.name  # the real error is reported by build_problem

    problems = [pr for pr in (build_problem(p, known, titles) for p in dirs) if pr]
    if errors:
        return ""

    seen_patterns: list[str] = []
    for pr in problems:
        if pr["pattern"] not in seen_patterns:
            seen_patterns.append(pr["pattern"])
    data = {
        "patterns": [{"slug": s, "label": PATTERN_LABELS.get(s, s.replace("_", " ").capitalize())}
                     for s in seen_patterns],
        "batches": sorted({pr["batch"] for pr in problems}),
        "problems": problems,
    }
    for s in seen_patterns:
        if s not in PATTERN_LABELS:
            warn("build_app", f"no display label for pattern {s!r}; add it to PATTERN_LABELS")

    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    # Safe inside <script>: no literal "<" (so no "</script" or "<!--"), no raw line separators.
    payload = payload.replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    template = TEMPLATE.read_text(encoding="utf-8")
    if template.count(DATA_TOKEN) != 1:
        raise SystemExit(f"error: {TEMPLATE} must contain {DATA_TOKEN} exactly once")
    return template.replace(DATA_TOKEN, payload)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true",
                    help="do not write; exit 1 if the existing output file differs from a fresh build")
    args = ap.parse_args(argv)

    page = build()
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    if errors:
        print(f"\nbuild failed with {len(errors)} error(s):", file=sys.stderr)
        for e in errors:
            print(f"  error: {e}", file=sys.stderr)
        return 1

    data = page.encode("utf-8")
    if args.check:
        if not args.out.exists() or args.out.read_bytes() != data:
            print(f"{args.out} is out of date: run `python scripts/build_app.py` and commit it", file=sys.stderr)
            return 1
        print(f"{args.out} is up to date")
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(data)
    n = page.count('"dir":"')
    print(f"wrote {args.out} ({len(data) / 1e6:.2f} MB, {n} problems, {len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
