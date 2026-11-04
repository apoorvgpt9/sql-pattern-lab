# 35 · Find Overbooked Employees

## 1. Problem & trigger phrases

Original: [Find Overbooked Employees](https://leetcode.com/problems/find-overbooked-employees/) (LeetCode 3611, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** add up each employee's meeting hours per Monday-to-Sunday week. A week is *heavy* when that total is more than 20 hours (half of a 40-hour week). Report every employee with at least 2 heavy weeks, with their name, department and number of heavy weeks. Most heavy weeks first, then by name.

| Trigger phrase | What it forces in SQL |
|---|---|
| "per employee per week (Monday to Sunday)" | A time bucket that is **not** a column: you have to derive it. `DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)` (the Monday of the week) or `YEARWEEK(meeting_date, 1)`. `WEEK()` with its default mode starts weeks on Sunday, and `YEAR()` + `WEEK()` splits the week that contains 1 January. |
| "more than 50% … 40 hours" | The threshold is on the **week's total**, so `SUM` first and compare in `HAVING SUM(duration_hours) > 20`. "More than" is strict; see Assumptions. |
| "meeting-heavy for at least 2 weeks" | A **second** aggregation on top of the first: weeks → count per employee, `HAVING COUNT(*) >= 2`. Two `GROUP BY` levels, each with its own `HAVING`. |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `employees` | one employee | `employee_id` (PK), `employee_name`, `department` |
| `meetings` | one meeting | `employee_id` (no FK), `meeting_date`, `duration_hours`. `meeting_type` is a distractor. |

**Output grain:** one row per qualifying employee, a subset of `employees`.

**Where the grain changes:** twice, and both changes are aggregations, not joins:

1. meeting → **(employee, week)**: `SUM(duration_hours)`, keep weeks > 20.
2. (employee, week) → **employee**: `COUNT(*)` of heavy weeks, keep ≥ 2.

Most wrong answers merge the two levels. Comparing single meetings with 20 hours skips level 1. Counting meetings in heavy weeks instead of the weeks themselves collapses level 2 into level 1. Both are in `mistakes/`. Where you join `employees` is a separate choice: before the two aggregations (approach 2) or after them (approach 3).

## Assumptions

Confidence is `medium`. Each interpretation is tested by a dataset.

1. **Heavy means strictly more than 20 hours**, so a week of exactly 20.00 is not heavy. The `requirement` field and the problem statement both say "more than"; the reference solution the spec was drawn from uses `>= 20`. CLAUDE.md makes the `requirement` field the source of truth, so `> 20` it is. Tested by `tests/edge_boundary_20_hours.sql` and `tests/edge_none_qualify.sql`; `mistakes/at_least_20_hours.sql` is the `>=` version and fails both. If LeetCode's checker agrees with the reference, flip the comparison: nothing else changes.
2. **A week is identified by its Monday**, so a week that crosses 1 January is one week (`tests/edge_week_spans_new_year.sql`), and a Sunday belongs to the week of the Monday six days before it (`tests/edge_sunday_ends_week.sql`).
3. **A NULL `duration_hours` contributes nothing.** `SUM` skips it, and a week whose only meetings are NULL has a NULL total, which is not > 20 (`tests/edge_nulls.sql`).
4. **Meetings of an `employee_id` that is not in `employees` are ignored**, because the output needs a name (`tests/edge_typical.sql`, employee 99).

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **time bucketing + two-level aggregation**. Aggregate to a bucket, filter the buckets, then aggregate the buckets.

</details>

<details><summary>Hint 2</summary>

Shape: (1) derive a week key from the meeting date. (2) Total the hours per (employee, week) and keep the heavy weeks. (3) Count heavy weeks per employee and keep those with at least 2. (4) Attach name and department, then sort.

</details>

<details><summary>Hint 3</summary>

Key trick: the week key must start on Monday and must not depend on the calendar year. `DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)` (since `WEEKDAY()` is 0 on Monday) gives the Monday's date. Then use two `GROUP BY`s, each with its own `HAVING`: `SUM(...) > 20` and `COUNT(*) >= 2`.

</details>

## 4. Decomposition

Read the conditions from the inside out. The innermost noun ("hours in a week") is a sum, the next ("weeks that are heavy") is a filter on those sums, and the outermost ("at least 2 such weeks") is a count of what survived. Each layer is one CTE.

1. **`weekly`: `GROUP BY employee_id, week_start` with `week_start = DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)`, keeping `HAVING SUM(duration_hours) > 20`.**
   *Why a GROUP BY here:* "per employee per week" names the grain directly, and the threshold is on the week's total, so it must be compared after summing. That makes it `HAVING`, not `WHERE`. *Why this week key:* `WEEKDAY()` is 0 on Monday and 6 on Sunday, so subtracting it gives the Monday. A real date sorts correctly and never splits a week at the year end.
2. **`counted`: `GROUP BY employee_id`, `COUNT(*)`, `HAVING COUNT(*) >= 2`.**
   *Why a second GROUP BY:* "for at least 2 weeks" counts rows of step 1, which is a different grain from step 1's input. Every row of `weekly` is a heavy week, so `COUNT(*)` is exactly the number of heavy weeks.
3. **Final: `JOIN employees`, `ORDER BY meeting_heavy_weeks DESC, employee_name`.**
   *Why the join is last:* name and department are only needed for the few employees who qualify. Joining after both aggregations keeps it 1:1 and keeps the wide columns out of the aggregations. It is an inner join, so meetings of unknown employees drop out.

```sql
WITH weekly AS (                                         -- step 1: meeting -> (employee, week)
  SELECT employee_id,
         DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY) AS week_start,
         SUM(duration_hours) AS week_hours
  FROM meetings
  GROUP BY employee_id, DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)
  HAVING SUM(duration_hours) > 20
),
counted AS (                                             -- step 2: (employee, week) -> employee
  SELECT employee_id, COUNT(*) AS meeting_heavy_weeks
  FROM weekly
  GROUP BY employee_id
  HAVING COUNT(*) >= 2
)
SELECT e.employee_id, e.employee_name, e.department,     -- step 3: details, sort
       c.meeting_heavy_weeks
FROM counted c
JOIN employees e ON e.employee_id = c.employee_id
ORDER BY c.meeting_heavy_weeks DESC, e.employee_name;
```

Self-check: find a Sunday meeting in your data and confirm its `week_start` is the Monday six days earlier. Then check a week that contains 1 January.

## 5. Approaches: brute force → optimal

### Approach 1: correlated weekly count per employee (`solutions/01_correlated_weekly_count.sql`)

```sql
SELECT e.employee_id, e.employee_name, e.department,
       (SELECT COUNT(*)
          FROM (SELECT SUM(m.duration_hours) AS week_hours
                  FROM meetings m
                 WHERE m.employee_id = e.employee_id
                 GROUP BY DATE_SUB(m.meeting_date, INTERVAL WEEKDAY(m.meeting_date) DAY)) w
         WHERE w.week_hours > 20) AS meeting_heavy_weeks
FROM employees e
-- then WHERE meeting_heavy_weeks >= 2 ORDER BY ... (via a CTE)
```

**Why it is correct:** for each employee, the derived table builds that employee's weekly totals, and the outer `COUNT(*)` counts those over 20. It is the spec read one employee at a time. MySQL 8.0.14 and later accept the outer reference `e.employee_id` inside a derived table. Older versions and some other engines do not, and need `LATERAL` or a rewrite.

**Cost model (reasoned from EXPLAIN):** a *dependent* subquery per employee. Without an index, each one is a `Table scan on m` of the whole `meetings` table plus a temporary-table aggregation, so the cost is employees × meetings, which is quadratic. With `indexes.sql`, each run becomes a `Covering index lookup … (employee_id=e.employee_id)` that reads only that employee's meetings, and the total is roughly linear. Employees with no meetings still pay for one probe each.

### Approach 2: join, then two-level GROUP BY (`solutions/02_join_then_two_level_group.sql`)

```sql
WITH heavy_weeks AS (
  SELECT e.employee_id, e.employee_name, e.department, YEARWEEK(m.meeting_date, 1) AS yw
  FROM employees e
  JOIN meetings m ON m.employee_id = e.employee_id
  GROUP BY e.employee_id, e.employee_name, e.department, YEARWEEK(m.meeting_date, 1)
  HAVING SUM(m.duration_hours) > 20
)
SELECT employee_id, employee_name, department, COUNT(*) AS meeting_heavy_weeks
FROM heavy_weeks
GROUP BY employee_id, employee_name, department
HAVING COUNT(*) >= 2
ORDER BY meeting_heavy_weeks DESC, employee_name;
```

**Why it is correct:** the same two levels as section 4, with the join done first. `YEARWEEK(d, 1)` is a Monday-start key that gives the whole week to one year (2024-12-30 → 202501), so it is equivalent to the week-start date as a grouping key. It is just less readable.

**Cost model (reasoned from EXPLAIN):** a nested-loop join of every meeting to its employee (a primary-key lookup per meeting), then two `Aggregate using temporary table` steps. The first aggregation's rows carry `employee_name` and `department`, so the temporary table is wider than it needs to be, and the group key is four columns instead of two.

### Approach 3 (optimal): aggregate twice, then join (`solutions/03_aggregate_twice_then_join.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** both aggregations run on `meetings` alone, and each `HAVING` applies its threshold at its own grain. The final join is from at most one row per employee to a primary key, so it neither duplicates nor drops qualifying employees.

**Cost model (reasoned from EXPLAIN):** one scan of `meetings` (or of the covering index) into a narrow (employee, week) aggregation, a second aggregation over heavy weeks only, then `Index lookup on c using <auto_key0>` from `employees`. Wide columns enter only at the end, for the survivors. One caveat: the week key is an *expression*, so even with `indexes.sql`, MySQL still uses a temporary table for step 1 (EXPLAIN keeps `Aggregate using temporary table`). The index makes the scan narrower but does not let the group-by stream.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:35-find-overbooked-employees -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, INTEL(R) XEON(R) PLATINUM 8573C, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/35-find-overbooked-employees.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_weekly_count` | 10.5 ms | timeout >60s | timeout >60s † | > 31× |
| `02_join_then_two_level_group` | 1.72 ms | 115 ms | 4.24 s | 2.2× |
| `03_aggregate_twice_then_join` (optimal) | 1.38 ms | 75.4 ms | 1.94 s | 1.0× |

† not run at this size: it already timed out at a smaller size.

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_weekly_count` | 1.58 ms | 73.6 ms | 828 ms | 0.5× |
| `02_join_then_two_level_group` | 1.67 ms | 115 ms | 3.79 s | 2.3× |
| `03_aggregate_twice_then_join` (optimal) | 1.33 ms | 75.2 ms | 1.66 s | 1.0× |

A ratio below 1.0× means that approach was faster than the one labelled optimal here.

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does all the heavy work on the narrow fact table and joins only the handful of survivors. The intermediate results shrink at every step: meetings, then heavy weeks, then qualifying employees. Approach 2 does the same aggregations but drags the employee columns through them. That costs a little on one machine and a lot more when the join forces a shuffle (section 6c). Approach 1 is only competitive with the index, and it still pays one probe per employee, including employees without meetings.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index, because it rescans `meetings` once per employee. Then the temporary tables of approaches 2 and 3, once (employee, week) groups outgrow `tmp_table_size` and spill to disk. Approach 2 reaches that point sooner because its rows are wider.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `meetings (employee_id, meeting_date, duration_hours)`. It is covering, turns approach 1 into per-employee range reads, and narrows the scan for 2 and 3.
- Making step 1 stream instead of using a temporary table would need the week key to be an indexed column. MySQL 8.0 can index a **functional key part**, `INDEX ((DATE_SUB(meeting_date, INTERVAL WEEKDAY(meeting_date) DAY)))`, or a stored generated column `week_start`. With (`employee_id`, `week_start`) indexed, the `GROUP BY` can read in key order. This is reasoned and not benchmarked: it is a schema change, which is why it is not in `indexes.sql`.
- Bound the date range whenever the question allows it ("in the last quarter"). The week grouping itself cannot prune anything.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* step 1 groups by (`employee_id`, `week_start`) and step 2 by `employee_id`. If the engine partitions step 1's shuffle by `employee_id` alone (a valid partitioning for both keys), step 2 needs no second shuffle. Spark does this when the first aggregation's output is already partitioned compatibly, which you can force with `repartition(employee_id)` before step 1. `SUM` and `COUNT` are decomposable, so map-side partial aggregation shrinks the shuffle to about one row per (employee, week) per task.
- *Join placement:* in approach 2, joining `employees` first shuffles (or broadcasts) every meeting with the name and department attached. In approach 3, the join input is the few qualifying employees, which you can broadcast for free.
- *Pruning:* Snowflake prunes on `meeting_date` only for bounded questions. Note that a week that straddles the range start would be cut, so align range boundaries to Mondays.
- *Week definitions differ by engine:* Snowflake's `WEEK()` and `DATE_TRUNC('week', …)` depend on the `WEEK_START` session parameter. Spark's `date_trunc('week', …)` is Monday-based. Never assume, and test a Sunday (section 9).

**(d) The data-engineering answer.** Weeks close, so materialise them. Keep `employee_week_hours(employee_id, week_start, hours)` and fold each day's meetings into it. The question then reads a small table:

```sql
-- Snowflake / ANSI MERGE (UNVERIFIED). meetings_batch = meetings not yet applied (watermark on meeting_id).
MERGE INTO employee_week_hours t
USING (
  SELECT employee_id,
         DATE_TRUNC('week', meeting_date) AS week_start,     -- Monday only if WEEK_START = 1 (see section 9)
         SUM(duration_hours) AS hours
  FROM meetings_batch
  WHERE duration_hours IS NOT NULL
  GROUP BY 1, 2
) s
ON t.employee_id = s.employee_id AND t.week_start = s.week_start
WHEN MATCHED THEN UPDATE SET hours = t.hours + s.hours
WHEN NOT MATCHED THEN INSERT (employee_id, week_start, hours) VALUES (s.employee_id, s.week_start, s.hours);

-- The question becomes steps 2-3 over the small table:
SELECT e.employee_id, e.employee_name, e.department, COUNT(*) AS meeting_heavy_weeks
FROM employee_week_hours w JOIN employees e ON e.employee_id = w.employee_id
WHERE w.hours > 20
GROUP BY e.employee_id, e.employee_name, e.department
HAVING COUNT(*) >= 2
ORDER BY meeting_heavy_weeks DESC, e.employee_name;
```

Caveats that interviewers probe. *Idempotency*: an additive MERGE double-counts a re-applied batch, so watermark on `meeting_id` or recompute the touched (employee, week) keys from the base table. *Corrections*: a meeting whose duration, date or employee changes needs a retraction from the old key and an addition to the new one, via a change feed with before and after images. *Threshold changes*: because the stored table keeps raw weekly hours, not a heavy flag, a policy change (20 → 25) needs no backfill.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Heavy weeks built from several meetings (one day with two meetings); a non-heavy week; an employee with one heavy week; an unknown employee_id | `tests/edge_typical.sql` | `sum_per_meeting_not_week`, `count_meetings_in_heavy_weeks`, `calendar_month_not_week`, `drive_from_meetings` |
| Week totals of exactly 20.00, 20.01, 20.25 (Assumption 1) | `tests/edge_boundary_20_hours.sql` | `at_least_20_hours` |
| Sunday meetings belong with the previous Monday | `tests/edge_sunday_ends_week.sql` | `sunday_start_week` (`YEARWEEK(d)` default mode), `sum_per_meeting_not_week` |
| One week from 2024-12-30 to 2025-01-05 | `tests/edge_week_spans_new_year.sql` | `year_plus_week_number` (`YEAR()` + `WEEK(d, 1)` splits it), `sum_per_meeting_not_week` |
| NULL duration; a week whose only meeting is NULL; NULL department | `tests/edge_nulls.sql` | none; `SUM` already skips NULL |
| Tie on heavy-week count; ids run opposite to name order | `tests/edge_ordering.sql` | `calendar_month_not_week` (two May weeks merge) |
| One heavy week plus one week of exactly 20.00 | `tests/edge_none_qualify.sql` | `at_least_20_hours` |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Only Client meetings count."** Add `WHERE meeting_type = 'Client'` in step 1. It is a row filter before the first aggregation, so it belongs in `WHERE`, not `HAVING`.
2. **"Heavy weeks must be consecutive."** Step 2 becomes a gaps-and-islands problem on `week_start`: label runs with `DATE_SUB(week_start, INTERVAL 7 * ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY week_start) DAY)`. Same move as `33-find-users-with-persistent-behavior-patterns`, with a 7-day step.
3. **"Include weeks with zero meetings as non-heavy, and report the share of heavy weeks."** Now the denominator needs weeks that have no rows, so you need a week spine (a generated calendar) cross-joined with employees and LEFT JOINed to the weekly totals. See `30-calculate-a-rolling-average-of-total-revenue`.
4. **"Overlapping meetings shouldn't double-count."** With start and end times, the hours become the length of the *union* of intervals per employee per week. That is a merge-intervals problem: sort by start, start a new group when start > the running `MAX(end)` of the previous rows, then sum group lengths.
5. **"Why not `WEEK(meeting_date)`?"** Its default mode 0 starts on Sunday, and on its own it has no year. Mode 1 fixes the start day, but `WEEK(d, 1)` still numbers the 2024-12-30 week as 53 of 2024 while 2025-01-02 is week 1 of 2025. `YEARWEEK(d, 1)` or a week-start date solves both.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `DATE_TRUNC('week', meeting_date)` returns the first day of the week, but **which day depends on the `WEEK_START` session parameter** (default 0 means legacy Monday-based behaviour; accounts and sessions can change it). `snowflake.sql` avoids the dependency by computing the Monday explicitly: `DATEADD(day, -(DAYOFWEEKISO(meeting_date) - 1), meeting_date)`. `DAYOFWEEKISO` is 1 on Monday regardless of `WEEK_START`.
- `COUNT_IF(week_hours > 20)` could merge steps 1–2 into a single level over weekly totals, but the weekly totals still need their own `GROUP BY`. Two levels remain.
- There are no indexes. Clustering on `meeting_date` helps only date-bounded variants, and `employee_id` clustering is not worth its reclustering cost for this query.

## 10. Pattern links

Same pattern (time bucketing, two-level aggregation):
- `04-monthly-transactions-i`: bucket a date to a month (`DATE_FORMAT`), then aggregate per bucket.
- `37-find-zombie-sessions`: per-session aggregation with several `HAVING` thresholds.
- `29-restaurant-growth`: pre-aggregate to a day grain before the next step.

Related:
- `33-find-users-with-persistent-behavior-patterns`: islands on dates, the "consecutive heavy weeks" follow-up.
- `30-calculate-a-rolling-average-of-total-revenue`: calendar spine, for follow-up 3.
- `34-find-covid-recovery-patients`: aggregate first, join the small result last.
