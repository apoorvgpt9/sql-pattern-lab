# sql-pattern-lab — cloud session prompts

Run order and gates:

| Step | Session | Starts when | Parallel? |
|---|---|---|---|
| 0 | Scaffold | Repo created with `CLAUDE.md` + `problems.yaml` on `main` | — |
| 1 | Batch B1 … B6 | Scaffold PR merged and CI green on `main` | Yes, all six at once |
| 2 | Benchmarks | All batch PRs merged | Workflow, not a session |
| 3 | Independent review | Benchmarks committed | — |
| 4 | Study app | Review PR merged | — |

Check credit spend after step 0 before launching step 1. If spend is high, launch B1–B3 first, then B4–B6.

Each prompt below is self-contained: paste it as the first message of a fresh cloud session on the `sql-pattern-lab` repo.

---

## Step 0 — Scaffold

```
Read CLAUDE.md fully, then problems.yaml. Your job is the scaffold only — no problem content.

Build:
1. harness/ (Python 3.11, pytest, PyMySQL):
   - Connection from env vars MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD (defaults 127.0.0.1, 3306, root, root).
   - Discover every problems/<dir>/ that has solutions/*.sql. Parametrize tests per (problem, edge dataset, solution).
   - Each test: create a fresh database, run schema.sql, run tests/edge_<name>.sql, run the solution, compare to expected/edge_<name>.csv.
     Comparison: order-insensitive multiset unless meta.yaml output.ordering says an exact order; CSV literal NULL = SQL NULL;
     numbers compared after normalising to 5 decimal places; column names compared case-insensitively.
   - Differential test per problem: for seeds 1..5, generate data via gen.py generate(n_rows=300, seed), load it, run every
     solution, assert all results are identical multisets. Report which solution diverged and a minimal diff.
   - Bench mode (python -m harness.bench --problems <glob> --sizes 1000,100000,1000000): for each problem/size, load gen.py
     data with LOAD DATA LOCAL INFILE from temp CSVs (server needs --local-infile=1, client local_infile=True), then for
     each solution record wall time (median of 3 runs after 1 warm-up) and EXPLAIN ANALYZE text, first without and then
     with indexes.sql if present. SET SESSION max_execution_time=60000; record timeouts as "timeout >60s" (a timeout is a
     valid, teachable result). Write JSON to bench/results/<problem_dir>.json with machine info.
2. scripts/render_bench.py: replace the region between `<!-- BENCH:<dir> -->` and `<!-- /BENCH -->` (insert the closing
   marker if missing) in each README with a markdown table: rows = solutions, columns = sizes, cells = time; plus a
   "× slower than optimal" column at the largest size, and a note that GitHub-hosted runners are noisy so ratios matter
   more than absolute times.
3. .github/workflows/ci.yml: on pull_request and push to main. Service container mysql:8.0 with
   MYSQL_ROOT_PASSWORD=root and command options --local-infile=1, health-check before tests. Run pytest -q harness.
4. .github/workflows/bench.yml: workflow_dispatch only. Matrix over batches B1..B6 (read from problems.yaml), each job
   timeout-minutes 120, runs bench for its batch and uploads bench/results as an artifact. A final job downloads all
   artifacts, runs render_bench.py, and commits bench/results/*.json and READMEs to main with message
   "bench: update results [skip ci]" (permissions: contents: write).
5. scripts/new_problem.py <id>: creates problems/<NN>-<slug>/ from problems.yaml with meta.yaml, empty README with the
   10 section headings from CLAUDE.md and the BENCH markers, empty my_answer.sql, and stub files.
6. One fully worked EXAMPLE problem to prove the pipeline: pick the first problem in batch B1 from problems.yaml and
   build it completely to the CLAUDE.md standard (all 10 sections, ≥4 edge datasets, ≥2 solutions, gen.py,
   snowflake.sql). This is the reference every batch session will imitate — make it excellent.
7. README.md at the repo root: what this is, how to run tests locally, how to use my_answer.sql
   (`pytest -q harness -k <dir> --mine` runs the learner's answer against the edge datasets — implement the --mine flag).
8. .gitignore, requirements.txt, pyproject or pytest.ini.

Verify CI is green on your PR (fix until it is). Open the PR titled "scaffold: harness, CI, bench, example problem".
```

---

## Step 1 — Batch session (launch six copies, replace Bn with B1 … B6)

