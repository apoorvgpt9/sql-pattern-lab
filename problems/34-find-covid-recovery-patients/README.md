# 34 · Find COVID Recovery Patients

## 1. Problem & trigger phrases

Original: [Find COVID Recovery Patients](https://leetcode.com/problems/find-covid-recovery-patients/) (LeetCode 3586, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** for each patient, take the date of their earliest Positive test (the *anchor*). Then find their earliest Negative test dated strictly after the anchor. Patients who have both are *recovered*. Report the patient's id, name and age, and the number of days from the anchor to that negative. Sort by that number, then by name.

| Trigger phrase | What it forces in SQL |
|---|---|
| "Positive test followed by … Negative test" | An *ordered event pair*: a later event must exist relative to an earlier one. You need the earlier event's date in hand *before* you can filter the later event, so this is two dependent steps, not one aggregation. |
| "first negative test after" | Two different MINs, and the second depends on the first: anchor = `MIN(test_date)` over positives, then `MIN(test_date)` over negatives with `test_date > anchor`. Taking the patient's overall first negative is wrong whenever a negative comes before the anchor. |
| "Inconclusive" | Not a negative, and not a reset. Filter on `result = 'Negative'`, never `result <> 'Positive'`. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `patients` | one patient | `patient_id` (PK), `patient_name`, `age` |
| `covid_tests` | one test | `patient_id` (no FK), `test_date`, `result` ∈ {Positive, Negative, Inconclusive} |

**Output grain:** one row per *recovered* patient, so it is a subset of `patients`. A patient without a qualifying pair is absent, not shown with a NULL.

**Where the grain changes:** `covid_tests` is at test grain, and the answer is at patient grain. The catch is that the patient-level answer needs *two* patient-level facts, one depending on the other:

- the anchor (patient grain), which you must compute first;
- the recovery date, which is again a patient-level MIN, but over test rows filtered *by the anchor*.

So test rows have to be seen twice: once to find the anchor, and once to compare against it. Approach 2 makes that "twice" a window (the anchor is copied onto every test row). Approach 3 makes it a join (the anchor table is joined back to the test rows). A single plain `GROUP BY patient_id` cannot do it, because inside one aggregate you cannot refer to another aggregate of the same group. That is why the one-pass conditional aggregation in `mistakes/min_neg_after_min_pos_overall.sql` is wrong.

`covid_tests` has no foreign key. Tests for an unknown `patient_id` must not produce output rows, since the output needs a name.

## Assumptions

Confidence is `high`, but the spec says nothing about undated tests. One interpretation is stated here and tested:

1. **A test with a NULL `test_date` is ignored.** It cannot be the anchor and cannot be "after" anything. `MIN()` and `>` already behave this way. The trap is `ROW_NUMBER() OVER (… ORDER BY test_date)`: MySQL sorts NULL **first** in ascending order, so an undated positive becomes "the first positive". Tested by `tests/edge_nulls.sql`; `mistakes/row_number_null_date_first.sql` shows the failure.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **first event after an anchor event** (event sequencing), per entity.

</details>

<details><summary>Hint 2</summary>

Shape: (1) find each patient's anchor date. (2) Among that patient's negative tests, keep those strictly after the anchor and take the earliest. (3) Attach patient details, compute the day difference, sort.

</details>

<details><summary>Hint 3</summary>

Key trick: the second MIN needs the first MIN as an input, so it cannot live in the same `GROUP BY`. Either pre-aggregate the anchor and join it back to the tests on `patient_id` with `n.test_date > anchor` in the `ON` clause, or put the anchor on every row with `MIN(CASE WHEN result = 'Positive' THEN test_date END) OVER (PARTITION BY patient_id)`.

</details>

## 4. Decomposition

The wording names two events and an order between them. Every "X followed by Y" problem decomposes the same way: compute X's anchor at entity grain, then search Y relative to it.

1. **`first_pos`: `WHERE result = 'Positive' GROUP BY patient_id`, `MIN(test_date)`.**
   *Why a GROUP BY here:* "first positive" is one date per patient, so test grain goes down to patient grain. Filtering in `WHERE` means negatives and inconclusives never reach the MIN. `MIN` skips NULL dates (Assumption 1).
2. **`recovered`: `first_pos JOIN covid_tests ON patient_id AND result = 'Negative' AND test_date > first_pos`, then `GROUP BY patient_id`, `MIN(test_date)`.**
   *Why a JOIN here:* the condition "after the anchor" compares a test row with a patient-level value, so the two grains have to meet. The join brings the anchor to the test rows. *Why an INNER join:* patients with no negative after the anchor are not recovered and must vanish. *Why `>` in `ON`:* "after" is strict, so a same-day negative is not a recovery.
3. **Final: `JOIN patients`, `DATEDIFF(first_neg_after, first_pos)`, `ORDER BY recovery_time, patient_name`.**
   *Why a JOIN last:* name and age come from `patients`, and joining after aggregation keeps the join 1:1. It is an inner join, so tests for unknown patients drop out here.

```sql
WITH first_pos AS (                              -- step 1: anchor per patient
  SELECT patient_id, MIN(test_date) AS first_pos
  FROM covid_tests
  WHERE result = 'Positive'
  GROUP BY patient_id
),
recovered AS (                                   -- step 2: first negative strictly after it
  SELECT f.patient_id, f.first_pos, MIN(n.test_date) AS first_neg_after
  FROM first_pos f
  JOIN covid_tests n
    ON  n.patient_id = f.patient_id
    AND n.result     = 'Negative'
    AND n.test_date  > f.first_pos
  GROUP BY f.patient_id, f.first_pos
)
SELECT p.patient_id, p.patient_name, p.age,      -- step 3: patient details, sort
       DATEDIFF(r.first_neg_after, r.first_pos) AS recovery_time
FROM recovered r
JOIN patients p ON p.patient_id = r.patient_id
ORDER BY recovery_time, p.patient_name;
```

Self-check: pick a patient with a negative *before* their first positive and confirm the output uses the later negative. Then pick one with two positives and confirm the anchor is the earlier positive.

## 5. Approaches: brute force → optimal

### Approach 1: correlated subqueries (`solutions/01_correlated_subqueries.sql`)

```sql
WITH per_patient AS (
  SELECT p.patient_id, p.patient_name, p.age,
         (SELECT MIN(t.test_date) FROM covid_tests t
           WHERE t.patient_id = p.patient_id AND t.result = 'Positive') AS first_pos,
         (SELECT MIN(n.test_date) FROM covid_tests n
           WHERE n.patient_id = p.patient_id AND n.result = 'Negative'
             AND n.test_date > (SELECT MIN(t.test_date) FROM covid_tests t
                                 WHERE t.patient_id = p.patient_id AND t.result = 'Positive')) AS first_neg_after
  FROM patients p
)
SELECT patient_id, patient_name, age, DATEDIFF(first_neg_after, first_pos) AS recovery_time
FROM per_patient
WHERE first_neg_after IS NOT NULL
ORDER BY recovery_time, patient_name;
```

**Why it is correct:** it is the spec, one patient at a time. The anchor subquery is repeated inside the negative subquery because a column alias from the same `SELECT` cannot be referenced there. Patients with no anchor get a NULL anchor, `n.test_date > NULL` is never true, `first_neg_after` is NULL, and the `WHERE` drops them.

**Cost model (reasoned from EXPLAIN):** three *dependent* subqueries per patient. Without an index, EXPLAIN shows each one as `Table scan on t`: the whole of `covid_tests` is read three times **per patient**, so the cost is patients × tests and grows quadratically. With `indexes.sql` (`patient_id, result, test_date`), each subquery becomes a `Covering index lookup … (patient_id=…, result='Positive')` of a few entries. The quadratic cost comes from the missing index, not from the correlated style.

### Approach 2: window anchor, one pass (`solutions/02_window_anchor_one_pass.sql`)

```sql
WITH anchored AS (
  SELECT patient_id, test_date, result,
         MIN(CASE WHEN result = 'Positive' THEN test_date END)
           OVER (PARTITION BY patient_id) AS first_pos
  FROM covid_tests
),
recovered AS (
  SELECT patient_id, first_pos,
         MIN(CASE WHEN result = 'Negative' AND test_date > first_pos THEN test_date END) AS first_neg_after
  FROM anchored
  WHERE first_pos IS NOT NULL
  GROUP BY patient_id, first_pos
)
SELECT p.patient_id, p.patient_name, p.age, DATEDIFF(r.first_neg_after, r.first_pos) AS recovery_time
FROM recovered r JOIN patients p ON p.patient_id = r.patient_id
WHERE r.first_neg_after IS NOT NULL
ORDER BY recovery_time, p.patient_name;
```

**Why it is correct:** a partition-only window computes the anchor for each patient and copies it onto every one of their rows. The second aggregate can then compare each row with it. This is the fix for the one-pass mistake: the anchor must exist *per row* before the second MIN runs.

**Cost model (reasoned from EXPLAIN):** one read of `covid_tests`, but `Window aggregate … Sort: covid_tests.patient_id` sorts **the entire table**, all result types, before anything is filtered. Then a temporary-table aggregation over all rows. With `indexes.sql`, MySQL reads the narrower index but still sorts. "One pass" sounds cheaper than two, but here that pass contains a full sort, while approach 3's two passes contain none.

### Approach 3 (optimal): aggregate the anchor, then join (`solutions/03_aggregate_then_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** `first_pos` has exactly one row per patient with a dated positive. The join keeps only negatives strictly after that patient's anchor, and the MIN picks the earliest. Patients with no such negative have no joined rows and disappear. The final join to `patients` is 1:1.

**Cost model (reasoned from EXPLAIN):** pass 1 reads the positives and aggregates them to one row per patient. Pass 2 reads the negatives and probes the anchor table through an auto-generated key (`<auto_key0>`), so it is a hash-style lookup, not a sort. With `indexes.sql`, pass 1 becomes `Covering index skip scan for grouping` and pass 2 becomes `Covering index lookup … result='Negative'` per patient. Neither pass sorts the whole table. The only sort is the final `ORDER BY` over recovered patients.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:34-find-covid-recovery-patients -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, INTEL(R) XEON(R) PLATINUM 8573C, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/34-find-covid-recovery-patients.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 162 ms | timeout >60s | timeout >60s † | > 43× |
| `02_window_anchor_one_pass` | 2.67 ms | 206 ms | 4.57 s | 3.3× |
| `03_aggregate_then_join` (optimal) | 1.68 ms | 123 ms | 1.39 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_subqueries` | 3.4 ms | 284 ms | 3.1 s | 2.5× |
| `02_window_anchor_one_pass` | 2.63 ms | 196 ms | 4.38 s | 3.5× |
| `03_aggregate_then_join` (optimal) | 1.8 ms | 113 ms | 1.25 s | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 shrinks one side to one row per patient before the comparison, and each pass reads only the result type it needs. The work is two narrow scans and a keyed lookup, with no full-table sort. With the index, both passes become index range reads. Approach 2 is the right tool when the anchor must be compared row by row with *many* later conditions. For one comparison it pays for a sort it does not need. Approach 1 is fine with the index and catastrophic without it: it times out at 100K rows without the index, and with it it even beats approach 2 at 1M rows (3.10 s vs 4.38 s). Approach 3 led at every size: 1.39 s at 1M without indexes, 3.3× faster than approach 2.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index, by a wide margin, since three full scans per patient grow quadratically. Next is approach 2's full sort, once it no longer fits in `sort_buffer_size` and spills to disk. Approach 3 degrades last.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `covid_tests (patient_id, result, test_date)`. It is covering for every approach. The column order matters: equality columns first (`patient_id`, `result`), then the range column (`test_date`), so "first positive" is the first index entry for (patient, 'Positive') and "negatives after the anchor" is a range scan.
- `(patient_id, test_date)` without `result` would serve approach 2's sort, but approach 1 and 3 would have to read every test of the patient to find the positives.
- If almost every test is Negative, the anchor pass is small and the join pass dominates. Its probe side can be restricted further with `test_date > (global minimum anchor)` (reasoned).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* approach 3 aggregates positives to one row per patient *before* the shuffle (partial MIN per task, then a small shuffle by `patient_id`). Then it shuffles only the Negative rows to join with the anchors. Approach 2 shuffles **every** test row by `patient_id` and sorts within each partition. Since MIN is decomposable, the pre-aggregation trick works and shuffle volume is roughly (#patients + #negatives) instead of #tests.
- *Broadcast:* the anchor table is one small row per positive patient. If it fits in memory, broadcast it and the negatives never shuffle at all. That is the strongest argument for approach 3's shape.
- *Pruning:* if tests are clustered by `test_date` (Snowflake micro-partitions, or a date-partitioned lake table), the negatives scan can prune with `test_date > MIN(anchor)` over the whole dataset. That only helps if the anchors are recent. For a "recovered in the last 30 days" question, push the date range into both passes.
- *Skew:* a few patients with thousands of tests (long-term monitoring) make one window partition huge in approach 2. In approach 3 the same patients cost one anchor row plus their negatives, spread across tasks before the join.

**(d) The data-engineering answer.** Recovery is a two-state machine per patient, so keep state instead of rescanning history. Maintain `patient_recovery(patient_id, first_pos, first_neg_after)` and apply each day's new tests:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED). new_tests = tests not yet applied (watermark on test_id).
MERGE INTO patient_recovery t
USING (
  SELECT patient_id,
         MIN(CASE WHEN result = 'Positive' THEN test_date END) AS batch_first_pos,
         MIN(CASE WHEN result = 'Negative' THEN test_date END) AS batch_first_neg
  FROM new_tests WHERE test_date IS NOT NULL
  GROUP BY patient_id
) s
ON t.patient_id = s.patient_id
WHEN MATCHED AND t.first_pos IS NOT NULL AND t.first_neg_after IS NULL
             AND s.batch_first_neg > t.first_pos THEN
  UPDATE SET first_neg_after = s.batch_first_neg                       -- recovery found
WHEN MATCHED AND t.first_pos IS NULL AND s.batch_first_pos IS NOT NULL THEN
  UPDATE SET first_pos = s.batch_first_pos                             -- first infection
WHEN NOT MATCHED THEN
  INSERT (patient_id, first_pos, first_neg_after)
  VALUES (s.patient_id, s.batch_first_pos, NULL);
```

This sketch is only right if batches arrive in date order. Three cases need a full recomputation of the affected patients: a positive *and* a later negative inside one new batch (the `NOT MATCHED` branch inserts the anchor but not the recovery); a batch whose earliest negative is before the stored anchor while a later one is after it (the batch MIN hides the later one); and late-arriving tests dated before the stored anchor. The robust production version recomputes approach 3 for exactly the patients that appear in the batch: `WHERE patient_id IN (SELECT patient_id FROM new_tests)`. That is still incremental (cost ∝ touched patients), and it is correct by construction.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Inconclusive between positive and negative; patients never positive / never negative / never tested; tests for an unknown patient | `tests/edge_typical.sql` | `not_positive_means_negative` (Inconclusive ends the recovery), `drive_from_tests` (unknown patient gets a row with NULL name) |
| Re-infection; two positives before the first negative; negatives after the recovery | `tests/edge_first_positive_anchor.sql` | `last_positive_anchor`, `last_negative` |
| A negative before the first positive | `tests/edge_negative_before_positive.sql` | `min_neg_after_min_pos_overall`: the one-pass `MIN(neg) > MIN(pos)` compares against the *earliest* negative, which is before the anchor |
| Negative on the same day as the first positive | `tests/edge_same_day.sql` | `same_day_negative_counts` (`>=` gives recovery 0) |
| Two patients tie on recovery time; ids run opposite to name order | `tests/edge_ordering.sql` | `order_by_id_not_name` |
| Undated positive and undated negative; NULL age | `tests/edge_nulls.sql` | `row_number_null_date_first`: MySQL sorts NULL first, so the undated positive becomes the anchor |
| Positives followed only by inconclusives; negative only before the positive | `tests/edge_no_recovery.sql` | none; every approach returns empty |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Measure from the *last* positive before the recovering negative."** The anchor now depends on the negative, so the dependency flips. For each negative, find the latest positive before it (`MAX` with `<`), and take the earliest such negative. Approach 3 becomes `negatives JOIN positives ON p.date < n.date`, grouped per negative. Watch the row explosion: it is a non-equi join.
2. **"Report each infection episode, not just the first."** Each positive that follows a negative (or starts the history) opens an episode, and the next negative closes it. That is sessionization with `LAG(result)`, the island pattern of `33-find-users-with-persistent-behavior-patterns`.
3. **"Include patients who have not recovered, with NULL recovery time."** Drive from `patients` (or from `first_pos`) with a LEFT JOIN to the negatives. Keep `n.test_date > f.first_pos` in the `ON`, never in `WHERE`, the trap from `01-market-analysis-i`.
4. **"What if results are free text: 'positive', 'POS', …?"** With the default `utf8mb4_0900_ai_ci` collation, `'positive' = 'Positive'` is already true in MySQL, because the comparison is case-insensitive. Other spellings need a mapping table. In Snowflake, comparison is case-sensitive by default, so normalise with `UPPER()` or a collation.
5. **"Why not `ROW_NUMBER()` to pick the first positive?"** It works if `test_date` is never NULL and you add a tiebreak. `MIN` is simpler, skips NULLs, and is decomposable for distributed pre-aggregation (section 6c).

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- Same SQL apart from `DATEDIFF(day, first_pos, first_neg_after)`. Snowflake's `DATEDIFF` takes a unit and puts the **start date first**, which is the opposite argument order from MySQL. Porting by copy-paste silently gives negative recovery times.
- String comparison is case-sensitive by default. `result = 'Negative'` will not match `'negative'`, unlike MySQL's default collation.
- `MIN_BY(test_date, test_date)` is not needed. If you wanted the *test_id* of the recovering negative, `MIN_BY(test_id, test_date)` gives it without a second join.
- No secondary indexes. Pruning depends on clustering by `test_date`, which helps only bounded-time variants (section 6c).

## 10. Pattern links

Same pattern (event sequencing / first event after an anchor):
- `35-find-overbooked-employees`, `37-find-zombie-sessions`: per-entity event aggregation in batch B5.
- `23-game-play-analysis-iv`: anchor = first login, then look for an event relative to it (the next day).
- `24-immediate-food-delivery-ii`: first event per key, then a condition on that first event.

Related:
- `01-market-analysis-i`: aggregate-then-join, and filter placement (ON vs WHERE) if the follow-up adds non-recovered patients.
- `36-find-churn-risk-customers`: latest event vs historical aggregates per user, the same "two facts per entity" shape.
