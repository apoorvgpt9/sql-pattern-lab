# sql-pattern-lab — instructions for every session

## What this repo is
A study system for SQL interview problems (data-engineering focus) that trains **decomposition and pattern recognition**: reading a problem's wording and knowing which steps need a JOIN, GROUP BY, window function, or CTE — then going from brute force to optimal, with *measured* evidence.

The learner is a data engineer with ~11 years' experience. Assume SQL fluency; teach judgment, not syntax.

## Non-negotiable rules
1. **Never reproduce problem statements, examples, or editorials** from LeetCode or any other platform. Link to the original. The only quoted text allowed is the short trigger phrases already listed in `problems.yaml` (≤ 8 words each). Everything else is in our own words.
2. **Main dialect: MySQL 8.0.** Every approach must run on MySQL 8.0. Snowflake versions go in `snowflake.sql` and are labelled **UNVERIFIED** (CI cannot run them).
3. **No fabricated numbers.** Performance figures come only from `bench/results/<problem_dir>.json` written by the benchmark workflow. Before results exist, use the placeholder `<!-- BENCH:<problem_dir> -->` exactly (followed by `<!-- /BENCH -->`); `scripts/render_bench.py` fills the region between them. Statements about billions of rows are *reasoned*, and must say so.
4. **Correctness is proven by execution**, not by review:
   - Every approach must pass every edge-case dataset (`tests/edge_*.sql` + `expected/edge_*.csv`).
   - All approaches for a problem must return identical results on randomly generated data (differential test).
   - Expected outputs for edge datasets are computed **by hand**, with a one-line comment in the data file explaining why each expected row is there. Never generate expected output by running one of your own solutions.
5. **The spec is `problems.yaml`.** Use its `requirement`, `output`, and `rules` fields as the source of truth. If a field is ambiguous or `confidence` is not `high`, state your interpretation in the guide under "Assumptions" and test it explicitly — do not silently pick one.
6. Keep `my_answer.sql` as an empty template in every problem folder (learner's workspace).
7. **Licensing by source** (see each entry's `source`, `license`, `attribution`):
   - `leetcode`: link-only, as in rule 1.
   - `pgexercises`: CC BY-SA 3.0. The folder must contain a `LICENSE.md` stating that its content is adapted from pgexercises.com under CC BY-SA 3.0, with the `attribution` text from `problems.yaml`, and the README's first section must repeat the attribution. Their sample data is not available to you — generate your own using their schema.
   - `original`: our own problems; no external link.

## Repository layout
```
problems.yaml                 # curated input (do not edit content except to fix a recorded error)
problems/<NN>-<slug>/
  meta.yaml                   # copy of this problem's entry from problems.yaml
  README.md                   # the study guide (template below)
  schema.sql                  # CREATE TABLE statements, MySQL 8.0, names mirror the original
  tests/edge_<name>.sql       # small INSERT datasets, one file per edge case (≤ 15 rows per table)
  expected/edge_<name>.csv    # hand-computed expected output, header row = output columns
  solutions/01_<name>.sql     # brute force / naive
  solutions/02_<name>.sql     # intermediate (optional)
  solutions/03_<name>.sql     # optimal
  gen.py                      # generate(n_rows:int, seed:int) -> dict[table, list[tuple]] for random + bench data
  indexes.sql                 # optional: indexes the "At scale" section recommends (bench runs with and without)
  mistakes/<name>.sql         # optional: tempting wrong queries; header `-- breaks: edge_a, edge_b` (harness proves it)
  snowflake.sql               # UNVERIFIED Snowflake version of the optimal approach
  my_answer.sql               # empty template for the learner
harness/                      # python test + bench harness (pytest, PyMySQL)
scripts/render_bench.py       # injects bench tables into READMEs
scripts/build_app.py          # compiles problems/* into app/data.json
app/index.html                # static study app
.github/workflows/ci.yml      # correctness tests on MySQL 8.0 service container
.github/workflows/bench.yml   # benchmarks; commits bench/results/<problem_dir>.json + rendered READMEs
```

## Study guide template (`README.md`) — all 10 sections, in this order
1. **Problem & trigger phrases** — link to original; the trigger phrases from `problems.yaml`, each with what it forces in SQL ("including those with no X" → LEFT JOIN keeps left side; filter must not be in WHERE on the right table).
2. **Schema & grain** — what one row of each input table means; what one row of the output must mean; the grain change the query must perform. Most bugs start here — say where the grain changes.
3. **Hint ladder** — exactly 3 hints, each in its own `<details><summary>Hint N</summary>…</details>`: (1) name the pattern, (2) the shape of the query (steps, no SQL), (3) the key clause or trick.
4. **Decomposition** — numbered steps; each step = one CTE; for each step a one-line *why this needs a JOIN / GROUP BY / window / filter here*. Then the assembled query. This is the most important section: it must teach how to get from wording to steps.
5. **Approaches: brute force → optimal** — 2–3 approaches. For each: SQL, why it is correct, cost model in plain words (table scans, row explosion, sorts), then the measured table `<!-- BENCH:<problem_dir> -->`. End with "Why the optimal one wins" in 2–3 sentences.
6. **At scale** — (a) what breaks first as rows grow; (b) single-machine fixes at ~1M–100M rows (indexes, rewrites) — reference `indexes.sql`; (c) distributed engines at billions of rows (Snowflake pruning/clustering, shuffle cost in Spark-style engines, why COUNT DISTINCT and global sorts hurt, when approximate functions are acceptable) — clearly labelled *reasoned, not measured*; (d) the data-engineering answer: incremental / materialized processing, with a sketch of the MERGE-style incremental version.
7. **Edge cases** — NULLs, ties, empty groups, duplicates, boundaries; each mapped to the `tests/edge_*.sql` file that exercises it and which naive approach it breaks, if any.
8. **Interviewer follow-ups** — 3–5 likely follow-ups with short answers.
9. **Snowflake notes (UNVERIFIED)** — what changes (QUALIFY, FULL OUTER JOIN, generators, etc.) and why it is better or worse.
10. **Pattern links** — other problems in this repo sharing the pattern, by folder name.

Optional between 2 and 3: **Assumptions** (required when `confidence` ≠ high).

## Quality bar
- Write for someone who knows SQL but freezes on decomposition. Prefer "notice X in the wording → that means Y" over generic explanation.
- Brute force must be a genuinely natural first attempt (correlated subquery, self-join, multiple passes) — not a strawman.
- Every claim about performance must either point to measured numbers or say "reasoned".
- No filler, no motivational text.

## Working practice for cloud sessions
- Work on your own branch; open a PR when your scope is complete. Keep PRs to one batch.
- Try to run MySQL 8.0 locally in the session first (`docker run mysql:8.0` if Docker is available, else install via package manager); if neither works, rely on CI and iterate on CI failures.
- Run `pytest -q harness -k <problem_dir>` for each problem before moving on.
- Do not modify `harness/`, workflows, or other batches' folders. If the harness has a bug, describe it in the PR body instead.