```
Read CLAUDE.md fully. Then study the example problem folder that already exists under problems/ — it is the quality
reference; match its depth and style.

Your scope: every problem in problems.yaml whose batch is Bn — nothing else. Work on branch batch-Bn.

For each problem, in problems.yaml order:
1. python scripts/new_problem.py <id>
2. schema.sql (MySQL 8.0; table and column names exactly as in problems.yaml).
3. Edge datasets FIRST, before any solution: at least 4 (typical, ties, NULLs, empty/no-match, plus any boundary the
   rules field mentions). Hand-compute expected/edge_*.csv and comment each expected row's reason in the .sql file.
4. Solutions 01 (natural brute force) → 03 (optimal). Each must pass all edge tests and the differential test.
5. gen.py producing realistic distributions that exercise the logic (duplicates, ties, NULL rate, skew) and scale to
   1,000,000 rows of the main table without exhausting memory (stream/yield if needed).
6. indexes.sql if the At scale section recommends indexes.
7. README.md — all 10 sections per CLAUDE.md. Leave the BENCH placeholder; never write performance numbers yourself.
8. snowflake.sql (UNVERIFIED label at top).
9. Run pytest -q harness -k <dir>; fix until green.

If a problem's spec in problems.yaml is ambiguous or wrong, add an "Assumptions" section, test the assumption, and list
it in the PR body. Do not skip problems; if one is genuinely blocked, finish the rest and explain the blocker in the PR.

Skip any problem whose folder already exists under problems/ (problem 01 is the finished example).

Save progress as you go: after each problem passes, commit it and push the branch. Open the PR as a draft after the
first problem, so partial work survives if the session is cut off; mark it ready when the batch is done.

Harness constraints:
- If meta.yaml output.ordering is anything other than "any order" or "single row", edge results are compared in exact
  order. Never put rows in an edge dataset that tie on every ordering key unless the spec defines the tie-break —
  otherwise the expected order is undefined. Add one edge dataset that tests the ordering itself.
- MySQL division gives 4 extra decimal places (div_precision_increment=4): 1/3 = 0.3333. Hand-computed expected values
  must follow MySQL's arithmetic and the spec's ROUND(), not exact math. Show the arithmetic in the expect: comment.
- Add mistakes/*.sql for every "this breaks the naive query" claim in your Edge cases section, as in problem 01.

Open one PR "batch Bn: <pattern names>" with a checklist of problems and their status. Make CI green.
```

---

## Step 2 — Benchmarks (no session needed)

After all batch PRs are merged: Actions → bench → Run workflow on `main`. When it finishes, READMEs contain measured tables.
Takes roughly 1–2 hours; uses private-repo Actions minutes.

---

## Step 3 — Independent review (fresh session, no prior context)

```
You are an independent reviewer. You did not write any of this content. Read CLAUDE.md, then review the problem
folders in your scope: SCOPE (run as two parallel sessions: "problems 01–24" on branch review-a, "problems 25–45" on
branch review-b). Do not touch folders outside your scope. Commit and push after each problem.
Spend the most effort on hard problems and on those whose meta.yaml confidence is not high.

For each problem, check and fix:
1. Spec fidelity: does the solution answer the requirement in meta.yaml exactly (output columns, grain, ties, NULLs)?
2. Adversarial testing: try to construct one dataset that breaks the optimal solution (ties at the boundary, NULL in a
   join key, duplicate rows, single-row groups, dates spanning month/year boundaries). If you find one, add it as a new
   edge dataset with hand-computed expected output and fix the solutions. Execution decides, not opinion.
3. Teaching quality of the Decomposition section: does each step say why it needs a JOIN / GROUP BY / window here, tied
   to wording in the problem? Rewrite steps that only describe what the SQL does.
4. Hint ladder: hint 1 must not give away hint 3. Each hint must reveal strictly more.
5. Brute force is a natural first attempt, not a strawman.
6. Performance claims: every claim points to the bench table or is labelled reasoned. Remove anything else.
   Batch sessions chose which approach is "optimal" from informal local timings. Read each problem's rendered bench
   table: where it contradicts "Why the optimal one wins" or the At-scale ranking, rewrite the text to match the
   measurements (or reorder solutions if the "optimal" one is clearly beaten without indexes).
   Remove any mistakes/*.sql whose failure depends on unspecified row order (e.g. relying on GROUP BY output order).
   Known from the bench (fix if in your scope):
   - 28: 02_window_running_sum is ~2.5x faster than the "optimal" 03_recursive_boarding at 1M rows. Make the window
     approach the optimal one (renumber files) or rewrite the text; keep the recursive CTE as a taught alternative.
   - 45: 02_row_number_asc_desc beats 03_row_number_and_count (~1.5s vs ~2.7s at 1M). Same treatment.
   - 43: benchmarked only at 1K and 100K, because 01 (correlated subqueries over a recursive closure) cannot finish
     at 1M and hung the bench. Say so in section 5/6 and explain why: closure size x per-employee rescans.
7. No reproduced problem text beyond the trigger phrases in problems.yaml.

Write REVIEW-<a|b>.md: one row per problem with score 1–5 on correctness, decomposition, hints, at-scale; and what
you changed. Open PR "review <a|b>: independent pass" and make CI green.
```

