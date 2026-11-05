# 27 · Most Common Course Pairs

## 1. Problem & trigger phrases

Original: [Most Common Course Pairs](https://leetcode.com/problems/most-common-course-pairs/) (LeetCode 3764, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** a *top performer* is a user with at least 5 completed courses whose average course rating is at least 4. For each top performer, put their completed courses in completion order and look at each pair of adjacent courses, "A then B". Count how often each ordered (A, B) pair occurs across all top performers, and list the pairs by count (highest first), then by A, then by B.

| Trigger phrase | What it forces in SQL |
|---|---|
| "at least 5 courses" | A *cohort* defined by a per-user aggregate (`COUNT(*)` and the average rating). That is a `GROUP BY user_id HAVING …`, and it must run **before** the windowing, so that only top performers' rows enter the sequence step. A per-row `WHERE course_rating >= 4` is the wrong tool: it filters courses, not users. |
| "consecutive course pairs" | Neighbour access inside each user's ordered history: `LEAD(course_name) OVER (PARTITION BY user_id ORDER BY completion_date …)`. The `PARTITION BY` is what stops a pair from spanning two users. The order is by *date*, not by `course_id`. |
| "pair frequency" | A second aggregation at a new grain: `GROUP BY first_course, second_course` with `COUNT(*)`, after dropping the NULL successor of each user's last course. Pairs are ordered: A→B and B→A are different rows. |

Also notice: the output names are course *names*, not ids. Two editions of one course (different ids, same name) count as the same pair.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `course_completions` | one user completed one course | `(user_id, course_id)` is the PK; `completion_date` orders a user's history; `course_rating` (1–5) feeds the cohort test; `course_name` is what the output shows |

**Output grain:** one row per distinct ordered pair of course *names*, with the number of times that transition occurred.

**Where the grain changes (three times):**
1. *Cohort filter:* completions → completions of top performers. Row grain is unchanged, but whole users disappear. Decided by an aggregate per user, so it needs `GROUP BY user_id`.
2. *Sequencing:* completions → transitions. A user with *k* completions has *k − 1* transitions, so the last completion of each user produces no pair. This step is a window and does not change the number of rows until the NULL successor is dropped.
3. *Counting:* transitions → distinct name pairs, via `GROUP BY` with `COUNT(*)`.

Bugs come from doing these in the wrong order or at the wrong key: windowing across users, windowing before filtering the cohort, filtering rows instead of users, and grouping by course id when the output is by name.

## Assumptions

`confidence` is `high`, but the spec leaves one case open and we fix a few readings to make the test data unambiguous:

1. **Same completion date.** The spec says same-date completions for one user are not addressed. Our interpretation: break the tie by `course_id` (smaller id first). Every solution orders by `completion_date, course_id`. Tested in `tests/edge_same_date.sql`; `mistakes/tiebreak_by_name.sql` shows a different tie-break fails.
2. **Pairs are counted by course name**, as the output grain says, so two `course_id`s with one name merge. Tested in `tests/edge_ordering.sql` (`mistakes/group_by_course_id.sql` fails it).
3. **"Average rating ≥ 4"** is evaluated as `SUM(course_rating) >= 4 * COUNT(course_rating)`. For integer ratings this is exactly equivalent to `AVG(course_rating) >= 4`, NULLs included: both skip an unrated completion (NULL `course_rating`), which still counts toward the 5 completed courses. It also avoids relying on how many decimal places a division keeps. Tested at the exact boundary (average 4.0) in `tests/edge_thresholds.sql`, and with unrated completions in `tests/edge_null_rating.sql`. The tempting `SUM(course_rating) >= 4 * COUNT(*)` is **not** equivalent: it counts an unrated course as a 0 (`mistakes/null_rating_as_zero.sql`).
4. **"At least 5 completed courses"** counts the user's rows: the primary key allows each course once per user.
5. Names are compared and sorted with MySQL's default case-insensitive collation. The datasets avoid names that differ only by case.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **filter a cohort first, then neighbour access inside each member's ordered history, then count the transitions.** Three different grains in one query, in that order.

</details>

<details><summary>Hint 2</summary>

Shape: (1) find the users who qualify (count and average, per user). (2) For those users only, order each one's courses by date and pair every course with the next one. (3) Throw away the pair that has no next course. (4) Group by the two names, count, and sort.

</details>

<details><summary>Hint 3</summary>

Key trick: `LEAD(course_name) OVER (PARTITION BY user_id ORDER BY completion_date, course_id)` produces each course together with its successor in one pass. Without the `PARTITION BY`, a user's last course is paired with the next user's first course. The cohort test is `HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating)`, applied to users, not to rows.

</details>

## 4. Decomposition

Read the wording in the order the data must be reduced: *who* (the cohort), *which pairs* (adjacent in time), *how many* (count by pair).

1. **`top_users`: `GROUP BY user_id HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating)`.**
   *Why a GROUP BY here:* "at least 5 courses" and "average rating" are properties of a *user*, not of a row. Doing it first also means the window in step 2 sees only top performers' rows.
2. **`transitions`: join `course_completions` to `top_users`, then `LEAD(course_name) OVER (PARTITION BY user_id ORDER BY completion_date, course_id)`.**
   *Why a join and a window here:* the join keeps only cohort members. The window reads the next row in each user's own history: `PARTITION BY user_id` makes "next" mean "next course of this user", and the `ORDER BY` defines "next" as the next completion in time.
3. **Drop rows where the successor is NULL.**
   *Why a filter here:* the last course of every user has no successor and is not a pair.
4. **`GROUP BY first_course, second_course`, `COUNT(*)`, then `ORDER BY transition_count DESC, first_course, second_course`.**
   *Why a second GROUP BY here:* "pair frequency" is a count over transitions at the (first, second) grain. The spec fixes the full sort order, so all three keys are needed.

Assembled:

```sql
WITH top_users AS (                                                   -- step 1
  SELECT user_id FROM course_completions
  GROUP BY user_id
  HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating)
),
transitions AS (                                                      -- step 2
  SELECT cc.course_name AS first_course,
         LEAD(cc.course_name) OVER (PARTITION BY cc.user_id
                                    ORDER BY cc.completion_date, cc.course_id) AS second_course
  FROM course_completions cc
  JOIN top_users t ON t.user_id = cc.user_id
)
SELECT first_course, second_course, COUNT(*) AS transition_count     -- step 4
FROM transitions
WHERE second_course IS NOT NULL                                       -- step 3
GROUP BY first_course, second_course
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
```

This assembled query is approach 2 in section 5, the clearest decomposition. Approach 3 keeps steps 1, 3 and 4 and replaces step 2 with a `ROW_NUMBER` plus a join of position *n* to *n + 1*, which is faster in MySQL 8.0 for a reason explained there.

Self-check before you submit: take one top performer with 5 courses and confirm they contribute exactly 4 transitions. Then confirm a user with 4 perfect-rated courses contributes none.

## 5. Approaches: brute force → optimal

### Approach 1: direct successor by `NOT EXISTS` (`solutions/01_next_course_not_exists.sql`)

```sql
SELECT a.course_name AS first_course, b.course_name AS second_course, COUNT(*) AS transition_count
FROM course_completions a
JOIN course_completions b
  ON b.user_id = a.user_id
 AND (b.completion_date, b.course_id) > (a.completion_date, a.course_id)
WHERE a.user_id IN (SELECT user_id FROM course_completions
                    GROUP BY user_id HAVING COUNT(*) >= 5 AND SUM(course_rating) >= 4 * COUNT(course_rating))
  AND NOT EXISTS (SELECT 1 FROM course_completions c
                   WHERE c.user_id = a.user_id
                     AND (c.completion_date, c.course_id) > (a.completion_date, a.course_id)
                     AND (c.completion_date, c.course_id) < (b.completion_date, b.course_id))
GROUP BY a.course_name, b.course_name
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
```

**Why it is correct:** pair every completion A with every later completion B of the same user, and keep it only if no completion C lies strictly between them: then B is A's direct successor. This is the pre-window way of saying `LEAD`. The row-value comparison `(date, id) > (date, id)` implements the date-then-id order.

**Cost model (reasoned):** per user with *k* completions, the self-join builds about *k²/2* pairs and each is checked against up to *k* rows, so roughly *k³* work per user. Cheap for ordinary users (*k* ≈ 6), disastrous for a user with thousands of completions. The join and `NOT EXISTS` have no useful index by default (the primary key starts with `user_id`, so there is a lookup per user, but not by date).

### Approach 2: `LEAD` over the cohort (`solutions/02_lead_pairs.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `LEAD` returns, for every row, the next row's value within the same `PARTITION BY user_id` in `completion_date, course_id` order. The cohort join has already removed other users, and the `IS NOT NULL` filter removes each user's last course. The rest is a plain `GROUP BY`.

**Cost model (reasoned; the plan was checked with `EXPLAIN`):** one scan of `course_completions` for the cohort (aggregating by user), one scan joined to the cohort, one window sort by `(user_id, completion_date, course_id)`, and one small aggregation. There is no self-join, but to look one row ahead MySQL buffers rows: the plan shows `Window aggregate with buffering`, and the window output is materialised before the final filter. It is the clearest query, and the right shape in an engine where look-ahead is cheap.

### Approach 3 (optimal): `ROW_NUMBER`, then join row *n* to row *n + 1* (`solutions/03_row_number_self_join.sql`)

```sql
WITH top_users AS (...),                       -- same cohort as above
numbered AS (
  SELECT cc.user_id, cc.course_name,
         ROW_NUMBER() OVER (PARTITION BY cc.user_id ORDER BY cc.completion_date, cc.course_id) AS rn
  FROM course_completions cc JOIN top_users t ON t.user_id = cc.user_id
)
SELECT a.course_name AS first_course, b.course_name AS second_course, COUNT(*) AS transition_count
FROM numbered a JOIN numbered b ON b.user_id = a.user_id AND b.rn = a.rn + 1
GROUP BY a.course_name, b.course_name
ORDER BY transition_count DESC, first_course ASC, second_course ASC;
```

**Why it is correct:** numbering gives every completion its position in the user's history. Joining position *n* to *n + 1* of the same user pairs each course with its successor, and the last course has no *n + 1* partner, so it drops out of the inner join without any NULL handling.

**Cost model (reasoned; the plan was checked with `EXPLAIN`):** one window sort, then a join of the numbered result with itself on `(user_id, rn + 1)`. The join is 1:1 per position, so it is linear in the cohort's completions. The numbered CTE is referenced twice, so MySQL materialises it and joins through an auto-generated key (`<auto_key>` in the plan): an extra write and lookup structure. What it saves is the look-ahead buffer: `ROW_NUMBER` is evaluated as a stream (a plain `Window aggregate`), which in MySQL 8.0 costs less than the buffered `LEAD` of approach 2.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:27-most-common-course-pairs -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/27-most-common-course-pairs.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_next_course_not_exists` | 9.22 ms | 659 ms | 6.87 s | 2.5× |
| `02_lead_pairs` | 3.98 ms | 169 ms | 3.96 s | 1.4× |
| `03_row_number_self_join` (optimal) | 3.72 ms | 154 ms | 2.78 s | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_next_course_not_exists` | 9.28 ms | 656 ms | 6.76 s | 2.4× |
| `02_lead_pairs` | 3.95 ms | 173 ms | 3.92 s | 1.4× |
| `03_row_number_self_join` (optimal) | 3.56 ms | 154 ms | 2.76 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the sequencing with `ROW_NUMBER`, which MySQL evaluates as a stream, and then pairs positions *n* and *n + 1* with a 1:1 join. Approach 2 gets the same pairs from `LEAD` in one expression, but MySQL has to buffer rows to look ahead. Approach 1 does the same job by comparing every pair of a user's completions, so it grows with the cube of history length. Filtering the cohort *before* windowing keeps the sort to top performers' rows in both 2 and 3. Measured at 1M rows: approach 3 took 2.78 s, approach 2 3.96 s (1.4× slower), and approach 1 6.87 s (2.5× slower). Approach 1's *k³* growth stays mild here only because `gen.py` users have short histories. At 100K rows, 2 and 3 were within 10% of each other. The ranking of 2 and 3 is a statement about MySQL 8.0's window implementation, and `indexes.sql` changed none of the timings by more than a few percent. In an engine with cheap look-ahead, `LEAD` is the natural choice.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, because its work grows with the cube of a user's history length; a few heavy users dominate. Approaches 2 and 3 are dominated by the sort by `(user_id, completion_date, course_id)`, which is *n log n* and spills to disk when the cohort does not fit in memory; approach 2 additionally pays for the look-ahead buffer of `LEAD`.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds a covering index `(user_id, completion_date, course_id, course_rating, course_name)`. The cohort scan, the window input and the correlated lookups of approach 1 can all be served from it without touching the table rows. Whether the window skips its sort is up to the optimizer; check `EXPLAIN ANALYZE` in the bench output rather than assuming it.
- Filter the cohort first. The cohort query is cheap (one aggregate by `user_id`), and anything that shrinks the window's input is worth it. Computing the window over all users and filtering afterwards does strictly more work.
- Compare `SUM(course_rating) >= 4 * COUNT(course_rating)` rather than `AVG(...) >= 4`. They give the same answer for integer ratings, NULLs included, but the SUM form is exact and cannot be affected by how many decimal places a division keeps. Use `COUNT(course_rating)`, not `COUNT(*)`, on the right: `COUNT(*)` would count unrated courses as zeros.
- The final `GROUP BY` is over name pairs. With *C* distinct course names there are at most *C²* groups, so it is small whatever the table size.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffles:* the cohort `GROUP BY user_id` is a shuffle by `user_id`. The window `PARTITION BY user_id` needs the same partitioning, so a good plan reuses it; a cohort join that goes through a different distribution (for example a broadcast of `top_users`) leaves the window to re-shuffle by `user_id`. Then the pair aggregation is a third shuffle by `(first_course, second_course)`.
- *Partial aggregation:* `COUNT` is decomposable, so each task counts its local pairs first and shuffles at most one row per distinct pair per task. Because the pair space is small (≤ *C²*), the final shuffle is tiny. Without partial aggregation, every transition would cross the network.
- *Skew:* a handful of very popular pairs would make one reducer hot in a naive plan, and partial aggregation removes that. A user with an enormous history is the other skew risk: one partition must sort all of that user's rows.
- *Exact vs approximate:* this is an exact count of transitions, and counts of "most common pairs" that feed a dashboard could use a Count-Min sketch for heavy hitters. For anything audited or reported as a number, keep it exact. `COUNT(DISTINCT user_id)` per pair (a likely follow-up) is the expensive one: it can't be pre-aggregated into a single number per task.
- *Global sort:* the final `ORDER BY` is over the distinct pairs only (small), so it is cheap. Don't `ORDER BY` the transitions before aggregating.

**(d) The data-engineering answer.** Both the cohort and the pair counts change as users complete more courses, so a full recompute re-sorts all history. Keep a small state per user and update the counts by *delta*:

```sql
-- user_state(user_id PK, n_courses, rating_sum, is_top, last_date, last_course_id, last_course_name)
-- pair_counts(first_course, second_course, n, PRIMARY KEY (first_course, second_course))
-- New completions arrive in batches (assume each user's new rows are later than user_state.last_*;
-- late or back-dated data must trigger a rebuild of that user's transitions).
-- 1. Stitch each new completion to its predecessor, including the one stored in user_state:
--      new_transitions(user_id, first_course, second_course)
--        = LEAD within the batch  UNION ALL  (user_state.last_course_name, first new course of the user)
-- 2. Users whose is_top flips from false to true: add ALL their historical transitions.
--    Users whose is_top flips from true to false: SUBTRACT all of them (their average fell below 4).
-- 3. Users who stay top performers: add only their new transitions.
-- Snowflake / ANSI MERGE (UNVERIFIED) for the delta:
MERGE INTO pair_counts t
USING (SELECT first_course, second_course, SUM(delta) AS delta
       FROM pair_delta                               -- rows with delta = +1 / -1 from steps 2 and 3
       GROUP BY first_course, second_course) s
ON t.first_course = s.first_course AND t.second_course = s.second_course
WHEN MATCHED THEN UPDATE SET n = t.n + s.delta
WHEN NOT MATCHED AND s.delta > 0 THEN INSERT (first_course, second_course, n) VALUES (s.first_course, s.second_course, s.delta);
```

Caveats: a user crossing the 5-course or average-4 threshold changes counts for their *entire* history, not only for the new row, which is what makes this harder than a plain running counter. Delete counts that reach zero if the table must stay minimal. Re-applying a batch double-counts unless the batch id is recorded.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Two top performers share a pair; a third user has only 4 courses; one user's course ids run against date order | `tests/edge_typical.sql` | `no_user_partition` (pair spans two users), `no_cohort_filter`, `count_gt_5`, `order_by_course_id`, `unordered_pair`, `keep_null_successor`, `order_keys_wrong` |
| Exactly 5 courses with average exactly 4.0 (qualifies); average 3.8 (does not); 4 courses with average 5 (does not) | `tests/edge_thresholds.sql` | `avg_gt_4`, `count_gt_5`, `row_level_rating_filter`, `no_cohort_filter`, `keep_null_successor` |
| Unrated completions (NULL rating): they count as completions but not in the average; a user with no ratings at all is not a top performer | `tests/edge_null_rating.sql` | `null_rating_as_zero` (`SUM >= 4 * COUNT(*)` treats NULL as 0, so nobody qualifies) |
| Nobody qualifies (low average; too few courses) | `tests/edge_no_top_performers.sql` | `no_cohort_filter` |
| Two courses on the same date (tie-break by `course_id`) | `tests/edge_same_date.sql` | `tiebreak_by_name`, `count_gt_5` (only a 5-course user, so it also drops) |
| Output order and pair semantics: count ties broken by first then second course; A→B ≠ B→A; one name on two course ids; a pair of identical names | `tests/edge_ordering.sql` | `group_by_course_id`, `unordered_pair`, `order_keys_wrong`, `order_by_course_id`, `no_user_partition` |

The last course of each user has no successor and is excluded from the pairs: that is the NULL rule in the spec. It is exercised by every dataset with a top performer and caught by `keep_null_successor`.

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Only the top 3 pairs."** `LIMIT 3` cuts arbitrarily inside a tie on the count. If tied pairs should all be kept, rank the grouped result (`DENSE_RANK() OVER (ORDER BY transition_count DESC) <= 3`). Ask which one they mean.
2. **"Count users, not transitions."** A user could repeat a name pair (two editions of one course). Use `COUNT(DISTINCT user_id)` per pair. Mention that it cannot be pre-aggregated per task at scale (section 6c).
3. **"Triples: A→B→C."** Add `LEAD(course_name, 2)` to the same window and group by three columns. A self-join version needs two joins and gets worse as the length grows.
4. **"Why not filter by `course_rating >= 4`?"** That filters courses. It removes courses from the middle of a user's sequence and creates adjacencies that never happened. `mistakes/row_level_rating_filter.sql` shows it fails.
5. **"Two courses on the same day?"** The spec leaves it open. State the rule you picked (`course_id`), put it in the `ORDER BY`, and say that without a total order the result can change between runs.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses the `LEAD` form (approach 2), not the `ROW_NUMBER` join that is fastest in MySQL. The reason `LEAD` costs more in MySQL is a buffering detail of its window implementation; whether Snowflake has that cost is not known here (reasoned, unverified), and `LEAD` avoids the self-join and its extra shuffle on `(user_id, rn)`. What changes, and why:

- **String ordering differs.** Snowflake compares strings case-sensitively by default (code point order), where MySQL's default collation is case-insensitive. `'dbt'` sorts before `'Spark'` in MySQL but after it in Snowflake. The file adds `COLLATE 'en-ci'` to the two sort keys to match MySQL's behaviour.
- **No indexes.** `indexes.sql` has no equivalent. Pruning does not help because there is no filter on a raw column; the whole table is read once. A clustering key on `user_id` could keep each user's rows together and make the window sort cheaper, at a reclustering cost.
- **Cost shape:** one hash aggregation for the cohort, one distributed sort for the window, one small hash aggregation for the pairs. The sort on `(user_id, completion_date, course_id)` is parallel across partitions by `user_id`, which is better than a global sort.
- Unquoted identifiers are upper-cased in the result: `FIRST_COURSE`, `SECOND_COURSE`, `TRANSITION_COUNT`.

## 10. Pattern links

Same pattern (neighbour access with `LAG`/`LEAD`):
- `25-exchange-seats`: `LEAD`/`LAG` with a fallback for the missing neighbour.
- `26-find-consistently-improving-employees`: `LEAD` over the three most recent rows per group, with a strict-increase test.
- `31-consecutive-numbers`: `LEAD` twice for a run of three equal values.
- `38-find-students-with-study-spiral-pattern`: `LAG`/`LEAD` plus a sequence check per student.

Related:
- `05-find-loyal-customers`, `06-find-golden-hour-customers`: `HAVING`-based cohort filters before the main computation.
- `12-find-product-recommendation-pairs`, `13-find-category-recommendation-pairs`: counting pairs by `GROUP BY` on two columns, with the pair built by a self-join (unordered) rather than by adjacency.
