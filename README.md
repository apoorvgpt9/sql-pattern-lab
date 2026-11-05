# sql-pattern-lab

A study system for data-engineering SQL interview problems. It trains **decomposition**: reading a problem's wording and knowing which steps need a JOIN, GROUP BY, window function or CTE. It also trains moving from a brute-force query to the optimal one, using **measured** evidence rather than folklore.

Every problem folder contains:

- a study guide (`README.md`, 10 fixed sections)
- 2–3 solutions, from brute force to optimal
- hand-computed edge-case datasets that every solution must pass
- a random-data generator for differential testing and benchmarks
- an empty `my_answer.sql` for you to work in

The main dialect is MySQL 8.0. Snowflake versions are included but labelled UNVERIFIED. The problem list and specs are in `problems.yaml`; the rules for writing content are in `CLAUDE.md`. The worked reference problem is [`problems/01-market-analysis-i`](problems/01-market-analysis-i/README.md).

## Run the tests locally

You need Python 3.11+ and a MySQL 8.0 server. Docker is the easiest way to get one:

```bash
docker run -d --name spl-mysql -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0 --local-infile=1
```

```bash
pip install -r requirements.txt
```

```bash
pytest -q harness
```

```bash
pytest -q harness -k 01-market-analysis-i
```

The connection comes from `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER` and `MYSQL_PASSWORD`, which default to `127.0.0.1`, `3306`, `root`, `root`. Each test creates its own throwaway database and drops it afterwards. If MySQL is unreachable, the database tests **fail** rather than skip, so a green run always means the SQL actually ran.

What `pytest -q harness` runs:

| Test | What it proves |
|---|---|
| `test_edge` | For each (problem, edge dataset, solution), the harness creates a fresh DB, runs `schema.sql`, then `tests/edge_<name>.sql`, then the solution, and compares the output to `expected/edge_<name>.csv`. |
| `test_edge_dataset_loads` | The dataset is valid SQL and has at most 15 rows per table, so it stays small enough to compute by hand. |
| `test_differential` | Every solution returns the same multiset on `gen.py` data (300 rows, seeds 1–5). On failure it reports which solution diverged and which rows differ, then searches for the smallest generated input that still reproduces the divergence. |
| `test_mistakes` | Each `mistakes/*.sql` (a tempting wrong query) fails every edge dataset its `-- breaks:` header names. This makes the guide's "this edge case breaks X" claims executable. |
| `test_structure` | The folder follows `CLAUDE.md`: `meta.yaml` equals its `problems.yaml` entry; the README has the 10 sections, exactly 3 hints and no TODOs; there are at least 4 edge datasets with matching CSVs; there is one `-- expect:` comment per expected row; `snowflake.sql` says UNVERIFIED; the BENCH region contains no hand-written numbers; pgexercises folders carry the license and attribution. |
| `test_unit` | The harness itself: SQL splitting, value normalisation, `render_bench.py`, `new_problem.py` for all 45 entries. |

**How results are compared:**

- **Rows** are compared as a multiset, unless `meta.yaml` `output.ordering` gives an order. In that case the order must match too. Anything other than "any order" or "single row" counts as an exact order.
- **NULLs:** a literal `NULL` cell in the CSV means SQL NULL. An empty cell is the empty string.
- **Numbers** are rounded to 5 decimal places on both sides before comparing, so `2`, `2.0` and `2.000001` are equal. A numeric-looking string counts as a number.
- **Column names** are compared case-insensitively, in order.
- **Session settings** are MySQL 8.0's defaults (`ONLY_FULL_GROUP_BY`, strict mode), with UTC as the time zone. Unrounded division keeps MySQL's 4 extra digits (`1/3` → `0.3333`), so hand-computed expected values must follow MySQL arithmetic.

## Study with `my_answer.sql`

1. Open a problem's `README.md`. Read sections 1–2, then stop.
2. Write your query in that folder's `my_answer.sql`.
3. Run it:

```bash
pytest -q harness -k 01-market-analysis-i --mine
```

`--mine` runs only your answer. It checks your answer against every edge dataset, then against the reference solution on random data. The random check catches bugs the edge cases miss; when your answer diverges, it prints the smallest generated input that shows the difference. If `my_answer.sql` is still empty, the tests are skipped with a reminder.

4. Climb the hint ladder (section 3) only when stuck. Then compare with the decomposition (section 4) and the approaches (section 5).

