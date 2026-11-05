# Review b: problems 25–45 (independent pass)

Scope: `problems/25-*` … `problems/45-*`. Nothing outside these folders was changed except this file.

Scores are 1–5 **as found**, before this review's fixes. Where a fix changed the picture, the score after the fix is shown as `x→y`.

- **Correctness:** the solutions answer `meta.yaml` exactly, and they survive the adversarial datasets.
- **Decomposition:** each step says why it needs a JOIN / GROUP BY / window, and ties that to the wording.
- **Hints:** three hints, each revealing strictly more, and hint 1 does not give away hint 3.
- **At scale:** every performance claim matches the bench table or is labelled *reasoned*.

| # | Correct. | Decomp. | Hints | At scale | What changed |
|---|:-:|:-:|:-:|:-:|---|
| 25 exchange-seats | 5 | 5 | 5 | 4→5 | Why-wins said only "the measured table shows how that nets out". Now cites it: 03 5.6 s, 01 6.6 s, 02 24.8 s at 1M (two buffered windows are the cost). NULL names were already documented as out of spec. |
| 26 consistently-improving | 5 | 5 | 4→5 | 4→5 | Hint 1 named `ROW_NUMBER`/`LAG`/`LEAD` (hint 3's trick); trimmed. Measured margins added (03 is 5× faster than 02 at 1M). |
| 27 course-pairs | **3→5** | 5 | 4→5 | 4→5 | **Bug.** `SUM(course_rating) >= 4 * COUNT(*)` was called "exactly equivalent" to `AVG(course_rating) >= 4`, but it counts an unrated completion (NULL rating) as a 0. New hand-computed `tests/edge_null_rating.sql`: all three solutions returned nothing where five pairs are expected. Fixed to `4 * COUNT(course_rating)` in solutions, mistakes and `snowflake.sql`; old form kept as `mistakes/null_rating_as_zero.sql`. Hint 1 no longer names `LEAD`. Measured margins added. |
| 28 bus | 5 | 5 | 4→5 | 3→5 | **Renumbered**: window running sum is now `03` (optimal), recursive CTE is `02`. Without an index the window is 2.5× faster at 1M; the recursion wins (1,750×) only with the `turn` index and needs 3 preconditions. §5 cost models, why-wins and §6a/b rewritten from the table; hint 3 no longer spoils the recursion. A note above the bench table maps the old file names until the next bench run. |
| 29 restaurant-growth | 5 | 5 | 5 | 4→5 | Measured penalties added (02 is 8.4× slower; 01 times out at 1M). The ROWS-vs-calendar gap risk was already in Assumptions, with what breaks. |
| 30 rolling-revenue | 5 | 5 | 5 | 4→5 | Measured margins added: without the index 02 is only 1.3× slower than 03 (both scan everything), and with the index 2.2× slower (its `DATE(starttime)` join cannot range-scan). License and attribution OK. |
| 31 consecutive-numbers | **3→5** | 5 | 5 | 4→5 | **Bug.** `PARTITION BY num` groups NULLs, so 03 reported a NULL "run" where 01/02 return nothing (the batch author had noticed and left it untested). New `tests/edge_null_num.sql` also puts a NULL between equal values. 03 now filters `num IS NOT NULL` *after* numbering. Two new mistakes: `null_run_reported` and `drop_nulls_before_numbering` (filtering first closes the gap and reports '7'). |
| 32 stadium | **2→5** | 5 | 5 | 3→5 | **Bug: optimal crashed.** `ROW_NUMBER()` is `BIGINT UNSIGNED`, so `id - ROW_NUMBER()` raises *out of range* whenever `id < rn`: ids starting at 0, or NULL ids, which sort first and shift the numbering. NULL ids also share one NULL island. New `edge_null_id` and `edge_id_starts_at_zero`; 03 now uses `CAST(… AS SIGNED)` and `id IS NOT NULL`; new mistake `null_ids_form_an_island`. Follow-up 5 claimed 02 "may even be a little faster": measured 2.1× slower; fixed. |
| 33 persistent-behavior | 5 | 5 | 5 | 5 | No change. Probed the year boundary, non-leap Feb, a multi-action day splitting a streak, and tied longest streaks: all covered and passing. |
| 34 covid-recovery | 5 | 5 | 5 | 4→5 | Measured margins added (with the index, 01 beats 02). |
| 35 overbooked | 5 | 5 | 5 | 3→5 | Said 01 is "only competitive with the index"; with the index it is the **fastest** (0.83 s vs 1.66 s at 1M). The bench plan explains it: 66K tiny per-employee aggregates beat one 261K-group temp table. 03 stays optimal (01 times out without the index); why-wins and §6 now say when the ranking flips. Also "02 costs a little": it is 2.2× slower. |
| 36 churn-risk | 5 | 5 | 4→5 | 3→5 | §6b said the index "lets approach 3's GROUP BY stream". True, but measured **slower** (2.57 s → 3.82 s): the index is not covering, so streaming costs a PK lookup per row. Rewritten from the plan. Hint 3 overclaimed `ROW_NUMBER` as "the only safe way". |
| 37 zombie-sessions | 5 | 5 | 4→5 | 3→5 | Without the index 02 beats 03 at 100K (2×) and loses by 17% at 1M; the temp-table aggregate dominates, not the scans. 03's win is the streaming `Group aggregate` with the index (7×). Hint 1 gave away "all rules in HAVING". |
| 38 study-spiral | 4 | 5 | 5 | 4→5 | Solutions are correct under the stated interpretation (the slot-pair trick is sound). Confidence stays low: LeetCode's checker on the vague corners is still unverified. Margins added: 03 vs 02 is only 1.2×; with the index 01 ≈ 02. |
| 39 tree-node | 5 | 5 | 5 | 4→5 | Why-wins oversold margins: 03 vs 01 is 1.2×, and with the `p_id` index 02 is the fastest. Rewritten. |
| 40 friend-requests-ii | 5 | 5 | 5 | **2→5** | Cost model said the accepter index makes 01 "roughly linear". The bench plan shows the re-planned range scan reading the whole table per person (`rows=1000 loops=332`): same speed with or without the index, timeout at 100K either way. Rewritten. |
| 41 downward-chain | 5 | 4 | 5 | 3→5 | Without the index, 01 is faster than 03 at 100K (265 vs 414 ms); 03 wins at 1M (1.5×) and with the index (6.6×). Rewritten. **Removed `mistakes/no_order_by.sql`**: it failed only because of the order a recursive CTE happened to emit rows. Kept as a prose warning. |
| 42 upward-chain | 5 | 5 | 5 | 5 | Measured contrast added (5.6 s vs ~1 ms at 1M). No issues. |
| 43 org-hierarchy | 5 | 5 | 5 | 3→5 | Explains why there is no 1M column (see "43" below). §5/§6 tied to the 100K numbers. |
| 44 facilities-by-value | 5 | 5 | 5 | 3→5 | Checked by hand that 01's `((p−1)·3) DIV n` equals `NTILE(3)` for every remainder. §6b omitted that the index made 01/02 **slower** (1.02 → 1.57 s); added with plan evidence. License OK. |
| 45 median | 5 | 4→5 | 4→5 | **2→5** | **Renumbered**: asc/desc `ROW_NUMBER` is now `03` (optimal), `ROW_NUMBER + COUNT` is `02`. The "one sort beats two" cost model was wrong: the bench's EXPLAIN ANALYZE shows the full-partition `COUNT` frame as a *buffered* window (~1.6 s) against a ~0.2 s second sort. Cost models, why-wins, §6 and hint 3 rewritten; the decomposition keeps the definition-driven version and points to the faster one. |

## Cross-cutting checks

- **Order-dependent mistakes.** I ran every `mistakes/*.sql` in scope on the datasets it claims to break and listed those whose failure is *only* row order (26 cases). For each, the mistake's own `ORDER BY` is total on that data (unique names and keys), except `41/no_order_by.sql`, which had no `ORDER BY`: removed.
- **Unsigned `ROW_NUMBER` arithmetic.** I grepped all solutions in scope for subtraction involving `ROW_NUMBER()`. Only 32 could go negative. 31's difference of two row numbers is never negative, and 38/45 only subtract from positions ≥ 1.
- **Quoted text (rule 1).** Every quoted phrase in each section-1 trigger table is one of that problem's `problems.yaml` trigger phrases. Long quoted strings elsewhere are our own interview questions and spec rules.
- **pgexercises licensing (30, 41, 42, 44).** Each has `LICENSE.md` with CC BY-SA 3.0 and the attribution text, repeated in README section 1.
- **Brute force.** Every `01_*` is a natural first attempt (correlated subqueries, self-joins, a closure walked from everyone), not a strawman.

## 43: why the bench has no 1M column

The prompt's explanation was "closure size × per-employee rescans". **The plans contradict the rescan part.** The bench's `EXPLAIN ANALYZE` at 100K shows `reports` materialised once (693K rows), with each correlated subquery served by `Covering index lookup on r using <auto_key0>`, ~7 rows per employee. A local `EXPLAIN FORMAT=TREE` at 1M shows the same plan shape. What changes at 1M is the closure's size: ~8.4M rows, far past `tmp_table_size` (16 MB on the runner). Approach 1 builds that table with an auto-key index on disk, probes it 2M times, and does a PK lookup per pair. The README now says this, labelled *reasoned*.

Local diagnosis (sandbox, not quoted in the README because it is not bench data): at 1M, approach 3 finished in about 1.5 minutes, and two thirds of that time was the two `GROUP BY`s over the spilled closure. Approach 1 was still running after 7.5 minutes. It then **did not respond to `KILL`**, and held a lock that blocked every `DROP DATABASE`, until MySQL was restarted. That is very likely why the bench job "hung" instead of recording a timeout.

## Not changed (out of spec, noted)

- **40:** a self-friendship row `(a, a)` counts once in 01 (`OR`) and twice in 02/03. The spec does not allow such rows; not tested.
- **25:** NULL student names break the `COALESCE` forms. Already documented in the README as out of spec.
