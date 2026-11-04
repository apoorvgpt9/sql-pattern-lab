# 03 · Investments in 2016

## 1. Problem & trigger phrases

Original: [Investments in 2016](https://leetcode.com/problems/investments-in-2016/) (LeetCode 585, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** one number: the total of `tiv_2016` over policies that (a) have a `tiv_2015` value that at least one *other* policy also has, and (b) sit at a `(lat, lon)` location that no other policy has. Round to 2 decimals.

| Trigger phrase | What it forces in SQL |
|---|---|
| "same tiv_2015 as one or more others" | An **existence** test against other rows of the same table: `EXISTS (… same tiv_2015 AND different pid)`, or a count over `PARTITION BY tiv_2015` that is > 1. "One or more" means you only need to know a twin exists, not how many. |
| "not in the same city as any other" | The **negation** of the same shape on the pair `(lat, lon)`: `NOT EXISTS`, or a partition count that is exactly 1. The key is the *pair*, and every member of a duplicated pair is out, including the first one. |
| "sum … rounded to two decimals" | A single scalar row: an aggregate with no `GROUP BY`. With no qualifying rows it is a row containing NULL, not zero rows and not 0. |

Also notice "other": in this repo it means a different `pid`. Without that exclusion every policy is its own twin.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `Insurance` | one policy | `pid` (PK); `tiv_2015` (twin test); `(lat, lon)` (location test); `tiv_2016` (the thing summed) |

**Output grain:** one scalar row, regardless of the input.

**Where the grain changes:** there is one table at one grain, so there is no join to change it. The grain trap is different: both conditions are about **groups of rows** (all policies sharing a tiv value, all policies sharing a location), while the thing you sum is **per row**. You need group-level facts attached back to each row. Four ways to do it:

- a correlated subquery per row (approach 1: counts the twins),
- window counts that attach the group size to every row (approach 2),
- `EXISTS` / `NOT EXISTS`: a self semi-join and self anti-join (approach 3),
- a self-join. **Do not use it**: a policy with two twins appears twice and its `tiv_2016` is summed twice (the `self_join_fanout` mistake).

## Assumptions

Confidence is `high`, but the statement is silent on one thing the data can contain:

1. **NULL `tiv_2015` does not "share a value" with anything**, not even another NULL. This is SQL equality (`NULL = NULL` is not true). `lat`/`lon` are NOT NULL by the spec. `edge_nulls.sql` tests it. This is not a free choice among equivalent forms: a window function's `PARTITION BY` puts all NULLs into **one** partition, so the window version needs an explicit `tiv_2015 IS NOT NULL` (the `window_null_partition` mistake shows the divergence).
2. **NULL `tiv_2016` contributes nothing** to the sum (that is what `SUM` does). It does not disqualify the policy.
3. **"Other" means a different `pid`.** The `pid` is the primary key, so there are no duplicate policies to worry about.
4. **FLOAT equality is exact equality.** Values compared are stored FLOATs of the same literal, so equal inputs are equal. The generated and hand-written data use multiples of 0.25/0.5, which FLOAT stores exactly, so no solution depends on float noise. In real data, equality on FLOAT coordinates is fragile (follow-up 2).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **existence / non-existence of "another row" in the same table** (an anti-join on a self-reference). Two independent group-level conditions, one scalar aggregate.

</details>

<details><summary>Hint 2</summary>

Shape: (1) for each policy, decide whether another policy has its `tiv_2015`. (2) For each policy, decide whether another policy is at its `(lat, lon)`. (3) Keep policies where (1) is true and (2) is false, and sum their `tiv_2016`. (1) and (2) are each computed against the **whole table**, not against the other's survivors.

</details>

<details><summary>Hint 3</summary>

Key trick: "another" means `pid <> i.pid`. With it, (1) is `EXISTS` and (2) is `NOT EXISTS`. Equivalent form: attach `COUNT(*) OVER (PARTITION BY tiv_2015)` and `COUNT(*) OVER (PARTITION BY lat, lon)` and test `> 1` and `= 1`. Do not filter by location first and then look for twins among the survivors: a policy's twin may be disqualified by *its* location, and the policy still counts.

</details>

## 4. Decomposition

Read the wording as two yes/no questions per policy, then an aggregate. Each question is about *other rows*, which is the signal for a self semi-join or self anti-join (or a window count).

1. **`shares_tiv`: which policies have a twin on `tiv_2015`?**
   *Why an existence test here:* "same tiv_2015 as one or more others" only needs to know whether at least one other row matches. `EXISTS` states exactly that and the engine can stop at the first match. Counting twins is more work than the question needs.
2. **`unique_loc`: which policies have no neighbour at `(lat, lon)`?**
   *Why a non-existence test here:* "not in the same city as any other" is the negation of the same question on a different key. `NOT EXISTS` is an anti-join. The key is the pair, not each column on its own.
3. **Final: sum `tiv_2016` over policies in both sets.**
   *Why an aggregate with no GROUP BY here:* the answer is one scalar. A `SUM` over zero rows is NULL, which is the specified output.

Written as separate CTEs, steps 1 and 2 must each read the **full** table. That is the point:

```sql
WITH shares_tiv AS (                          -- step 1: against the whole table
  SELECT i.pid FROM Insurance i
  WHERE EXISTS (SELECT 1 FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid)
), unique_loc AS (                            -- step 2: against the whole table, independently
  SELECT i.pid FROM Insurance i
  WHERE NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid)
)
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016  -- step 3
FROM Insurance i
JOIN shares_tiv  USING (pid)                  -- 1:1 on the PK: cannot multiply rows
JOIN unique_loc  USING (pid);
```

The two CTEs are just predicates on the same row, so `solutions/03_exists_not_exists.sql` folds them into one `WHERE`. Both forms return the same rows; the CTE form shows that the joins are on `pid`, so they cannot fan out.

Self-check: run the two predicates separately and count rows; the answer rows are the intersection. On a hand-made table, find a policy whose only tiv twin has a shared location, and confirm it is still counted.

## 5. Approaches: brute force → optimal

### Approach 1: correlated `COUNT(*)` subqueries (`solutions/01_correlated_count.sql`)

```sql
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE (SELECT COUNT(*) FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015) > 1
  AND (SELECT COUNT(*) FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon) = 1;
```

**Why it is correct:** for each policy the first subquery counts everyone with its `tiv_2015`, itself included, so "> 1" means "at least one other". The second counts everyone at its location, itself included, so "= 1" means "nobody else". A NULL `tiv_2015` matches nothing, so its count is 0 and the policy is out.

**Cost model (reasoned):** a dependent subquery runs once per policy per condition. Without an index it scans the table each time, so cost is rows² comparisons: this is the approach that can time out outright (the bench records a timeout as a result). With `indexes.sql` each run is an index range read of one key's entries, so total cost is about rows × twins. Note it counts *every* twin when one would do.

### Approach 2: window counts (`solutions/02_window_counts.sql`)

```sql
WITH counted AS (
  SELECT tiv_2015, tiv_2016,
         COUNT(*) OVER (PARTITION BY tiv_2015) AS n_same_tiv,
         COUNT(*) OVER (PARTITION BY lat, lon) AS n_same_loc
  FROM Insurance
)
SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
FROM counted
WHERE tiv_2015 IS NOT NULL AND n_same_tiv > 1 AND n_same_loc = 1;
```

**Why it is correct:** each window count is the size of the row's group, attached to the row without collapsing it, so the grain stays at policy level. `IS NOT NULL` implements assumption 1.

**Cost model (reasoned):** no self-join and no per-row probes: the table is read once, but the engine sorts it twice (once per distinct `PARTITION BY`) into a buffered window operator, and then materialises the result. Cost is dominated by the two sorts, O(n log n) each, unless an index already provides the order. The EXPLAIN on a sample shows both sorts and a temporary table.

### Approach 3 (optimal on MySQL 8.0): `EXISTS` / `NOT EXISTS` (`solutions/03_exists_not_exists.sql`)

```sql
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE EXISTS (SELECT 1 FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid)
  AND NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);
```

**Why it is correct:** `EXISTS` is true iff some *other* row has the same `tiv_2015` (so NULL never matches); `NOT EXISTS` is true iff no other row is at the same pair. Both are evaluated against the whole table, independently. No join multiplies rows, so there is no fan-out.

**Cost model (reasoned, plan shape checked with EXPLAIN on a sample):** syntactically this looks like approach 1, but it is not executed that way. MySQL 8.0 rewrites `EXISTS` into a *semi-join* and `NOT EXISTS` into an *anti-join*, and without a useful index it runs them as **hash** joins: the table is scanned and hashed on the key, and the `pid <>` condition is a residual filter on each bucket. That is a few linear passes with no sort and no temporary table. With `indexes.sql` the optimizer may switch to index nested-loop plans (with duplicate weed-out), which is not automatically faster; the "with indexes" bench table is the authority.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:03-investments-in-2016 -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 is the only one that asks the engine what the wording asks, "does another row exist?", so the optimizer is free to use semi/anti-join algorithms that stop at the first match, instead of counting every twin (approach 1) or sorting the whole table twice (approach 2). That reading is reasoned and checked against plan shapes, not assumed: on a different engine or with different indexes approach 2 can win, and the bench has both "without" and "with indexes" tables so you can see where the ranking flips. Approach 3 also never depends on `IS NOT NULL` for correctness, because `NULL = NULL` is simply not a match.

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* approach 1 without an index breaks first, since rows² comparisons stop being feasible within thousands to tens of thousands of rows. Approach 2 degrades next as the two sorts spill to disk. Approach 3 stays near-linear as long as the hash tables fit in memory (the build side is the whole table, keyed on a FLOAT).

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `(tiv_2015, pid)` and `(lat, lon, pid)`. They are covering for the probes, and are what makes approach 1 feasible at all. For approach 3 they let the optimizer choose index lookups instead of hash joins; whether that wins depends on how many twins there are. Read both tables of the bench.
- `GROUP BY … HAVING` + `IN (subquery)` (or a join to those aggregated sets) is correct, but it builds two grouped temporary tables keyed on FLOATs and then probes them per row. That is extra materialisation the question does not need, so expect it to lose to approach 3 (reasoned; it is not one of the benchmarked solutions).
- `FLOAT` keys are a smell for equality: with real coordinates, store `DECIMAL(9,6)` or a geohash / H3 cell id and compare that.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- Both conditions need **all rows with the same key together**, so each costs one shuffle: by `tiv_2015` and by `(lat, lon)`. Approach 2 does exactly two shuffles (one per window). Approach 3's two semi/anti-joins also need both sides hashed on those keys.
- *Skew:* a single popular `tiv_2015` (a default value such as 0) puts millions of rows on one reducer. Because the question only needs "count > 1" or "count = 1", pre-aggregate with `GROUP BY key` to get `(key, n)` (decomposable, cheap to combine) and join the *small* result back. Only that tiny `(key, n)` table is shuffled by key.
- *Pruning:* neither predicate filters on a clusterable column, so Snowflake-style micro-partition pruning does not help; the whole table is read. The win comes from reading only the 4 columns involved (columnar storage), not from skipping data.
- *Things to avoid:* no `COUNT(DISTINCT)` is needed, and no global sort. "Is count at least two" is exactly the case where an approximate sketch is not appropriate: it is an exact boundary at 1 vs 2.

**(d) The data-engineering answer.** Keep per-key counters instead of rescanning the table, and re-derive membership from them:

```sql
-- tiv_counts(tiv_2015 PK, n) and loc_counts(lat, lon, PRIMARY KEY (lat, lon), n), updated per batch of new policies.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO tiv_counts t
USING (SELECT tiv_2015, COUNT(*) AS n FROM policies_batch WHERE tiv_2015 IS NOT NULL GROUP BY tiv_2015) s
ON t.tiv_2015 = s.tiv_2015
WHEN MATCHED THEN UPDATE SET n = t.n + s.n
WHEN NOT MATCHED THEN INSERT (tiv_2015, n) VALUES (s.tiv_2015, s.n);
-- (same for loc_counts on (lat, lon))

-- MySQL equivalent for one of them:
INSERT INTO tiv_counts (tiv_2015, n)
SELECT tiv_2015, COUNT(*) FROM policies_batch WHERE tiv_2015 IS NOT NULL GROUP BY tiv_2015
ON DUPLICATE KEY UPDATE n = n + VALUES(n);

-- The question reads two 1:1 lookups instead of self-joining the whole table:
SELECT ROUND(SUM(p.tiv_2016), 2)
FROM Insurance p
JOIN tiv_counts t ON t.tiv_2015 = p.tiv_2015 AND t.n > 1
JOIN loc_counts l ON l.lat = p.lat AND l.lon = p.lon AND l.n = 1;
```

The caveat interviewers probe: **a new row changes the status of old rows.** Adding the second policy with a given `tiv_2015` makes the *first* one start qualifying; adding a second at a location makes the first one stop qualifying. So you cannot just append a delta to the previous sum. Either re-derive from the counter tables (cheap, as above), or maintain the sum with ±`tiv_2016` adjustments whenever a counter crosses 1 → 2 or 2 → 1. Also: re-applied batches double-count (track a watermark), and deletes must decrement.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Typical mix: twins and non-twins, unique and shared locations | `tests/edge_typical.sql` | `forgot_other_pid` (every policy is its own twin), `self_join_fanout` (a policy with two twins counted twice) |
| Rows exist, none qualifies: one row with NULL, not 0 and not no rows | `tests/edge_none_qualify.sql` | `forgot_other_pid`, `coalesce_to_zero` |
| Table empty: still one row with NULL | `tests/edge_empty_table.sql` | `coalesce_to_zero` |
| Location "ties": both members of a duplicated pair are out; policies sharing only a lat or only a lon are not neighbours | `tests/edge_location_ties.sql` | `lat_only`, `lon_only`, `first_occurrence_only` (keeps the first of a duplicated pair), `self_join_fanout` |
| Twin that is itself disqualified by location still counts as a twin | `tests/edge_independent_conditions.sql` | `sequential_filter` (filter locations first, then look for twins among survivors) |
| NULL `tiv_2015` (two NULLs are not twins), NULL `tiv_2016` (skipped by SUM) | `tests/edge_nulls.sql` | `window_null_partition`: `PARTITION BY` groups NULLs together, so the unguarded window query counts them as twins |
| Sum with more than two decimals, and a zero `tiv_2016` | `tests/edge_rounding.sql` | `no_round` |

No approach in `solutions/` is broken by any of these. Approach 1 is only slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Return the policies, not the sum."** Same predicates, `SELECT pid`. Note the contrast: with no qualifying policy the result is *empty*, where the scalar version is a NULL row.
2. **"Why is comparing FLOAT latitudes risky?"** Binary floats cannot represent most decimals exactly, so two "equal" coordinates can differ in the last bit after any arithmetic, and a pair that should match won't. Store `DECIMAL` or snap to a geohash/H3 cell, and define "same city" on that.
3. **"Window functions or `EXISTS`?"** Windows state the grouping and compute it once, and tend to win in distributed engines because one repartition per key does both checks. `EXISTS` states the intent and wins on MySQL without indexes because the optimizer can use semi/anti-joins. Say what you measured, not what you prefer.
4. **"What if `tiv_2015` is NULL?"** See Assumptions: SQL equality says not a twin; a window `PARTITION BY` disagrees unless guarded.
5. **"Make it return 0 when nothing qualifies."** `COALESCE(SUM(...), 0)`: a one-line change, but it contradicts this spec (NULL), so confirm with the interviewer which is wanted.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` has approach 3 plus a commented window alternative. What changes:

- Correlated `EXISTS` with a non-equality residual (`pid <>`) is accepted syntax, but how it is planned (a join with a residual predicate vs a per-row subquery) is for the query profile to tell you. I could not run it; check for a join node and not a repeated sub-plan.
- The window version needs no self-join, so it is the first thing to benchmark. `QUALIFY` does not help here: the filters combine two different windows with a scalar aggregate, so a CTE is clearer.
- No secondary indexes: `indexes.sql` has no equivalent. Pruning cannot help (neither predicate is a range on a clustered column); the saving is reading only four columns.
- `FLOAT` in Snowflake is 64-bit (double), not MySQL's 32-bit FLOAT, so stored values like 12.345678 are not the same bits as in MySQL. The hand-built datasets would still agree because they use exactly representable values, but real data may not. Prefer `NUMBER(38, 6)` for money.
- `SUM` over zero rows is NULL, as in MySQL.

## 10. Pattern links

Same pattern (existence / non-existence of another row):
- `01-market-analysis-i`, `02-confirmation-rate`: the other members of the `anti_join` family (there, preserving unmatched rows rather than testing for neighbours).
- `34-find-covid-recovery-patients`, `38-find-students-with-study-spiral-pattern`: `EXISTS` / `NOT EXISTS` over a user's other rows.
- `39-tree-node`: classify a row by whether other rows reference it.
- `15-employees-qualified-for-every-required-skill-of-a-role`: `NOT EXISTS` twice (relational division).

Same pattern (group size attached to each row with a window count):
- `12-find-product-recommendation-pairs`: self-join plus pair counts; compare with the self-join fan-out trap here.