## Study app

`app/index.html` is a single self-contained page: open it straight from disk (double-click, `file://`), no server needed. It shows one problem at a time and reveals the guide in study order (trigger meanings, three hints, decomposition, approaches with the measured bench table, then the rest). Your attempt, status, reveal progress and a time-to-first-attempt stopwatch are kept in the browser's `localStorage` only. The page never runs SQL; paste your attempt into `my_answer.sql` or LeetCode.

It is generated, so do not edit it by hand. After changing a problem's README, `meta.yaml` or solutions, or after a bench run, rebuild and commit it:

```bash
python scripts/build_app.py
```

The page template is `app/template.html`. `--check` exits 1 if the committed `app/index.html` is stale. CI runs the build on every PR and fails on structural errors in any problem folder. Bench numbers in the app come from `bench/results/*.json`, never from text typed into a README.

## Add or complete a problem

```bash
python scripts/new_problem.py 7
```

This creates `problems/<NN>-<slug>/` with `meta.yaml`, the README skeleton (10 headings plus the BENCH markers), a commented-out draft `schema.sql`, and stubs. It never overwrites existing files, and it never creates solutions. A folder joins the correctness tests when its first `solutions/*.sql` appears, and `test_structure` fails until the folder is complete.

Conventions the harness enforces (see `problems/01-market-analysis-i` for every one in use):

- `tests/edge_<name>.sql`: INSERTs only, against the tables from `schema.sql`. Add one `-- expect: <row> | <why>` comment per expected output row. For an empty result, add a single `-- expect-empty: <why>`.
- `expected/edge_<name>.csv`: header row = `output.columns`. Compute it by hand, never by running a solution.
- `solutions/NN_<name>.sql`: the last statement must return the result. The highest-numbered file is treated as the optimal one (the reference for `--mine` and for bench ratios).
- `mistakes/<name>.sql` (optional): first line `-- breaks: edge_a, edge_b`.
- `gen.py`: `generate(n_rows, seed) -> {table: iterable of tuples}`, in `schema.sql` column order. It must be deterministic per seed, and it must stream (yield) rows so that `n_rows=1_000_000` fits in memory.
- `indexes.sql` (optional): the bench runs every solution without it, then with it.
- No `CREATE DATABASE` or `USE` anywhere, and no schema-qualified names (`cd.bookings` → `bookings`): the harness owns the database.

## Benchmarks

Numbers in READMEs come only from the **bench** workflow (Actions → bench → Run workflow, on `main`):

1. One job per batch in `problems.yaml` (B1–B6), each limited to 120 minutes.
2. For each problem and size (default `1000,100000,1000000` rows of the main table), it loads `gen.py` data with `LOAD DATA LOCAL INFILE`.
3. For each solution it runs 1 warm-up and 3 timed runs, and records the median plus `EXPLAIN ANALYZE`. It does this without indexes, then with `indexes.sql`.
4. Each statement is capped at 60 s. A timeout is recorded as `timeout >60s`, and a solution that timed out is not re-run at larger sizes.
5. Results go to `bench/results/<problem_dir>.json`, together with machine info and a digest of each solution's result. `scripts/render_bench.py` turns them into a table between `<!-- BENCH:<dir> -->` and `<!-- /BENCH -->`, and the final job commits both to `main`.

To try it locally, run the command below. Do not commit local results; `.gitignore` covers `bench/local/`.

```bash
python -m harness.bench --problems '01-*' --sizes 1000,100000 --out bench/local
```

CI (`.github/workflows/ci.yml`) runs `pytest -q harness` on every pull request and every push to `main`, against a `mysql:8.0` service container. It also runs a tiny bench smoke test, which catches generator or loader breakage before the real bench.

## Layout

```
problems.yaml            curated problem list (the spec)
problems/<NN>-<slug>/    one folder per problem (see CLAUDE.md)
harness/                 pytest suite + bench runner (python -m harness.bench)
scripts/new_problem.py   scaffold a problem folder from problems.yaml
scripts/render_bench.py  inject bench tables into READMEs
scripts/build_app.py     compile problems/* into app/index.html (template: app/template.html)
bench/results/           committed by the bench workflow only
```

## Licensing

Code: MIT (`LICENSE`). LeetCode problems are link-only: no statements, examples or editorials are reproduced. Folders derived from pgexercises.com are CC BY-SA 3.0 and carry their own `LICENSE.md`.