---

## Step 4 — Study app

```
Read CLAUDE.md. Build the study app.

1. scripts/build_app.py: read every problems/<dir>/ (meta.yaml, README.md split by its 10 section headings,
   solutions/*.sql, bench/results/<dir>.json, schema.sql) and produce app/index.html as ONE self-contained file with the
   data embedded as a JSON <script> block (must work when opened directly from disk — no fetch, no server).
   Render markdown to HTML at build time in Python; the page itself has no external dependencies.
2. Layout: sidebar of problems grouped by pattern, with difficulty badge and status; filters by pattern, difficulty,
   status, batch. Main pane for one problem, revealed in study order:
   - Always visible: link to original, schema & grain, trigger phrases (phrases visible, their meanings behind a reveal).
   - "My attempt" textarea (monospace, persisted per problem) with a Copy button — this is the exercise canvas; the
     learner pastes it into my_answer.sql or LeetCode to run.
   - Reveal buttons, one at a time and in order: Hint 1 → Hint 2 → Hint 3 → Decomposition → Approaches (with bench
     table) → At scale → Edge cases → Follow-ups → Snowflake notes → Pattern links (as in-app links).
   - Status selector: not started / attempted / solved / revisit; a "time to first attempt" stopwatch.
3. Persistence: localStorage, every read and write wrapped in try/catch; the page must work fully without it.
4. Light and dark themes via CSS variables and prefers-color-scheme; readable at phone width (16px gutters, no
   horizontal scroll except inside code blocks).
5. Add a CI step that runs build_app.py and fails if it errors. Commit the built app/index.html.
Open PR "app: study canvas".
```

---

## Step 5 — Frontend reskin (time-boxed, optional)

```
Read CLAUDE.md, then app/template.html and scripts/build_app.py. If a frontend-design skill is available, load it.

Goal: give the study app (now public at https://apoorvgpt9.github.io/sql-pattern-lab/) a distinctive, polished
visual design. It doubles as a portfolio piece for a senior data engineer. This is a RESKIN, hard time box 40 minutes.

You may change ONLY app/template.html (markup, CSS, the page's JS) and then regenerate app/index.html with
python scripts/build_app.py. Do not touch build_app.py, problems/, the harness or workflows.

Must keep (these are tested):
- Every existing element id the JS relies on, the embedded JSON data contract, and the reveal order:
  Hint 1 → 2 → 3 → Decomposition → Approaches → At scale → Edge cases → Follow-ups → Snowflake notes → Pattern links.
  Nothing gated may be in the visible DOM before its reveal.
- Works from file:// and from Pages; zero external requests (no CDN fonts or scripts; system font stacks only).
- localStorage wrapped in try/catch; the page must work with storage blocked.
- Light and dark themes via CSS variables and prefers-color-scheme; WCAG AA contrast (≥ 4.5:1 body text).
- 360px phone width with no horizontal page scroll; code scrolls inside its block.

Worth improving:
- The landing view: in 3 seconds a visitor should understand what this is (45 SQL problems, decomposition-first,
  every approach executed and benchmarked on MySQL 8.0), with a clear "start" path and a link to the repo.
- Visual hierarchy of the problem view: spec → attempt box → reveal ladder should read as one flow.
- The bench tables: add a small inline bar or ratio visual next to each time (pure CSS, from data already in the page).

Process: commit and push after the first working pass, open a draft PR immediately, then refine. Before marking
ready, verify in headless Chromium (Playwright is preinstalled): open a problem, click every reveal step in order,
check no console errors and no non-file requests, screenshot light, dark and 360px. Run python scripts/build_app.py
--check. Open PR "app: visual redesign" and make CI green.
```
