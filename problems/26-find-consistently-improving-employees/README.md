# 26 · Find Consistently Improving Employees

## 1. Problem & trigger phrases

Original: [Find Consistently Improving Employees](https://leetcode.com/problems/find-consistently-improving-employees/) (LeetCode 3580, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** consider only employees with at least three performance reviews. Take each one's three most recent reviews by date. If, going from the oldest of those three to the newest, every rating is strictly higher than the one before, report the employee with `improvement_score` = newest rating − oldest rating. Sort by score (high first), then by name.

| Trigger phrase | What it forces in SQL |
|---|---|
| "last three reviews" | A top-N-per-group: number each employee's reviews newest first (`ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC)`) and keep `rn <= 3`. Only the *recent* history counts, so older reviews must not influence the test. |
| "strictly increasing ratings" | A comparison between adjacent rows inside that group of three: `LAG`/`LEAD`, or a self-join on `rn`. "Strictly" means `>`; an equal step disqualifies. |
| "at least 3 review" | A guard on group size. A group with fewer than 3 rows must produce no output, and the window has to make "no third review" visible (`LEAD(.., 2)` is NULL; `COUNT(*) = 3` after the filter). |
| "latest rating and the earliest rating among" | A pivot of the three rows into one: the score is `rating(rn=1) − rating(rn=3)`. With `LEAD` on the newest row, or conditional aggregation, the three values end up in one row. |

Also notice what is **not** in the wording: the output is one row per *employee*, so the three-row groups must collapse. The employee's `name` lives in `employees`, so a join is needed at the end.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `employees` | one employee | `employee_id` (PK), `name` |
| `performance_reviews` | one review | `employee_id`, `review_date`, `rating`; `review_id` is a key, **not** a timeline |

**Output grain:** one row per qualifying employee. Every employee has at most one row, and an employee with an improvement streak never appears twice.

**Where the grain changes:** reviews are at review grain (many per employee), and the answer is at employee grain. The query goes review → *3 reviews per employee* (window + filter) → *1 row per employee* (pivot with `LEAD` or conditional aggregation). Bugs come from testing the wrong set of reviews (all history, or the oldest three) and from letting employees with too few reviews through.

`performance_reviews` has no foreign key to `employees`. A review for an unknown employee has no name to report, so those reviews never produce output (`edge_typical` has one).

## Assumptions

The spec marks one situation as not addressed: **two reviews of the same employee on the same date**. Then "the three most recent" is ambiguous. Our interpretation: break the tie by `review_id`, so the larger `review_id` is the more recent review. Every solution orders by `review_date DESC, review_id DESC`. This is tested in `tests/edge_same_date.sql` and the opposite tie-break is shown to fail in `mistakes/tiebreak_wrong_direction.sql`. If you use a different rule in an interview, say what it is: the point is that you picked one deliberately.

Other readings, fixed by the spec and not by us: ratings are not NULL; employees without a row in `employees` are not reported (the output needs a name).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **top-N per group, then neighbour comparison** (`ROW_NUMBER` / `LAG` / `LEAD`). Restrict each employee to a short, ordered sequence, and then ask a yes/no question about consecutive elements of it.

</details>

<details><summary>Hint 2</summary>

Shape: (1) order each employee's reviews newest first. (2) For the newest review, look at the next two older ratings. (3) Keep an employee only if both older ratings exist and the three ratings strictly fall as you go back in time. (4) Join to `employees`, compute the score, sort.

</details>

<details><summary>Hint 3</summary>

Key trick: put `LEAD(rating, 1)` and `LEAD(rating, 2)` on the same window (`PARTITION BY employee_id ORDER BY review_date DESC`) and keep only the newest row (`ROW_NUMBER() = 1`). That row now holds all three ratings, a missing third review shows up as `LEAD(.., 2) IS NULL`, and the score is `rating − LEAD(rating, 2)`. Add `review_id DESC` to the window order so same-day reviews have a defined order. An equivalent route without look-ahead: rank with `ROW_NUMBER`, keep `rn <= 3`, and pivot the three rows with conditional aggregation (approach 3).

</details>

## 4. Decomposition

Read the wording as three nested questions: *which* reviews (the last three), *what test* on them (strictly increasing), *what to report* (newest minus oldest).

1. **`latest`: number and look ahead within each employee, newest first.**
   *Why a window here:* "last three" is relative to each employee's own history, so the ordering and the counting restart per employee: `PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC`. A plain `GROUP BY` cannot rank rows. `LEAD(rating, 1)` and `LEAD(rating, 2)` fetch the next two older ratings without a self-join.
2. **Keep one row per employee: the newest review (`rn = 1`).**
   *Why a filter here:* after step 1 that single row carries all three ratings (`newest`, `middle`, `oldest`). The other rows are redundant, and keeping them would produce one output row per review.
3. **Apply the rule: `oldest IS NOT NULL AND newest > middle AND middle > oldest`.**
   *Why a filter here:* `oldest IS NOT NULL` is the "at least 3 reviews" rule, and the two `>` comparisons are "strictly increasing" read from oldest to newest. `>` rather than `>=`, because an equal step disqualifies.
4. **Join `employees` and compute `newest − oldest`.**
   *Why a join here:* only the employee table has the name. Joining *after* the filter keeps the join small, one row per candidate.
5. **`ORDER BY improvement_score DESC, name ASC`.**
   *Why an ORDER BY here:* the spec defines the order. The name is only the tie-break, so it comes second.

Assembled:

```sql
WITH latest AS (
  SELECT employee_id,
         rating                  AS newest,                 -- step 1
         LEAD(rating, 1) OVER w  AS middle,
         LEAD(rating, 2) OVER w  AS oldest,
         ROW_NUMBER()    OVER w  AS rn
  FROM performance_reviews
  WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC)
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score   -- step 4
FROM latest l
JOIN employees e ON e.employee_id = l.employee_id
WHERE l.rn = 1                                                        -- step 2
  AND l.oldest IS NOT NULL AND l.newest > l.middle AND l.middle > l.oldest   -- step 3
ORDER BY improvement_score DESC, e.name ASC;                          -- step 5
```

This assembled query is approach 2 in section 5. It is the clearest decomposition. Approach 3 keeps the same logic but swaps steps 1 and 2: it ranks with `ROW_NUMBER`, keeps `rn <= 3`, and pivots those three rows into one with conditional aggregation, which is faster in MySQL 8.0 for a reason explained there.

Self-check before you submit: pick an employee with five reviews and confirm by hand that you looked at the newest three, not the first three. Then pick one with exactly two reviews and confirm they are absent.

## 5. Approaches: brute force → optimal

### Approach 1: rank by counting newer reviews, then self-join (`solutions/01_correlated_rank_self_join.sql`)

```sql
WITH ranked AS (
  SELECT r.employee_id, r.rating,
         1 + (SELECT COUNT(*) FROM performance_reviews x
               WHERE x.employee_id = r.employee_id
                 AND (x.review_date > r.review_date
                      OR (x.review_date = r.review_date AND x.review_id > r.review_id))) AS rn
  FROM performance_reviews r
)
SELECT e.employee_id, e.name, r1.rating - r3.rating AS improvement_score
FROM employees e
JOIN ranked r1 ON r1.employee_id = e.employee_id AND r1.rn = 1
JOIN ranked r2 ON r2.employee_id = e.employee_id AND r2.rn = 2
JOIN ranked r3 ON r3.employee_id = e.employee_id AND r3.rn = 3
WHERE r1.rating > r2.rating AND r2.rating > r3.rating
ORDER BY improvement_score DESC, e.name ASC;
```

**Why it is correct:** the correlated count is the pre-window way to say `ROW_NUMBER() ... DESC`: a review's rank is 1 plus the number of reviews newer than it. The three inner joins find rank 1, 2 and 3; an employee with fewer than three reviews has no rank-3 row, so the inner join removes them.

**Cost model (reasoned):** the rank subquery runs once per review and scans that employee's reviews, so without an index it is reviews × reviews. That is quadratic overall, and it is the part that blows up first. The three joins on the materialised `ranked` result are cheap in comparison. With `indexes.sql` each count becomes a covering index range read of one employee's newer reviews (confirmed in `EXPLAIN` on generated data).

### Approach 2: `LEAD` on the newest review (`solutions/02_lead_on_newest.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** with the window ordered newest first, `LEAD(rating, 1)` is the next-older review and `LEAD(rating, 2)` is the one before that. On each employee's newest review (`rn = 1`) these are exactly the middle and oldest of the last three. `LEAD(.., 2)` is NULL when there are fewer than three reviews, so the "at least 3" rule falls out of the same expression.

**Cost model (reasoned; the plan was checked with `EXPLAIN`):** one window pass over the table, with no self-joins and no aggregation. But to look ahead, MySQL has to buffer rows: the plan shows `Window aggregate with buffering`, and all three window functions are evaluated for every review, including the ones that are then thrown away by `rn = 1`. The derived table holding those results is materialised before the filter. It is the clearest query and the right shape in an engine where look-ahead is cheap; in MySQL 8.0 the buffering is its cost.

### Approach 3 (optimal): `ROW_NUMBER`, keep three, pivot (`solutions/03_row_number_pivot.sql`)

```sql
WITH ranked AS (
  SELECT employee_id, rating,
         ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC) AS rn
  FROM performance_reviews
),
last3 AS (
  SELECT employee_id, COUNT(*) AS n,
         MAX(CASE WHEN rn = 1 THEN rating END) AS newest,
         MAX(CASE WHEN rn = 2 THEN rating END) AS middle,
         MAX(CASE WHEN rn = 3 THEN rating END) AS oldest
  FROM ranked WHERE rn <= 3 GROUP BY employee_id
)
SELECT e.employee_id, e.name, l.newest - l.oldest AS improvement_score
FROM last3 l JOIN employees e ON e.employee_id = l.employee_id
WHERE l.n = 3 AND l.newest > l.middle AND l.middle > l.oldest
ORDER BY improvement_score DESC, e.name ASC;
```

**Why it is correct:** the window ranks each employee's reviews newest first. `rn <= 3` keeps the most recent three. Conditional aggregation collapses those rows into one (newest / middle / oldest), and `n = 3` is the "at least 3 reviews" rule. Compared with approach 2, the neighbour access is replaced by position: instead of asking "what is the next-older rating?", the query asks "which rating has rank 2?".

**Cost model (reasoned; the plan was checked with `EXPLAIN`):** one sort of all reviews by (employee, date) for the window, then a `GROUP BY` over at most three rows per employee. `ROW_NUMBER` is evaluated as a stream: the plan shows a plain `Window aggregate`, without the look-ahead buffer of approach 2. The rows surviving `rn <= 3` are few, so the aggregation and the join to `employees` are small. The window still ranks every review, including the ones about to be discarded; that is the shared cost of 2 and 3.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:26-find-consistently-improving-employees -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 turns the problem into "rank, cut, pivot": a streaming `ROW_NUMBER`, a filter that leaves three rows per employee, and a tiny aggregation. Approach 2 expresses the same thing with neighbour access, which is shorter, but in MySQL 8.0 it needs a buffered window. Approach 1 shows what `ROW_NUMBER` replaces: a correlated count that rescans the table per row. This ranking is a statement about MySQL's window implementation: the bench table is the evidence, and in an engine without that buffering cost approach 2 may well be as fast, so the choice depends on the engine.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 breaks first, because its rank subquery rescans an employee's reviews once per review, which without an index means a scan of the whole table per row. Approaches 2 and 3 are dominated by sorting all reviews by (employee, date), which is *n log n* and spills to disk when the table does not fit in memory; approach 2 additionally pays for the look-ahead buffer of its `LEAD` windows.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `performance_reviews (employee_id, review_date, rating)`. It is *covering* (`review_id` is the InnoDB primary key and is stored in every secondary index entry), so no query touches the table rows. It makes approach 1's counts covering index range reads, and gives the windows in 2 and 3 a narrow index to scan instead of the table. It did not remove the window's sort in the `EXPLAIN` checks run while writing this guide (ascending or descending index), so don't promise a sort-free plan. The bench runs every approach with and without it.
- MySQL cannot stop a window early, so even though only three reviews per employee matter, the window function visits every review. If most employees have long histories, a rewrite that fetches the top three per employee with a `LATERAL` join or a per-employee `LIMIT 3` can read far fewer rows (reasoned, not implemented here, as it needs the employee list as the driver).
- Do not filter by date before ranking (for example "reviews in the last year") unless the spec says so: it changes which three reviews count.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `PARTITION BY employee_id` is a hash shuffle on `employee_id`, followed by a local sort within each partition. All reviews of one employee land on one task. That is the cost of any per-group window, and the skew risk is an employee with millions of reviews (a service account or test user). Few real employees have that many.
- *Early reduction:* in a Spark-style engine, a rank filter (`rn <= 3`) cannot be pushed below the shuffle, so every review is shuffled even though only three per employee survive. The engine can partially reduce first with a per-partition top-3 before the shuffle (a "top-N per key" combiner) if the plan is written as `groupBy` + `sort_array(collect_list(struct(date, rating)))[0:3]` or equivalent. SQL-only plans often miss this.
- *Snowflake:* `QUALIFY ROW_NUMBER() ... = 1` (the form in `snowflake.sql`) avoids an extra subquery layer. Micro-partition pruning does not help because there is no date predicate, and the whole table is read once.
- *Things to avoid:* `COUNT(DISTINCT ...)` is not needed here, and a global `ORDER BY` of the final result is on a small set (one row per qualifying employee), so it is cheap.

**(d) The data-engineering answer.** An employee's status depends only on their last three reviews, which is tiny state. Keep that state and update it as reviews arrive instead of re-ranking all history:

```sql
-- employee_last3(employee_id PRIMARY KEY, r1_date, r1_id, r1_rating, r2_rating, r3_rating): the newest three reviews.
-- Late or back-dated reviews are the catch: a review that is not newer than r3 must be ignored, and one that
-- lands between existing ones shifts the others. The safe incremental unit is "recompute the affected employees":
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO employee_status t
USING (
  SELECT employee_id, newest, middle, oldest FROM (
    SELECT employee_id, rating AS newest,
           LEAD(rating, 1) OVER w AS middle, LEAD(rating, 2) OVER w AS oldest,
           ROW_NUMBER() OVER w AS rn
    FROM performance_reviews
    WHERE employee_id IN (SELECT DISTINCT employee_id FROM review_batch)    -- only employees touched by the batch
    WINDOW w AS (PARTITION BY employee_id ORDER BY review_date DESC, review_id DESC)
  ) WHERE rn = 1
) s
ON t.employee_id = s.employee_id
WHEN MATCHED THEN UPDATE SET newest = s.newest, middle = s.middle, oldest = s.oldest
WHEN NOT MATCHED THEN INSERT (employee_id, newest, middle, oldest) VALUES (s.employee_id, s.newest, s.middle, s.oldest);
-- The report is then: SELECT ... FROM employee_status JOIN employees WHERE oldest IS NOT NULL AND newest > middle AND middle > oldest.
```

Caveats: the per-employee recompute still reads that employee's full history, so index `(employee_id, review_date)` or keep the last three in the state table. Re-running the same batch is harmless because the recompute is a function of the data, not of the batch (idempotent). Deleting or correcting a review must also put its employee in the batch.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| 3 rising reviews, one dip, an unknown employee id | `tests/edge_typical.sql` | `endpoints_only` (Carol 4,3,5 slips through), `order_keys_swapped` |
| 0, 1, 2 reviews (even rising ones) vs exactly 3 | `tests/edge_fewer_than_three.sql` | `missing_min_count` (the 2-review employee is reported) |
| Longer history: only the newest three count; old dip is irrelevant; first three rise but last three do not | `tests/edge_last_three_only.sql` | `first_three_reviews`, `all_reviews_must_rise`, `endpoints_only` |
| Equal consecutive ratings (including a flat start, a flat end and all equal) | `tests/edge_equal_ratings.sql` | `non_strict_steps` (>=), `endpoints_only` |
| `review_id` order is the reverse of date order | `tests/edge_review_order.sql` | `order_by_review_id` |
| Two reviews on the same date (our tie-break, see Assumptions) | `tests/edge_same_date.sql` | `tiebreak_wrong_direction` |
| Output order: score ties broken by name; insertion order is neither | `tests/edge_ordering.sql` | `order_keys_swapped` |
| No reviews at all | `tests/edge_no_reviews.sql` | none; every approach returns empty |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Make the number of reviews a parameter N."** Replace `LEAD(.., 2)` with a check over N rows: `ROW_NUMBER() <= N`, `COUNT(*) = N` after the filter, and `MIN(rating > next_rating)` over the group using `LAG`. `LEAD(.., k)` gets unwieldy beyond a handful of offsets, and the aggregate form takes any N.
2. **"Allow equal ratings (non-decreasing)."** Change both `>` to `>=`. The score is unchanged. Say that this is a different business rule, not a bug fix.
3. **"Two reviews on one date: what then?"** The spec does not say. State a tie-break (`review_id`), put it in the window order, and mention that without it the result can change between runs.
4. **"Only count reviews from the last 12 months."** Filter *before* ranking (`WHERE review_date >= ...`) if "last three" should mean the last three within the year, and filter *after* ranking if it should mean: of the last three overall, all must be recent. Those are different answers.
5. **"Why not just compare the newest and oldest rating?"** Because a dip in the middle (4,3,5) passes that test. `mistakes/endpoints_only.sql` demonstrates it.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` uses the single-pass `LEAD` form (approach 2), not the `ROW_NUMBER` pivot that is fastest in MySQL. The reason `LEAD` is slower in MySQL is a buffering detail of MySQL's window implementation; whether Snowflake has the same cost is not known here (reasoned, unverified), and `LEAD` with `QUALIFY` is the shorter query there. What changes, and why:

- **`QUALIFY ROW_NUMBER() OVER (...) = 1`** replaces the extra subquery layer that filters on `rn`, so the query is one level flatter.
- **No named `WINDOW` clause** (as far as we know): the window spec is repeated for each function. The optimizer should still treat identical specs as one window.
- No secondary indexes, so `indexes.sql` has no equivalent. A clustering key on `(employee_id, review_date)` can make the window's sort cheaper for a very large table, at a reclustering cost.
- Without a date predicate there is nothing to prune; the whole table is scanned once. The cost model is "one scan + one distributed sort by `employee_id`".
- Unquoted identifiers are upper-cased in the result: `EMPLOYEE_ID`, `NAME`, `IMPROVEMENT_SCORE`.

## 10. Pattern links

Same pattern (neighbour access with `LAG`/`LEAD`):
- `25-exchange-seats`: `LEAD`/`LAG` with a fallback for the missing neighbour.
- `27-most-common-course-pairs`: `LEAD` inside a pre-filtered cohort to build adjacent pairs.
- `31-consecutive-numbers`: `LEAD` twice for a run of three equal values.
- `38-find-students-with-study-spiral-pattern`: `LAG`/`LEAD` plus a cyclic sequence check.

Related:
- `19-department-top-three-salaries` and `16-department-highest-salary`: top-N per group with `DENSE_RANK`, the "keep N rows per group" half of this problem.
- `22-find-students-who-improved`: first and last per group, then compare, the same "pivot a group into one row" step.
