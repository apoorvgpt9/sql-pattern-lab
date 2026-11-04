# 11 · Analyze Subscription Conversion

## 1. Problem & trigger phrases

Original: [Analyze Subscription Conversion](https://leetcode.com/problems/analyze-subscription-conversion/) (LeetCode 3497, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** each row of `UserActivity` is one user's activity on one day, tagged `free_trial`, `paid` or `cancelled`, with a duration in minutes. A user has *converted* if they have at least one `free_trial` row and at least one `paid` row. For every converted user, report the average duration over their trial rows and over their paid rows, each rounded to 2 decimals, sorted by user. `cancelled` rows are ignored.

| Trigger phrase | What it forces in SQL |
|---|---|
| "converted from free trial to paid" | An existence test on **two specific values** of one column, per user. It is not "has more than one type" and it is not about dates (see Assumptions). With a pivot it falls out of NULLs: the average of a type the user never has is NULL, so "both averages are not NULL" means "has both". |
| "average daily activity duration during …" | `AVG(activity_duration)` restricted to one type, computed **twice per user** with different restrictions. Two restrictions on the same group are conditional aggregation: `AVG(CASE WHEN type = … THEN duration END)`. Each row is one day, so "average daily" is just the row average. |
| "rounded to 2 decimal places" | `ROUND(…, 2)` on the output, half away from zero for `DECIMAL`. Not `TRUNCATE`, not integer division. |

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `UserActivity` | one user on one day with one activity type | `user_id` (group key), `activity_type` (decides the bucket), `activity_duration` (the thing averaged). `activity_date` is not needed for the answer. |

**Output grain:** one row per converted user.

**Where the grain changes:** (user, day, type) → user, in one `GROUP BY user_id`, with the two types going **side by side** as two columns of that single row (the pivot). The second grain question is "which users survive": the users with a non-NULL average on both sides.

## Assumptions

Confidence is `high`; the spec leaves these points implicit.

1. **"Converted" does not look at dates.** The requirement says "users who have both free_trial and paid activity rows". A user whose paid rows come before their trial rows, or on the same day, counts. Tested in `tests/edge_date_order.sql`. If you read the title as "trial *then* paid", that is a different problem; `mistakes/paid_must_follow_trial.sql` shows what it changes.
2. **A user with a cancelled row can still be converted.** Cancelled rows are *ignored*, not disqualifying. Tested in `tests/edge_typical.sql` (user 4) and `tests/edge_date_order.sql` (user 3).
3. **Zero-minute days are real rows.** A day with duration 0 stays in the average. Tested in `tests/edge_rounding.sql`.
4. **Columns are NOT NULL** (spec: `nulls: n/a`), so there is no NULL-duration case to decide.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **pivot by conditional aggregation** with an "exists in both buckets" filter. One output row per user, two averages that come from different subsets of the same rows.

</details>

<details><summary>Hint 2</summary>

Shape: (1) throw away the rows that cannot matter (cancelled), (2) group by user and compute the trial average and the paid average in the same pass, (3) keep users where both averages exist, (4) round and sort.

</details>

<details><summary>Hint 3</summary>

Key clause: `AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END)` and the same for `'paid'`. A type the user lacks gives `AVG` over no rows, which is NULL, so `WHERE t IS NOT NULL AND p IS NOT NULL` is the whole "converted" test. Do not use `COUNT(DISTINCT activity_type) >= 2`: cancelled counts as a type.

</details>

## 4. Decomposition

Read the output: `user_id` plus two averages. The averages are the same function over two different slices of each user's rows.

1. **Filter: keep only `free_trial` and `paid` rows.**
   *Why a filter here:* "cancelled rows are ignored". Dropping them first removes a third value that could otherwise sneak into an `ELSE` branch or into a distinct-type count. It only restricts rows; it does not change the grain.
2. **`per_user`: `GROUP BY user_id` with two `AVG(CASE …)` columns.**
   *Why a GROUP BY with conditional aggregation:* both averages must land on the same row, so both are computed in the same group. A `WHERE type = 'free_trial'` would remove the rows the paid average needs. This is the grain change (day → user) and the pivot in one step.
3. **Filter: `WHERE t IS NOT NULL AND p IS NOT NULL`.**
   *Why a NULL test and not a count of types:* "converted" is "has a trial row **and** a paid row". Each average is non-NULL exactly when its type exists for that user, so the test is exact and needs no second pass.
4. **`ROUND(…, 2)` and `ORDER BY user_id`.**
   *Why last:* rounding is presentation. The filter in step 3 must see the unrounded values, and the sort is on the integer id.

Assembled (this is `solutions/03_conditional_aggregation.sql`):

```sql
WITH per_user AS (
  SELECT user_id,                                                    -- step 2: day grain -> user grain, pivoted
         AVG(CASE WHEN activity_type = 'free_trial' THEN activity_duration END) AS t,
         AVG(CASE WHEN activity_type = 'paid'       THEN activity_duration END) AS p
  FROM UserActivity
  WHERE activity_type IN ('free_trial', 'paid')                      -- step 1: cancelled never gets in
  GROUP BY user_id
)
SELECT user_id, ROUND(t, 2) AS trial_avg_duration, ROUND(p, 2) AS paid_avg_duration
FROM per_user
WHERE t IS NOT NULL AND p IS NOT NULL                                -- step 3: has both
ORDER BY user_id;                                                    -- step 4
```

Self-check: choose one output user and recompute both averages from their raw rows by hand. Choose one user who has a trial row and a cancelled row but no paid row, and confirm they are absent.

## 5. Approaches: brute force → optimal

### Approach 1: two scalar subqueries per user (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT x.user_id, ROUND(x.t, 2) AS trial_avg_duration, ROUND(x.p, 2) AS paid_avg_duration
FROM (SELECT u.user_id,
             (SELECT AVG(a.activity_duration) FROM UserActivity a
               WHERE a.user_id = u.user_id AND a.activity_type = 'free_trial') AS t,
             (SELECT AVG(a.activity_duration) FROM UserActivity a
               WHERE a.user_id = u.user_id AND a.activity_type = 'paid')       AS p
      FROM (SELECT DISTINCT user_id FROM UserActivity) u) x
WHERE x.t IS NOT NULL AND x.p IS NOT NULL
ORDER BY x.user_id;
```

**Why it is correct:** the outer list is every user in the table, once. Each subquery is the spec's sentence for one type, and it returns NULL when the user has no such rows, so the `WHERE` keeps exactly the users with both. Cancelled rows are never selected. It is the most natural first attempt because the question is phrased per user.

**Cost model (reasoned):** the two subqueries run per user. The table's primary key starts with `user_id`, so each run can seek straight to one user's rows rather than scan the table; it then reads all of that user's rows (every type, every day) and filters on the type. The total is roughly 2 × rows plus 2 × users index seeks. With the `indexes.sql` index `(user_id, activity_type, activity_duration)` each run reads only the one type's entries.

### Approach 2: two aggregates joined (`solutions/02_join_two_aggregates.sql`)

```sql
WITH trial AS (SELECT user_id, AVG(activity_duration) AS avg_dur FROM UserActivity WHERE activity_type = 'free_trial' GROUP BY user_id),
     paid  AS (SELECT user_id, AVG(activity_duration) AS avg_dur FROM UserActivity WHERE activity_type = 'paid'       GROUP BY user_id)
SELECT t.user_id, ROUND(t.avg_dur, 2) AS trial_avg_duration, ROUND(p.avg_dur, 2) AS paid_avg_duration
FROM trial t JOIN paid p ON p.user_id = t.user_id
ORDER BY t.user_id;
```

**Why it is correct:** each CTE has one row per user who has that type. The **inner** join keeps a user only if they appear in both, which is the definition of converted. Both sides are at user grain, so the join is 1:1. Turn it into a `LEFT JOIN` and trial-only users return with a NULL paid average (`mistakes/left_join_keeps_unconverted.sql`).

**Cost model (reasoned):** two scans of the table (each reads only its own type's rows, so together they read each relevant row once) and a join between two user-grain results. Linear in rows. The cost is the second pass plus the join.

### Approach 3 (optimal): one pass, conditional aggregation (`solutions/03_conditional_aggregation.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** one group per user; two `AVG(CASE …)` columns that each look at one type only; NULL exactly where that type is absent; the `WHERE … IS NOT NULL` pair is the conversion test. The initial `IN ('free_trial', 'paid')` guarantees cancelled rows are not averaged.

**Cost model (reasoned):** one scan, one aggregation keyed by `user_id` holding two running sums and two counts per user. The table's primary key is ordered by `user_id`, so the scan arrives user by user and MySQL can often aggregate without a temporary table; with `indexes.sql` that is true for a covering secondary index as well, and it skips the `activity_date` column entirely.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:11-analyze-subscription-conversion -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/11-analyze-subscription-conversion.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 1.61 ms | 95.7 ms | 968 ms | 1.7× |
| `02_join_two_aggregates` | 1.18 ms | 64.2 ms | 643 ms | 1.1× |
| `03_conditional_aggregation` (optimal) | 1.13 ms | 58.8 ms | 585 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 1.38 ms | 97.7 ms | 987 ms | 1.7× |
| `02_join_two_aggregates` | 1.22 ms | 61.1 ms | 607 ms | 1.1× |
| `03_conditional_aggregation` (optimal) | 1.09 ms | 56.9 ms | 564 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 asks both questions of each user's rows while it already holds them, so conversion needs no join and no second scan. The "has both types" test is a by-product of the NULL semantics of `AVG`, which makes it hard to get wrong. Approaches 1 and 2 reach the same answer by splitting and re-matching. Because `AVG` is decomposable (a sum and a count), approach 3 is also the form that scales out (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, because of users × rows when users and rows grow together, and it is the one most sensitive to which index exists. Approach 2 degrades with its second scan and its join. Approach 3 degrades last.

**(b) One machine, ~1M–100M rows.**
- The primary key `(user_id, activity_date, activity_type)` already clusters each user's rows, which helps every approach. It does not group by type within a user, and it makes each row carry `activity_date`, which this query never reads.
- `indexes.sql` adds `(user_id, activity_type, activity_duration)`. It is *covering*, narrower than the clustered row, and keeps each user's trial rows contiguous and paid rows contiguous. It turns approach 1's subqueries into two short ranges and lets approach 3 stream.
- The `activity_type` filter is a handful of distinct values, so on its own it is not selective. Low-cardinality columns only pay off as the *second* column behind `user_id`.
- Do not "pre-filter" with `activity_type <> 'cancelled'`: an `IN` list of the wanted values is explicit and survives a new type being added later.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* `AVG` is `SUM/COUNT`, so each task computes per-user partial sums and counts for each type and only those move across the network, keyed by `user_id`. Approach 2 shuffles twice, once per type, before the join.
- *Skew:* a bot or test account with a huge number of rows would overload one reducer in a plan that shuffles raw rows. Partial aggregation reduces it to one row per task. This relies on the engine doing a map-side combine for `AVG`, which Spark-style engines do.
- *Distinct counts:* none here. Counting types with `COUNT(DISTINCT activity_type)` is the wrong test (see Edge cases), and it would also be a needless distinct aggregate.
- *Pruning:* `activity_date` is not filtered, so date pruning does nothing for this query. A "converted in the last 30 days" variant would prune.
- *Approximate functions:* not appropriate. The averages are exact and cheap, and users will check them.

**(d) The data-engineering answer.** Averages are not additive, but sum and count are. Maintain per-user, per-type sums and counts and derive the averages on read:

```sql
-- user_type_stats(user_id, activity_type, sum_dur BIGINT, n_rows BIGINT, PRIMARY KEY (user_id, activity_type))
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO user_type_stats t
USING (SELECT user_id, activity_type, SUM(activity_duration) AS sum_dur, COUNT(*) AS n_rows
       FROM activity_batch                       -- rows not yet applied (by arrival watermark)
       WHERE activity_type IN ('free_trial', 'paid')
       GROUP BY user_id, activity_type) s
ON t.user_id = s.user_id AND t.activity_type = s.activity_type
WHEN MATCHED THEN UPDATE SET sum_dur = t.sum_dur + s.sum_dur, n_rows = t.n_rows + s.n_rows
WHEN NOT MATCHED THEN INSERT (user_id, activity_type, sum_dur, n_rows) VALUES (s.user_id, s.activity_type, s.sum_dur, s.n_rows);

-- Read side: a user has converted exactly when both rows exist.
SELECT a.user_id, ROUND(a.sum_dur / a.n_rows, 2) AS trial_avg_duration, ROUND(b.sum_dur / b.n_rows, 2) AS paid_avg_duration
FROM user_type_stats a
JOIN user_type_stats b ON b.user_id = a.user_id AND b.activity_type = 'paid'
WHERE a.activity_type = 'free_trial'
ORDER BY a.user_id;
```

Caveats interviewers probe. *Idempotency*: applying a batch twice double-counts, so keep a watermark. *Corrections*: a corrected duration needs the old value subtracted. *Late arrivals*: no problem, since the stats are keyed by user and type, not by date. *Why the table is better than a view*: reads touch two rows per user instead of every activity day.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Cancelled rows among a converted user's rows (value 999) | `tests/edge_typical.sql`, `tests/edge_date_order.sql` | `else_is_paid` (cancelled leaks into the paid mean), `exclude_users_who_cancelled` (converted users removed) |
| Trial-only, paid-only and cancelled-only users | `tests/edge_typical.sql`, `tests/edge_no_conversion.sql` | `left_join_keeps_unconverted` (NULL paid average) |
| Users with two different types that are not trial + paid (trial + cancelled, paid + cancelled) | `tests/edge_no_conversion.sql` | `distinct_types_ge_2` |
| Average that needs rounding: 23/3 = 7.6667; exactly 1/8 = 0.125 | `tests/edge_typical.sql`, `tests/edge_rounding.sql` | `truncate_instead_of_round` |
| Zero-minute days inside an average | `tests/edge_rounding.sql` | none of these mistakes (a `WHERE activity_duration > 0` clean-up would break it) |
| Paid before trial; trial and paid on the same day | `tests/edge_date_order.sql` | `paid_must_follow_trial` |
| Ids that sort differently as text and as numbers (7, 20, 30, 100) | `tests/edge_ordering.sql` | `order_by_text` |
| Empty table | `tests/edge_empty.sql` | none |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Only count a conversion if the paid row comes after the trial."** Now dates matter: keep users where `MIN(CASE WHEN paid THEN date END) > MIN(CASE WHEN trial THEN date END)` (or compare the first paid date with the last trial date, depending on what "after" should mean; clarify). It stays a single pass. `mistakes/paid_must_follow_trial.sql` is exactly this, and it changes the answer.
2. **"Also give me the number of days to convert."** `DATEDIFF(first_paid_date, first_trial_date)` from two more conditional aggregates in the same `GROUP BY`. If the answer is negative for some users, that is your data-quality finding.
3. **"Why not `HAVING COUNT(DISTINCT activity_type) = 2`?"** Because the type column has three values. Trial + cancelled also has two distinct types and is not a conversion. Counting the *specific* values you need (`COUNT(CASE WHEN … THEN 1 END)`, or the NULL averages) is the right test; relational division (`14-customers-who-bought-all-products`) is the general version.
4. **"The average should be per week, not per row."** Then "daily" matters and rows per week vary: sum durations per (user, type, week) first, then average the weekly totals. Decide what to do with weeks that have no rows; that decision is a scaffold problem (`09-count-salary-categories`).
5. **"How would you do this if activity types were not known in advance?"** You cannot pivot to an unknown number of columns in plain SQL. Return the long form `(user_id, activity_type, avg)` and let the consumer pivot, or generate the SQL.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3, with one difference in how "has both" is expressed:

- `IFF(cond, x, NULL)` replaces `CASE`; `COUNT_IF(cond)` gives a direct existence count, so the filter is `HAVING COUNT_IF(type = 'free_trial') > 0 AND COUNT_IF(type = 'paid') > 0`. It is closer to the wording than a NULL test, and equivalent here because the duration column is NOT NULL.
- With a nullable duration the two forms diverge: a type present with only NULL durations has an average of NULL but a count above 0. Pick the form that matches the spec's meaning of "has a row".
- `AVG` on `NUMBER` yields a `NUMBER` with extra scale, then `ROUND`; this should match MySQL for the spec's exact cases, but confirm the 0.125 → 0.13 case on Snowflake.
- No indexes; the primary key is metadata only. Cost is bytes scanned, and the query reads three of the four columns. `indexes.sql` has no equivalent.
- String comparison on `activity_type` is case-sensitive by default in Snowflake; in the MySQL default collation (`utf8mb4_0900_ai_ci`) it is not. Quote the exact spelling in both.
- Unquoted identifiers are upper-cased in the output.

## 10. Pattern links

Same pattern (pivot with conditional aggregation, plus a "both buckets present" filter):
- `08-odd-and-even-transactions`: the basic pivot, with `ELSE 0` instead of NULL.
- `10-find-drivers-with-improved-fuel-efficiency`: two pivoted averages, then a comparison.
- `04-monthly-transactions-i`: several conditional aggregates per group.

Related ("has all of a required set"):
- `14-customers-who-bought-all-products`: relational division; the generalisation of "has both types".
- `15-employees-qualified-for-every-required-skill-of-a-role`: division per group.
