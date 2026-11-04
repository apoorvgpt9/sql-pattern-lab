# 02 · Confirmation Rate

## 1. Problem & trigger phrases

Original: [Confirmation Rate](https://leetcode.com/problems/confirmation-rate/) (LeetCode 1934, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** one output row per signed-up user: their id and the share of their confirmation requests that ended as `confirmed`, rounded to 2 decimals. A user who never made a request gets 0.00.

| Trigger phrase | What it forces in SQL |
|---|---|
| "each user" | The output grain is `Signups`. Drive the query from `Signups` and keep every row: `Signups LEFT JOIN …`, or a scalar subquery per user. A user missing from the output is a wrong answer. |
| "did not request any … is 0" | The LEFT JOIN yields one all-NULL row for such a user, and a ratio over it is NULL (or, with `COUNT(*)`, a misleading 1 in the denominator). You must turn "no data" into 0 explicitly: `IFNULL` / `COALESCE`. |
| "confirmed divided by total requests" | A ratio of two counts over the **same rows**, in one pass: `AVG(action = 'confirmed')`, or `SUM(action = 'confirmed') / COUNT(*)`. This is conditional aggregation; do not filter to `confirmed` first, or the denominator disappears with the rows. |

What is **not** in the wording: timestamps. `time_stamp` is only part of the key, and no window or ordering is involved.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Signups` | one user | `user_id` (PK) |
| `Confirmations` | one confirmation request by a user | `user_id`; PK is `(user_id, time_stamp)`; `action` is `confirmed` or `timeout` |

**Output grain:** one row per `Signups` row. Sanity check: the output row count equals `SELECT COUNT(*) FROM Signups`, whatever is in `Confirmations`.

**Where the grain changes:** `Confirmations` is at request grain; the answer is at user grain. The query has to collapse requests to one row per user (a `GROUP BY user_id` or a per-user subquery), attach that to `Signups`, and compute the ratio from two numbers at the *same* grain.

- **Join first, then group** (approach 2): the joined rows are at request grain, and a user without requests is one row with `Confirmations` columns NULL. That row is why the zero case needs `IFNULL`.
- **Group first, then join** (approach 3): the CTE is already at user grain, so the join is 1:1 and cannot duplicate or drop users.

`Confirmations` has no foreign key here (the original declares one), so a request can carry a `user_id` that is not in `Signups`. Such users must not appear in the output: the grain is `Signups`, not "anyone who made a request". Also, `action` is `NOT NULL` in this schema, so there is no "request with unknown outcome" case; every row counts in the denominator.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **outer-join preservation + conditional aggregation**. Every signup must survive, and the value is a ratio of "rows meeting a condition" to "all rows" for the same user.

</details>

<details><summary>Hint 2</summary>

Shape: (1) per user, count all requests and count the confirmed ones, in a single pass over `Confirmations`. (2) Attach those two numbers to every signup. (3) Divide, turning "no requests" into 0, then round.

</details>

<details><summary>Hint 3</summary>

Key trick: put the condition **inside the aggregate**, not in `WHERE`: `SUM(action = 'confirmed')` next to `COUNT(*)`. A comparison is 1 or 0 in MySQL, so the average of the comparison is the confirmed share. After the LEFT JOIN, "no requests" shows up as NULL, so wrap the ratio in `COALESCE(…, 0)` before `ROUND(…, 2)`.

</details>

## 4. Decomposition

Read the wording as "ratio" over "for each user". The ratio is something you compute from two counts; "for each user" is the frame you hang it on.

1. **`per_user`: `GROUP BY user_id` over `Confirmations`, with `COUNT(*)` and `SUM(action = 'confirmed')`.**
   *Why a GROUP BY here:* "confirmed divided by total requests" is per user, so requests must collapse to user grain. *Why both counts in one pass:* numerator and denominator come from the same rows, so a condition inside `SUM` replaces a second scan or a second join. No `WHERE`: that would remove the denominator rows.
2. **Final: `Signups LEFT JOIN per_user`.**
   *Why a LEFT JOIN here:* "each user" means every `Signups` row survives, and users with no requests have no partner row. The join is 1:1 because `per_user` has one row per `user_id`.
3. **Final projection: `ROUND(COALESCE(n_confirmed / n_requests, 0), 2)`.**
   *Why COALESCE:* an unmatched user has NULL for both counts, so the division is NULL, and the spec wants 0. *Why division after the join, not inside the CTE:* the CTE only knows users who made requests; the zero case exists only after the join.

```sql
WITH per_user AS (                            -- step 1: request grain -> user grain
  SELECT user_id,
         SUM(action = 'confirmed') AS n_confirmed,
         COUNT(*)                  AS n_requests
  FROM Confirmations
  GROUP BY user_id
)
SELECT s.user_id,                             -- steps 2 + 3: all signups, NULL -> 0, round
       ROUND(COALESCE(p.n_confirmed / p.n_requests, 0), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN per_user p ON p.user_id = s.user_id;
```

Self-check: the row count must equal `Signups`; find a user you know made no requests and confirm they show 0.00; find a user with 1 of 3 and confirm 0.33.

## 5. Approaches: brute force → optimal

### Approach 1: three correlated subqueries per user (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT s.user_id,
       ROUND(CASE
         WHEN (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id) = 0 THEN 0
         ELSE (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id AND c.action = 'confirmed')
            / (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id)
       END, 2) AS confirmation_rate
FROM Signups s;
```

**Why it is correct:** the outer query is `Signups` with no join and no filter, so every user appears once. The `CASE` handles the zero-request user explicitly, which also avoids dividing by zero. It reads like the spec, which is why it is the natural first attempt.

**Cost model (reasoned, plan shape checked with EXPLAIN on a sample):** each subquery is a *dependent* subquery that runs once per user, three times. The table's primary key is `(user_id, time_stamp)`, so each run is already an index lookup on `user_id`, not a table scan; it is not quadratic here. What costs is the repetition: every user's entries are read three times, and the `action = 'confirmed'` count has to fetch each matching row from the clustered index to read `action`. With `indexes.sql` (`user_id, action`) all three become covering index reads.

### Approach 2: LEFT JOIN, then GROUP BY (`solutions/02_left_join_group_by.sql`)

```sql
SELECT s.user_id,
       ROUND(IFNULL(AVG(c.action = 'confirmed'), 0), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN Confirmations c ON c.user_id = s.user_id
GROUP BY s.user_id;
```

**Why it is correct:** the join keeps every user. For each user the group holds their requests (or one all-NULL row). `AVG` over the 0/1 comparison is confirmed ÷ total; for the all-NULL row the comparison is NULL, `AVG` skips it and returns NULL, and `IFNULL` makes that 0. There is no filter on `Confirmations` at all, so no row can disappear.

**Cost model (reasoned):** one pass over each table. Without an index on `user_id` beyond the PK, MySQL 8.0 can choose a *left hash join* (the EXPLAIN on a sample showed one). The join output is request grain, and an *aggregate using temporary table* runs on those rows, which can spill to disk once large. With `indexes.sql` the join becomes an index nested loop and the aggregate streams in `user_id` order.

### Approach 3 (optimal): aggregate, then LEFT JOIN (`solutions/03_aggregate_then_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `per_user` has exactly one row per user who made a request; the LEFT JOIN from `Signups` is 1:1, so it can neither duplicate nor drop a user. Users who are not in `Signups` never join. `COALESCE` turns "no row" into 0. Both counts come from the same rows, so the ratio is always confirmed ÷ total.

**Cost model (reasoned):** one scan of `Confirmations` feeds a narrow aggregation keyed only by `user_id`, and its result has at most one row per distinct requester. Because the primary key starts with `user_id`, the scan arrives already sorted by user, and the plan on a sample showed a streaming *group aggregate* with no temporary table even without `indexes.sql`. The join then reads users + requesters, not users + requests.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:02-confirmation-rate -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 reduces the big table to one narrow row per user before touching `Signups`, so the join is 1:1 and the zero case is one `COALESCE`. It reads `Confirmations` once (approach 1 reads each user's entries three times) and never builds order-grain intermediate rows (approach 2 does). It is also the shape that distributes well (section 6c). It is not guaranteed to win on one machine with a good index; approach 2 with `indexes.sql` becomes a streaming nested loop of similar cost, so read the "with indexes" bench table before declaring a winner.

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* approach 1 goes first, because it runs three lookups per signup, so its cost grows with users × lookups, and the `action` filter touches clustered rows. Approach 2's order-grain temporary table comes next, when it no longer fits in memory. Approach 3 degrades last: its aggregate is narrow and, with the PK order, can stream.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Confirmations (user_id, action)`. It is *covering* for all three approaches. The PK `(user_id, time_stamp)` already serves the `user_id` lookup, so the gain is avoiding clustered-row fetches for `action`, not avoiding a full scan.
- Keep the whole computation to one pass. Computing "confirmed" and "total" in separate subqueries or joins doubles the I/O.
- At 100M+ requests, partition by `time_stamp` only if the question gains a time window (it doesn't here); a per-user aggregate must read all partitions.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the `GROUP BY user_id` needs a shuffle by `user_id`. `COUNT` and `SUM` are decomposable, so each task pre-aggregates locally first and the shuffle carries at most one `(user_id, partial_confirmed, partial_total)` row per user per task. A join-first plan (approach 2) shuffles every request row to the join and aggregates afterwards.
- *Skew:* a few very heavy users would overload one reducer in a join-first plan. Pre-aggregation removes that skew because each heavy user leaves every task as one partial row.
- *The second join:* attaching counts to `Signups` is a second shuffle on `user_id`, unless one side is small enough to broadcast. Aggregating first makes the aggregated side small, which is what makes a broadcast plausible.
- *Things to avoid:* no `ORDER BY` is asked for, so don't add one. Nothing here needs `COUNT(DISTINCT)`, so approximate functions are unnecessary; if the follow-up becomes "distinct devices per user", partial results can no longer be single numbers.

**(d) The data-engineering answer.** Do not rescan all history per run. Maintain per-user **sums**, and compute the rate at read time. A rate itself is not additive: you cannot add yesterday's 0.50 to today's 0.67. The counts are.

```sql
-- user_confirmation_counts(user_id PK, n_confirmed, n_requests), fed by each new batch of requests.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO user_confirmation_counts t
USING (SELECT user_id, COUNT_IF(action = 'confirmed') AS c, COUNT(*) AS n
       FROM confirmations_batch                 -- only rows not yet applied (watermark on time_stamp)
       GROUP BY user_id) s
ON t.user_id = s.user_id
WHEN MATCHED THEN UPDATE SET n_confirmed = t.n_confirmed + s.c, n_requests = t.n_requests + s.n
WHEN NOT MATCHED THEN INSERT (user_id, n_confirmed, n_requests) VALUES (s.user_id, s.c, s.n);

-- MySQL equivalent (no MERGE):
INSERT INTO user_confirmation_counts (user_id, n_confirmed, n_requests)
SELECT user_id, SUM(action = 'confirmed'), COUNT(*) FROM confirmations_batch GROUP BY user_id
ON DUPLICATE KEY UPDATE n_confirmed = n_confirmed + VALUES(n_confirmed),
                        n_requests  = n_requests  + VALUES(n_requests);

-- The question then reads only Signups + the small table:
SELECT s.user_id, ROUND(COALESCE(c.n_confirmed / c.n_requests, 0), 2) AS confirmation_rate
FROM Signups s LEFT JOIN user_confirmation_counts c ON c.user_id = s.user_id;
```

Caveats interviewers probe. *Idempotency:* a batch applied twice double-counts, so track the applied watermark and make re-runs no-ops. *Late or corrected rows:* a request whose `action` flips needs a −1 on the old outcome and +1 on the new, which means a change feed with before and after images.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Users with no requests, among users who have some | `tests/edge_typical.sql` | `inner_join` (user vanishes), `avg_without_ifnull` (shows NULL), `drive_from_confirmations` (user absent), `where_filter_on_confirmed` |
| Every user has no requests (`Confirmations` empty) | `tests/edge_no_confirmations.sql` | the same four |
| All timeouts (0.00) and all confirmed (1.00) | `tests/edge_typical.sql` | none: a correct reference point for the extremes |
| Repeating decimal (1/6 → 0.17) and an exact half (1/8 → 0.13) | `tests/edge_rounding.sql` | `float_arithmetic`: `CAST(… AS DOUBLE)` makes `ROUND(0.125, 2)` round half to even and return 0.12 |
| Requests from users who are not signups | `tests/edge_orphan_confirmations.sql` | `drive_from_confirmations` (extra rows for users 98, 99) |
| `Signups` empty, `Confirmations` not | `tests/edge_empty_signups.sql` | `drive_from_confirmations` (returns requesters) |

No approach in `solutions/` is broken by any of these. There is no ties case and no true-NULL case in the input: `action` is `NOT NULL`, and the only NULLs are the ones the LEFT JOIN manufactures.

## 8. Interviewer follow-ups

1. **"Why not `WHERE action = 'confirmed'` and count?"** It removes the timeout rows, so the denominator is gone, and it removes every user with no confirmed row. The condition belongs inside the aggregate.
2. **"What if `action` can be NULL?"** Decide what a request with unknown outcome means. `AVG(action = 'confirmed')` skips it in the denominator; `SUM(...) / COUNT(*)` counts it. Say which you chose and test it. Here the schema forbids NULL.
3. **"Confirmation rate per month."** The grain becomes (user, month); you need a month scaffold if zero-request months must appear. Same idea as `09-count-salary-categories`. Otherwise just add the month to the `GROUP BY`.
4. **"Why does `ROUND(0.125, 2)` give 0.13 here but 0.12 in Python?"** MySQL divides exact numbers (`DECIMAL`) and rounds halves away from zero; Python's `round` works on binary floats and rounds half to even. (UNVERIFIED) Snowflake also divides into a fixed-scale `NUMBER`, so it should match MySQL here; check before relying on it.
5. **"Only users with at least 5 requests."** A `HAVING COUNT(*) >= 5` on `per_user`, which now filters the right-hand side, so decide whether the others should show 0 or be dropped.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes:

- `COUNT_IF(action = 'confirmed')` replaces `SUM(action = 'confirmed')`. In Snowflake, `SUM` over a boolean needs a cast, so `COUNT_IF` is the idiomatic form.
- `ZEROIFNULL` (or `COALESCE`) turns "no row" into 0.
- No secondary indexes: `indexes.sql` has no equivalent. Cost is driven by scanned micro-partitions; the aggregate reads only the `user_id` and `action` columns (columnar storage), which is why aggregate-then-join is cheap.
- The CTE may be inlined, and the optimizer may reorder; writing it aggregate-then-join still states the 1:1 intent.
- Snowflake's `ENUM` does not exist; `action` would be a `VARCHAR` with a check, so the comparison is case-sensitive.
- Unquoted identifiers come back upper-cased (`USER_ID`).

## 10. Pattern links

Same pattern (outer-join preservation, zero instead of NULL):
- `01-market-analysis-i`: the same LEFT JOIN-preserve plus a count that must be 0 for unmatched users.

Same pattern (conditional aggregation, ratio from two counts over the same rows):
- `04-monthly-transactions-i`: several conditional sums in one pass, grouped by (month, country).
- `05-find-loyal-customers`, `06-find-golden-hour-customers`: ratios in `HAVING`.
- `07-trips-and-users`: cancellation rate per day, with a second join to filter users.
