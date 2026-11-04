# 07 · Trips and Users

## 1. Problem & trigger phrases

Original: [Trips and Users](https://leetcode.com/problems/trips-and-users/) (LeetCode 262, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for each day from 2013-10-01 to 2013-10-03, take only the trips whose client **and** driver are both unbanned, and report the share of those trips that were cancelled (by either side), rounded to 2 decimals. A day with no such trip is not reported.

| Trigger phrase | What it forces in SQL |
|---|---|
| "both client and driver must not be banned" | `Trips` has **two** foreign keys into the same table `Users`. Each side needs its own check against `Users` (two joins with two aliases, or two membership tests), and the two checks are AND-ed. One join cannot test both roles. |
| "cancelled by client or driver" | Two statuses on the numerator side. Simplest is "not completed": `status <> 'completed'`. Listing only one cancellation status is a wrong answer. |
| "each day … with at least one trip" | `GROUP BY request_at`. Days with zero eligible trips *do not appear*; you must **not** build a calendar and LEFT JOIN. This is the opposite of the outer-join problems in this repo. |
| "round to two decimal points" | `ROUND(…, 2)` on a ratio of two counts, over the same rows: conditional aggregation. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Trips` | one trip request | `client_id` and `driver_id` (both reference `Users.users_id`); `status`; `request_at` (a `'YYYY-MM-DD'` string) |
| `Users` | one user (client, driver or partner) | `users_id` (PK); `banned` |

**Output grain:** one row per day in the range that has at least one eligible trip.

**Where the grain changes:** trip grain → day grain, in one `GROUP BY request_at`. A second grain issue sits before that: `Users` is attached to a trip **twice** (as client, as driver). Each attachment must be 1:1 with the trip. If one trip ever produced two joined rows, the day's counts would be inflated: that is the fan-out trap of joining `Users` once on `client_id IN (…)`/`driver_id`.

The `role` column is not needed: the foreign keys already say which role a user plays on a trip.

## Assumptions

Confidence is `high`, but the spec is silent on one point the data can contain:

1. **A trip counts only if both its client and its driver exist in `Users` and are unbanned.** The statement guarantees the foreign keys, so a trip pointing at a missing user should not occur; this repo declares no foreign keys, so `tests/edge_orphan_users.sql` includes one and pins the choice: such a trip is **not** counted. Every solution uses *membership in the unbanned set* (an inner join or `IN`), never *absence from the banned set* (`NOT IN`/`NOT EXISTS`); `not_in_banned` shows the difference.
2. **`request_at` is a zero-padded ISO string** (`'2013-10-01'`), so comparing strings is comparing dates and `BETWEEN '2013-10-01' AND '2013-10-03'` is inclusive at both ends. Data in other formats (`'2013-10-1'`) would sort wrongly; that is a data-quality problem this query does not defend against.
3. **The date range is the one in the spec** (2013-10-01 to 2013-10-03), hard-coded.
4. **Ban status is current**, not as of the trip date (the table has no ban history); see section 6d for why that matters in a pipeline.
5. **Output names are `Day` and `Cancellation Rate`** (the second has a space, so it needs backticks in MySQL and double quotes in Snowflake).
6. **Rounding** is `ROUND(ratio, 2)` on an exact decimal, so halves round up (0.125 → 0.13). Tested by `tests/edge_rounding.sql`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **conditional aggregation after a filter that involves the same table twice**. Filter trips by two roles of one lookup table, then take a ratio per day.

</details>

<details><summary>Hint 2</summary>

Shape: (1) find the unbanned users. (2) Keep trips in the date range whose client **and** driver are both in that set. (3) Group those trips by day and divide cancelled trips by all trips.

</details>

<details><summary>Hint 3</summary>

Key trick: the ban check is a *filter* (rows leave), not an aggregate input: do it before grouping, once per role. Then `status <> 'completed'` is 1 for a cancellation of either kind, so `AVG(status <> 'completed')` (or `SUM(…) / COUNT(*)`) is the rate. Do not left-join a calendar: days with no eligible trip must be absent.

</details>

## 4. Decomposition

Read the sentence as: *who counts* (a filter on two foreign keys), *what is measured* (a ratio), *per what* (day).

1. **`ok_users`: users with `banned = 'No'`.**
   *Why a filter on `Users` here:* "not banned" is a property of a user. Defining the set once means both roles use the same definition.
2. **`eligible`: trips in range whose `client_id` and `driver_id` are both in `ok_users`.**
   *Why two membership tests (or two joins), AND-ed:* `Trips` holds two foreign keys to `Users` and the sentence requires both parties to pass. *Why membership, not "not in banned":* a missing user is not "banned", but it is not a verified unbanned user either (assumption 1). *Why the date filter here:* it is on the raw `request_at`, applied before any grouping, so an index can serve it.
3. **Final: `GROUP BY request_at`, rate = cancelled ÷ all.**
   *Why a GROUP BY here:* "each day" is the output grain. *Why conditional aggregation:* numerator and denominator are the same trips; `status <> 'completed'` is a 0/1 expression you can sum. A day with no eligible trip has no rows to group, so it is absent, as the spec demands.
4. **`ROUND(…, 2)` and the column aliases.**

```sql
WITH ok_users AS (                              -- step 1
  SELECT users_id FROM Users WHERE banned = 'No'
), eligible AS (                                -- step 2: both parties unbanned, in range
  SELECT request_at, status
  FROM Trips
  WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03'
    AND client_id IN (SELECT users_id FROM ok_users)
    AND driver_id IN (SELECT users_id FROM ok_users)
)
SELECT request_at AS Day,                       -- steps 3 + 4
       ROUND(SUM(status <> 'completed') / COUNT(*), 2) AS `Cancellation Rate`
FROM eligible
GROUP BY request_at;
```

Self-check: a day on which every trip involves a banned user must not appear. Sum the per-day trip counts and compare with a hand count of eligible trips.

## 5. Approaches: brute force → optimal

### Approach 1: per-day correlated subqueries (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT d.request_at AS Day,
       ROUND(
         (SELECT COUNT(*) FROM Trips t
           WHERE t.request_at = d.request_at AND t.status <> 'completed'
             AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
             AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No'))
         /
         (SELECT COUNT(*) FROM Trips t
           WHERE t.request_at = d.request_at
             AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
             AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No')), 2) AS `Cancellation Rate`
FROM (SELECT DISTINCT request_at FROM Trips WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03') d
WHERE (SELECT COUNT(*) FROM Trips t
        WHERE t.request_at = d.request_at
          AND t.client_id IN (SELECT users_id FROM Users WHERE banned = 'No')
          AND t.driver_id IN (SELECT users_id FROM Users WHERE banned = 'No')) > 0;
```

**Why it is correct:** the derived table lists each day in range once. For each day, one subquery counts eligible cancelled trips and one counts eligible trips; the `WHERE … > 0` drops days with no eligible trip (and avoids dividing by zero). It reads like the spec.

**Cost model (reasoned, plan shape checked with EXPLAIN on a sample):** three dependent subqueries per day, each re-reading the eligible trips of its day, so the whole eligible set is evaluated three times. It is **not** quadratic here: the day list is at most 3 rows, so the cost is about 3 × (the cost of one pass), and without an index on `request_at` each of those passes scans all of `Trips`. With `indexes.sql` each is a range read of one day.

### Approach 2: join `Users` twice, then group (`solutions/02_join_users_twice.sql`)

```sql
SELECT t.request_at AS Day,
       ROUND(AVG(t.status <> 'completed'), 2) AS `Cancellation Rate`
FROM Trips t
JOIN Users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN Users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY t.request_at;
```

**Why it is correct:** each trip joins at most one client row and at most one driver row (primary-key lookups), so it appears at most once; the ban test sits in the `ON`, and an inner join drops trips with a banned or missing party. `AVG` of the 0/1 comparison is cancelled ÷ total.

**Cost model (reasoned, plan shape checked on a sample):** one pass over `Trips` (the date filter first, or a range scan with the index), two primary-key lookups into `Users` per surviving trip, and one aggregation. Linear in the trips in range.

### Approach 3 (optimal): filter with set membership, then aggregate (`solutions/03_filter_then_aggregate.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `eligible` contains exactly the in-range trips whose two parties are in the unbanned set, with no columns from `Users`; `IN (subquery)` is a semi-join, which cannot multiply rows however `Users` is shaped. The aggregation then sees one row per eligible trip.

**Cost model (reasoned, plan shape checked on a sample):** on MySQL 8.0 the optimizer turns the `IN` subqueries into the same primary-key lookups as approach 2: **the EXPLAIN trees of approaches 2 and 3 have the same shape** (a scan or range scan of `Trips`, two lookups into `Users`, a group aggregate). Expect the bench to show them at parity; any gap is noise.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:07-trips-and-users -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V74 80-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/07-trips-and-users.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 4.04 ms | 308 ms | 3.45 s | 4.6× |
| `02_join_users_twice` | 1.08 ms | 58.4 ms | 742 ms | 1.0× |
| `03_filter_then_aggregate` (optimal) | 1.19 ms | 60.5 ms | 743 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 1.18 ms | 43.4 ms | 659 ms | 1.9× |
| `02_join_users_twice` | 868 µs | 22.6 ms | 336 ms | 1.0× |
| `03_filter_then_aggregate` (optimal) | 835 µs | 23.5 ms | 339 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

On MySQL it only ties approach 2; the claim is not a speed win. Approach 3 is preferred because it states the intent exactly (a trip is eligible if both parties are *in* the unbanned set), carries no `Users` columns into the aggregate, and cannot fan out or leak even if someone later replaces the primary-key lookup with a join on a non-unique key. It is also the shape that distributes best (section 6c), since the unbanned set can be broadcast. Both beat approach 1, which evaluates the whole eligibility filter three times.

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* the cost of reading `Trips` when the query needs only three days of it. Without an index on `request_at` every approach scans the entire history, so cost grows with the table, not with the answer. Approach 1 pays that three times.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `Trips (request_at, client_id, driver_id, status)`. It starts with the range column, so the 3-day filter is an index range scan, and it is covering for the `Trips` side (EXPLAIN on a sample shows a *covering index range scan*). `Users` is only touched by primary key, so it needs no extra index.
- Compare the date as a raw range, never `DATE(request_at) BETWEEN …`, `LEFT(request_at, 10)`, or `STR_TO_DATE(request_at, …)`: any function on the column hides it from the index. Better, store `request_at` as `DATE`.
- At 100M+ rows partition `Trips` by month on the date, so only the matching partition is read (reasoned). Partitioning needs the date in every unique key, which conflicts with `id` as sole PK.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Pruning:* the date range is the dominant lever. If `Trips` is clustered by `request_at` (Snowflake micro-partitions in arrival order, or date-partitioned files), only a sliver of the table is read at all.
- *Joins:* the unbanned-user filter is a join against a small, slowly changing set, so broadcast it (or a Bloom filter of it) to every task and avoid shuffling the large `Trips` side. If `Users` is also huge, the two joins each cost a shuffle of the *date-filtered* trips by `client_id` and by `driver_id`; filtering by date first keeps that small.
- *Shuffle for the aggregate:* `SUM` and `COUNT` are decomposable, so each task emits at most 3 partial rows (one per day). The final shuffle is negligible.
- *Skew:* a handful of very active drivers could skew the driver-side join in a shuffle plan; a broadcast plan has no such skew.
- *Things to avoid:* a calendar scaffold (the spec wants absent days), `COUNT(DISTINCT)` (not needed), and approximate counts (the ratio's rounding is exact at 2 decimals).

**(d) The data-engineering answer.** Keep daily **counts**, not rates (a ratio is not additive), and decide **which ban status** applies. The query uses *current* ban status, so banning a user retroactively changes the rate of every past day they took part in. For stable reporting, evaluate eligibility at trip time (a flag computed at ingest from a ban history table) and store it:

```sql
-- daily_cancellation(day PK, n_eligible, n_cancelled), fed by each batch of trips; is_eligible set at ingest
-- (client and driver unbanned as of request time).
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO daily_cancellation t
USING (SELECT request_at AS day, COUNT(*) AS n, COUNT_IF(status <> 'completed') AS c
       FROM trips_batch                   -- only rows not yet applied (watermark on id)
       WHERE is_eligible
       GROUP BY request_at) s
ON t.day = s.day
WHEN MATCHED THEN UPDATE SET n_eligible = t.n_eligible + s.n, n_cancelled = t.n_cancelled + s.c
WHEN NOT MATCHED THEN INSERT (day, n_eligible, n_cancelled) VALUES (s.day, s.n, s.c);

-- MySQL equivalent (no MERGE):
INSERT INTO daily_cancellation (day, n_eligible, n_cancelled)
SELECT request_at, COUNT(*), SUM(status <> 'completed') FROM trips_batch WHERE is_eligible GROUP BY request_at
ON DUPLICATE KEY UPDATE n_eligible = n_eligible + VALUES(n_eligible), n_cancelled = n_cancelled + VALUES(n_cancelled);

-- The question reads only the small table:
SELECT day AS `Day`, ROUND(n_cancelled / n_eligible, 2) AS `Cancellation Rate`
FROM daily_cancellation WHERE day BETWEEN '2013-10-01' AND '2013-10-03' AND n_eligible > 0;
```

Caveats interviewers probe. *Idempotency:* a batch applied twice double-counts, so apply by watermark. *Status changes:* a trip that flips from `completed` to `cancelled_by_client` later needs a −1/+1 delta, so a change feed. *Ban changes:* the "current ban" semantics force a recompute of the user's past days (find them through the user's trips); the "as of trip time" semantics do not, but need ban history (an SCD type 2 table) to compute `is_eligible` correctly.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Banned client on one trip, banned driver on another; both banned on a third | `tests/edge_typical.sql` | `client_only_check`, `driver_only_check`, `either_unbanned`, `one_join_for_both_roles` (fan-out and leakage at once) |
| Cancelled by driver and cancelled by client both count | `tests/edge_typical.sql` | `cancelled_by_client_only` |
| A day with no cancellations still appears (0.00) | `tests/edge_typical.sql` | none: a correct reference point |
| Trips just outside the range (2013-09-30, 2013-10-04) | `tests/edge_typical.sql`, `tests/edge_date_boundaries.sql` | none in `solutions/`: a range predicate that is too wide would be the thing to check |
| First and last day of the range are included | `tests/edge_date_boundaries.sql` | `exclusive_end_date` |
| A day whose every trip involves a banned user is absent (not NULL, not 0.00) | `tests/edge_banned_day_absent.sql` | `ban_inside_aggregate` (the day appears with NULL), `either_unbanned` |
| A trip referencing a user who is not in `Users` | `tests/edge_orphan_users.sql` | `not_in_banned` (the trip slips through as "not banned") |
| Rounding: 1/8 → 0.13, 1/3 → 0.33, 2/3 → 0.67 | `tests/edge_rounding.sql` | `double_arithmetic` (DOUBLE rounds the exact half to even: 0.12) |
| Empty `Trips` | `tests/edge_empty.sql` | none: an empty result |
| NULLs | not applicable: every column is NOT NULL | none |

No approach in `solutions/` is broken by any of these. Approach 1 is slower, not wrong. There are no ties: the output grain is the day.

## 8. Interviewer follow-ups

1. **"Show the days with no eligible trips too."** Now a scaffold is needed: generate the three days and LEFT JOIN the aggregate. Then decide what a day with zero trips means: `0.00` would claim "nothing was cancelled", while NULL says "no data". A 0/0 is not 0%.
2. **"Rate per city."** Add `city_id` to the `GROUP BY` and the select list. The eligibility CTE is unchanged: that is the benefit of filtering first.
3. **"Bans have a `banned_at` timestamp."** The test becomes point in time: a party is unbanned for a trip if `banned_at IS NULL OR banned_at > request_at`. That is a join to ban history with a range condition, and each trip must still match at most one row per party.
4. **"Why not `NOT IN (banned users)`?"** It is true for any id that is missing from the banned list, including ids that are missing from `Users` altogether. (`NOT IN` also returns nothing at all if its subquery ever yields a NULL; that cannot happen here because `users_id` is the primary key, but it is the classic trap.) Membership in the unbanned set fails closed.
5. **"`request_at` is a string. Risks?"** Range comparison only works for zero-padded ISO dates; `'2013-10-1'` sorts after `'2013-10-09'`. Parse to a `DATE` at load. Never wrap the column in a function in the `WHERE` (kills index use).

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes:

- Quoted aliases: unquoted `Day` would come back as `DAY`; `"Day"` and `"Cancellation Rate"` preserve the case and the space.
- `COUNT_IF(status <> 'completed')` replaces `SUM(status <> 'completed')` (a boolean cannot be summed directly).
- `IN (subquery)` is a semi-join, planned as a join: Snowflake usually broadcasts or replicates the small `ok_users` side. Check the query profile for a join node with a small build side.
- Pruning replaces the index: if `request_at` is clustered (or the data arrives in date order), the 3-day range reads few micro-partitions. A `DATE` column makes that pruning more reliable than a string column.
- `ROUND` on a `NUMBER` quotient rounds halves away from zero, so 0.125 → 0.13 as in MySQL. If the expression were `FLOAT`, halves could round differently; check before relying on it.
- No `ENUM` type: `status` and `banned` would be `VARCHAR`, compared case-sensitively.

## 10. Pattern links

Same pattern (conditional aggregation, ratio of two counts over the same rows):
- `02-confirmation-rate`: a conditional share per user (with a zero case, the opposite of this problem's absent days).
- `04-monthly-transactions-i`: several conditional sums in one pass, grouped by (month, country).
- `05-find-loyal-customers`, `06-find-golden-hour-customers`: shares in `HAVING`.
- `24-immediate-food-delivery-ii`: a conditional share over a derived subset.

Same pattern (one table referenced twice from another):
- `12-find-product-recommendation-pairs`, `18-find-stores-with-inventory-imbalance`: self-joins with two aliases.
- `03-investments-in-2016`: another place where the choice between a join and `EXISTS`/`IN` decides whether rows can multiply.
- `01-market-analysis-i`: the contrast: there, unmatched rows must survive; here they must not.
