# 22 · Find Students Who Improved

## 1. Problem & trigger phrases

Original: [Find Students Who Improved](https://leetcode.com/problems/find-students-who-improved/) (LeetCode 3421, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** a student's results are tracked separately per subject. For every (student, subject) with exams on at least two different dates, compare the score of the earliest exam with the score of the latest exam. Return the pairs where the latest score is higher than the first, with both scores. Order by `student_id`, then `subject`.

| Trigger phrase | What it forces in SQL |
|---|---|
| "at least two different dates" | A per-pair count of exams, `>= 2`, or an argument that the comparison already needs two rows. Here the primary key makes dates unique within a (student, subject), so two exams means two dates. And a pair with one exam has *first = latest*, which fails a strict `>` anyway, so this condition is implied by the next one. |
| "latest score … higher than their first score" | Two extremes of the same group, picked **by date**, then compared **strictly**. `FIRST_VALUE`/`LAST_VALUE`, or `MIN`/`MAX` of the date joined back to the scores. Not `MAX(score)` versus `MIN(score)`: that compares best with worst, not latest with first. |
| (per student per subject) | The group is the pair `(student_id, subject)`. Partitioning by student only mixes subjects. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Scores` | one exam score of one student in one subject on one date | primary key `(student_id, subject, exam_date)`; `exam_date` is a `VARCHAR` holding `'YYYY-MM-DD'` |

**Output grain:** one row per improving (student, subject) pair, carrying two scores taken from two different input rows.

**Where the grain changes:** exam grain → (student, subject) grain. Unlike a plain aggregate, the output values (first and latest score) are not `SUM`/`MAX` of a column: they are the value of `score` at the minimum and at the maximum of **another** column (`exam_date`). That "value at the extreme of a different column" step is the problem. The approaches differ in how they fetch it: join back to the extremes, or a window function that puts them on every row.

**The date column is text.** Zero-padded ISO strings sort exactly like dates, so `MIN(exam_date)`, `MAX(exam_date)` and `ORDER BY exam_date` are chronological. This stops being true for `'2024-9-1'`-style strings; the spec guarantees ISO format. `tests/edge_date_strings.sql` places exams across a year end, a leap day and the 09-30 → 10-01 boundary.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **first and last row of each group** (by a date), then a comparison of the two. The result values come from two different rows of the group.

</details>

<details><summary>Hint 2</summary>

Shape: (1) group by student and subject. (2) For each group find the score at the earliest date and the score at the latest date. (3) Keep the groups where the second is strictly greater than the first. (4) Sort the result.

</details>

<details><summary>Hint 3</summary>

Key trick: in one pass, `FIRST_VALUE(score)` and `LAST_VALUE(score)` over `PARTITION BY student_id, subject ORDER BY exam_date`, with the frame `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. The frame is the catch: with only an `ORDER BY`, the default frame stops at the current row and `LAST_VALUE` just returns the current row's score. Then collapse the repeated rows with a `GROUP BY` or by keeping one row per pair.

</details>

## 4. Decomposition

"Compare the first with the latest, per student per subject": the unit is the pair; the two numbers are *values at the extremes of the date*.

1. **For every exam row, attach the pair's first score and latest score.**
   *Why a window function here:* the first and the latest scores are facts about a whole group but live on specific rows; `FIRST_VALUE`/`LAST_VALUE OVER (PARTITION BY student_id, subject ORDER BY exam_date …)` copies them onto every row without a join. Both functions use the same window, so the data is sorted once. The full-partition frame is required for `LAST_VALUE`.
2. **Keep the pairs where `latest_score > first_score`.**
   *Why a filter here:* "improved" is a strict comparison of the two columns that now sit on the same row. A pair with a single exam has the same row as both ends, so it fails the test; the "at least two dates" rule needs no separate condition.
3. **Collapse to one row per pair and order.**
   *Why a GROUP BY here:* after step 1 every exam row of a pair carries the same two values, so there are as many identical rows as exams. Grouping by `(student_id, subject, first_score, latest_score)` returns one. The spec's order is `student_id`, `subject`.

```sql
WITH w_scores AS (                                         -- step 1: first/latest on every row
  SELECT student_id, subject,
         FIRST_VALUE(score) OVER w AS first_score,
         LAST_VALUE(score)  OVER w AS latest_score
  FROM Scores
  WINDOW w AS (PARTITION BY student_id, subject
               ORDER BY exam_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
)
SELECT student_id, subject, first_score, latest_score
FROM w_scores
WHERE latest_score > first_score                           -- step 2
GROUP BY student_id, subject, first_score, latest_score    -- step 3
ORDER BY student_id, subject;
```

Self-check before you submit: take one improving pair with three exams and confirm that the returned first/latest are the first and last *by date*, not the lowest/highest. Check that no (student, subject) appears twice.

## 5. Approaches: brute force → optimal

### Approach 1: correlated `MIN`/`MAX` of the date, joined twice (`solutions/01_correlated_first_and_latest.sql`)

```sql
SELECT f.student_id, f.subject, f.score AS first_score, l.score AS latest_score
FROM Scores f
JOIN Scores l ON l.student_id = f.student_id AND l.subject = f.subject
WHERE f.exam_date = (SELECT MIN(a.exam_date) FROM Scores a WHERE a.student_id = f.student_id AND a.subject = f.subject)
  AND l.exam_date = (SELECT MAX(b.exam_date) FROM Scores b WHERE b.student_id = l.student_id AND b.subject = l.subject)
  AND l.score > f.score
ORDER BY f.student_id, f.subject;
```

**Why it is correct:** `f` is restricted to the first exam row of its pair and `l` to the last, both found by a correlated extreme of the date; the join on `(student_id, subject)` pairs them. Each pair has exactly one first and one last row (the key makes dates unique), so there is at most one output row per pair. A single-exam pair pairs a row with itself, and fails `l.score > f.score`.

**Cost model (reasoned):** the self-join on `(student_id, subject)` forms every combination of the pair's exams (k × k rows for a pair with k exams) before the two correlated filters discard most of them; every row of `f` and `l` also triggers a subquery. The primary key `(student_id, subject, exam_date)` makes each subquery a cheap index lookup of the first or last entry of the pair (no table scan), so on this schema the cost is driven by the number of rows × pair-size, not by a quadratic table scan. Without the key, it would be.

### Approach 2: `FIRST_VALUE` / `LAST_VALUE` in one window (`solutions/02_first_value_last_value.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the window orders each pair by `exam_date` and exposes the whole partition to both functions, so `FIRST_VALUE` is the score at the earliest date and `LAST_VALUE` the score at the latest. Filtering on `latest > first` and grouping on the four columns returns one row per improving pair.

**Cost model (reasoned):** one scan; the window needs rows ordered by `(student_id, subject, exam_date)`, which is exactly the primary-key order, so MySQL can read them in that order without an extra sort. There are no joins and no subqueries. The `GROUP BY` at the end works on rows that are already grouped. In an engine without a matching physical order, the cost is one sort of the table. Every exam row, not only the two ends of each pair, goes through the window evaluation, and `FIRST_VALUE`/`LAST_VALUE` with a full-partition frame make MySQL buffer the partition.

### Approach 3 (optimal): one `GROUP BY`, two joins back (`solutions/03_group_dates_then_join_twice.sql`)

```sql
WITH ends AS (SELECT student_id, subject, MIN(exam_date) AS first_date, MAX(exam_date) AS last_date
                FROM Scores GROUP BY student_id, subject HAVING COUNT(*) >= 2)
SELECT e.student_id, e.subject, f.score AS first_score, l.score AS latest_score
FROM ends e
JOIN Scores f ON f.student_id = e.student_id AND f.subject = e.subject AND f.exam_date = e.first_date
JOIN Scores l ON l.student_id = e.student_id AND l.subject = e.subject AND l.exam_date = e.last_date
WHERE l.score > f.score
ORDER BY e.student_id, e.subject;
```

**Why it is correct:** the CTE has exactly one row per pair with the two extreme dates; each join back matches exactly one `Scores` row (the key is the pair plus the date), so no row is duplicated or lost. `HAVING COUNT(*) >= 2` is the spec's literal condition; the strict comparison would drop single-exam pairs anyway.

**Cost model (reasoned):** one aggregation pass over `Scores` (index-ordered by the primary key, so it can stream) followed by two point lookups per pair through the primary key. The work is linear in the number of rows plus 2 × the number of pairs. This is the standard "aggregate the extremes, join back for the payload" shape. Only one row per pair is aggregated into a candidate, and the payload fetch touches two rows per pair instead of every row.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:22-find-students-who-improved -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/22-find-students-who-improved.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_first_and_latest` | 9.73 ms | 875 ms | 8.86 s | 3.4× |
| `02_first_value_last_value` | 3.38 ms | 281 ms | 6.38 s | 2.5× |
| `03_group_dates_then_join_twice` (optimal) | 2.74 ms | 197 ms | 2.59 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the expensive part, finding the two extreme dates of every pair, as a plain aggregate over the primary-key order, and then fetches exactly two rows per pair by key. Approach 2 reads each exam once but sends every row through a window, which MySQL evaluates by buffering partitions. So the ranking in MySQL is expected to favour approach 3 and the bench table is the arbiter; this is not a general law, and in an engine with cheap windows or aggregates like `MIN_BY`/`MAX_BY` (section 9) the one-pass forms win. The mechanism that makes all three acceptable here is the same: the primary key already orders rows by `(student_id, subject, exam_date)`, so the clustered key *is* the best index (section 6b) and there is no `indexes.sql`. Approach 2 is still the form that is hardest to get wrong about *which* rows are the ends; it only needs the right frame.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, since it forms k × k pairs of rows per (student, subject) before filtering and runs two subqueries per row. Approach 2 sends every row through a window and buffers partitions, so it is expected to slow down next, with total rows. Approach 3 degrades last, as the number of pairs (two lookups each) grows.

**(b) One machine, ~1M–100M rows.**
- `schema.sql` declares the primary key `(student_id, subject, exam_date)`. In InnoDB the table *is* that index (clustered), and it contains `score` too, so every approach is already served by an ordered, covering structure. A secondary index would only add write cost, so `indexes.sql` is intentionally absent.
- If the table were a heap with a different key (say, an auto-increment `id`), the index to add would be exactly `(student_id, subject, exam_date, score)`.
- Storing `exam_date` as `DATE` instead of `VARCHAR` is better for correctness (invalid strings are rejected) and for size; the ISO format makes the string sort order safe, but only by convention.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* all approaches have to bring a pair's exams together. A window shuffles every row once by `(student_id, subject)`. A decomposable alternative: `MIN_BY(score, exam_date)`/`MAX_BY(score, exam_date)` are *aggregates* that keep one (date, score) candidate per group, so each task pre-aggregates locally and only one row per (task, pair) is shuffled. For tables where each pair has many exams, that is substantially less network traffic than a window.
- *Skew:* a pair with an enormous number of exams would be one slow window partition; the pre-aggregating form avoids it.
- *Snowflake:* `MIN_BY`/`MAX_BY` give the equivalent of approach 3 in one `GROUP BY` (see `snowflake.sql`); no window and no join. Clustering by `student_id` keeps a student's rows together.
- *Things to avoid:* a global sort; `LAST_VALUE` without the full frame (silently returns the current row); casting the text date to a number for ordering.

**(d) The data-engineering answer.** First and latest values per key are cheap to maintain: the first is written once, the latest only moves forward. Keep `pair_summary(student_id, subject, first_date, first_score, latest_date, latest_score)`:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED): fold a batch of new exams into the summary.
MERGE INTO pair_summary t
USING (SELECT student_id, subject,
              MIN(exam_date) AS b_first_date, MIN_BY(score, exam_date) AS b_first_score,
              MAX(exam_date) AS b_last_date,  MAX_BY(score, exam_date) AS b_last_score
       FROM scores_batch GROUP BY student_id, subject) s
ON t.student_id = s.student_id AND t.subject = s.subject
WHEN MATCHED THEN UPDATE SET
  first_date   = IFF(s.b_first_date < t.first_date, s.b_first_date,  t.first_date),
  first_score  = IFF(s.b_first_date < t.first_date, s.b_first_score, t.first_score),
  latest_date  = IFF(s.b_last_date  > t.latest_date, s.b_last_date,  t.latest_date),
  latest_score = IFF(s.b_last_date  > t.latest_date, s.b_last_score, t.latest_score)
WHEN NOT MATCHED THEN INSERT (student_id, subject, first_date, first_score, latest_date, latest_score)
  VALUES (s.student_id, s.subject, s.b_first_date, s.b_first_score, s.b_last_date, s.b_last_score);

-- The question is then a filter on the summary:
SELECT student_id, subject, first_score, latest_score FROM pair_summary
WHERE latest_score > first_score ORDER BY student_id, subject;
```

(MySQL has no `MERGE` or `MIN_BY`: use `INSERT … ON DUPLICATE KEY UPDATE` with `IF(VALUES(first_date) < first_date, …)`. Within one UPDATE, MySQL assigns columns left to right and later assignments see the new values, so the order of the `SET` clauses matters: update the score columns before the date columns.) Caveats interviewers probe: a corrected or deleted first/latest exam cannot be patched from the summary, so the affected pairs are recomputed from `Scores`; late-arriving exams earlier than `first_date` are handled by the `first_*` branch.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| One improving pair and one declining pair of the same student; an equal pair; a single exam | `tests/edge_typical.sql` | `partition_by_student_only` (subjects mixed), `max_vs_min_score`, `non_strict_comparison` (equal pair and single exam reported) |
| Three exams where the best/worst score is in the middle | `tests/edge_peak_and_valley.sql` | `max_vs_min_score` (best vs worst, not latest vs first), `consecutive_pair_improved` (any step up), `last_value_default_frame` (the default frame ends at the current row) |
| Chronology across a year end, a leap day and 09-30 → 10-01; rows inserted out of order | `tests/edge_date_strings.sql` | `max_vs_min_score` |
| Output order: `student_id`, then `subject` (student 12 after 7; subject 'Art' before 'Math') | `tests/edge_ordering.sql` | `order_by_subject_first`, `partition_by_student_only` |
| Nothing improves: decline, equal, single exam | `tests/edge_no_improvement.sql` | `non_strict_comparison`, `max_vs_min_score` |

No approach in `solutions/` is broken by any of these. Equal scores and single-exam pairs are excluded by the strict comparison. NULLs are outside the spec; every column is `NOT NULL` in `schema.sql`.

## 8. Interviewer follow-ups

1. **"Students who improved in *every* subject."** Add a second level: count improving pairs per student and compare to the number of pairs (`COUNT(*) = SUM(improved)`), the "relational division by counting" idiom of problem 14.
2. **"Improvement between the *two most recent* exams only."** Replace `FIRST_VALUE` with `LAG(score) OVER (… ORDER BY exam_date)` and take the last row per pair. That is the case where `LAG` is right; for first vs latest it is wrong (`mistakes/consecutive_pair_improved.sql`).
3. **"Why does `LAST_VALUE` need the long frame, but `FIRST_VALUE` does not?"** With `ORDER BY`, the default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`: it always starts at the partition start (so `FIRST_VALUE` is right) and ends at the current row (so `LAST_VALUE` is the current row's value).
4. **"What if `exam_date` can have different formats?"** Parse to `DATE` before ordering (`STR_TO_DATE` in MySQL, `TRY_TO_DATE` in Snowflake) and decide what to do with rows that do not parse; ordering text only works under the ISO guarantee.
5. **"Two exams on the same date?"** The key forbids it here. If it were allowed, "first" and "latest" would need a tie-break column, or the result would be non-deterministic.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses `MIN_BY`/`MAX_BY` instead of window functions. What changes, and why:

- `MIN_BY(score, exam_date)` returns the `score` of the row with the smallest `exam_date`, and `MAX_BY` the largest. One `GROUP BY` replaces the window, the CTE and the outer group-by. Because `exam_date` is unique within a pair, there is no tie to resolve; with ties, the chosen row is arbitrary.
- `MIN_BY`/`MAX_BY` are aggregates, so Snowflake can compute partial results per micro-partition and merge them. A window requires the full partition on one node.
- `HAVING MAX_BY(…) > MIN_BY(…)` repeats the aggregates; alternatively wrap in a CTE or use `QUALIFY` after a window version.
- There are no secondary indexes. Text comparison is lexicographic, as in MySQL; casting to `DATE` is still better practice. MySQL's collation is case-insensitive by default, so `ORDER BY subject` may order differently from Snowflake's byte order for mixed-case subjects.

## 10. Pattern links

Same pattern (value at the extreme of another column; first/last row per group):
- `20-product-sales-analysis-iii`: first year per product, keeping every row of that year.
- `21-product-price-at-a-given-date`: latest row per key as of a date, with a default.
- `23-game-play-analysis-iv`: first date per player as the anchor for a measure.
- `24-immediate-food-delivery-ii`: first order per customer as the sample for a ratio.
- `18-find-stores-with-inventory-imbalance`: the highest- and lowest-priced row of a group, compared.
- `26-find-consistently-improving-employees`: comparison of ordered rows within a group using `LAG`.
