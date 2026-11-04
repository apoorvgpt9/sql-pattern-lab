# 30 · Calculate a rolling average of total revenue

## 1. Problem & trigger phrases

Original: [Calculate a rolling average of total revenue](https://pgexercises.com/questions/aggregates/rollingavg.html) (pgexercises, hard).

> Adapted from PostgreSQL Exercises by Alisdair Owens (pgexercises.com), CC BY-SA 3.0. Spec reworded. See `LICENSE.md`.

**Spec (own words):** a booking earns `slots × price`, where the price per slot is the facility's `guestcost` if the booking was made by the shared guest account (`memid = 0`) and its `membercost` otherwise. For every calendar date in August 2012 (31 rows), report the revenue of that date and the 14 days before it (July days included) divided by 15, counting days without bookings as 0. Sort by date.

| Trigger phrase | What it forces in SQL |
|---|---|
| "for each day in August 2012" | The output rows come from a **calendar**, not from `bookings`. All 31 dates must appear, including dates with no booking. MySQL 8.0 has no `generate_series`, so build the dates with a recursive CTE. The calendar must start 14 days *before* Aug 1, because the first windows reach into July. |
| "previous 15 days" | A trailing window of 15 calendar days: the date and the 14 before it. On a gap-free calendar that is `SUM(...) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW)`. |
| "a day having zero revenue" | Zero-fill: `LEFT JOIN` the daily revenue onto the calendar and `COALESCE(..., 0)`. The divisor is always 15, never the number of days that had bookings. |

Also notice: `members` is a distractor. The guest account is identified by `memid = 0` in `bookings` itself, so no join to `members` is needed. Facility prices live in `facilities`.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `bookings` | one booking of one facility | `facid` (price lookup), `memid` (0 = guest), `starttime` (decides the day), `slots` (30-minute slots) |
| `facilities` | one facility and its prices | `facid`, `membercost`, `guestcost` per slot |
| `members` | one member; `memid` 0 is the guest account | not needed |

**Output grain:** exactly 31 rows, one per August 2012 date. The row count must be 31 whatever is in `bookings`.

**Where the grain changes:**
1. *Booking → booking revenue:* join `facilities`, pick the price by `memid = 0`. Still one row per booking.
2. *Booking → day:* `GROUP BY` the date of `starttime`, `SUM(revenue)`. Dates without bookings do not exist yet.
3. *Day with bookings → every calendar day:* `LEFT JOIN` onto the calendar, `COALESCE` to 0. This is the step that a query driven from `bookings` can never do.
4. *Calendar day → window total:* a window adds a column and keeps the grain. A final filter drops the 14 July rows that were only there as history.

## Assumptions

`confidence` is `high`. Readings we fix, and where they are tested:

1. A booking's revenue belongs to the **date on which it starts** (`starttime`), even if its slots run past midnight (up to 8 slots = 4 hours could). Tested at the day edges in `tests/edge_window_boundaries.sql` (23:30, 23:59:59, 00:00:00).
2. The window is **15 calendar days** (the date and the 14 before), starting 2012-07-18 for Aug 1, and **July bookings count**. Tested in `tests/edge_typical.sql` and `tests/edge_window_boundaries.sql`.
3. `revenue` is **not rounded**, as in the exercise. In MySQL, a `DECIMAL(10,2)` total divided by 15 carries 6 decimals (`170.00/15 = 11.333333`) because the division adds 4 digits to the scale; the harness compares numbers at 5 decimals.
4. The `date` column is a `DATE`.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **date spine + zero-fill + moving window**. First make sure every date exists as a row, then slide a 15-row window over daily revenue.

</details>

<details><summary>Hint 2</summary>

Shape: (1) a calendar from 14 days before Aug 1 to Aug 31. (2) Revenue per booking, using the guest or member price, then total per day. (3) Attach daily revenue to the calendar, with 0 for empty days. (4) Sum each day with the 14 days before it, divide by 15. (5) Keep only August and sort.

</details>

<details><summary>Hint 3</summary>

Key trick: reduce first, then spine. Filter `bookings` with a range on the raw column (`starttime >= '2012-07-18' AND starttime < '2012-09-01'`), aggregate to one row per day, and only then `LEFT JOIN` that small result onto the calendar. Because the calendar has no gaps, a `ROWS BETWEEN 14 PRECEDING` frame means exactly 15 days. In MySQL, `WITH RECURSIVE calendar AS (SELECT DATE '2012-07-18' AS day UNION ALL SELECT day + INTERVAL 1 DAY FROM calendar WHERE day < DATE '2012-08-31')`.

</details>

## 4. Decomposition

Read the wording as: *which rows to output* (dates), *what to compute per date* (revenue), *over what window* (15 days), *how to treat quiet days* (zero).

1. **`calendar`: dates 2012-07-18 .. 2012-08-31 (recursive CTE).**
   *Why a generated table here:* "for each day in August" means rows must exist for days with no data. A recursive CTE is the MySQL way to create them. It starts 14 days early because the Aug 1 window needs July.
2. **`booked`: join `facilities`, `slots * CASE WHEN memid = 0 THEN guestcost ELSE membercost END`, filter to the date range, `GROUP BY DATE(starttime)`.**
   *Why a join, a CASE and a GROUP BY here:* the price lives in `facilities` (join); guest vs member is a per-booking choice (CASE on `memid`); "revenue of a day" is a total over bookings (GROUP BY). The range filter goes on the raw column so it stays usable for an index.
3. **`daily`: `calendar LEFT JOIN booked`, `COALESCE(revenue, 0)`.**
   *Why a LEFT JOIN here:* the calendar is the frame that must survive. Joining the other way (or inner) deletes the quiet days, which are part of the answer.
4. **`windowed`: `SUM(revenue) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW)`.**
   *Why a window here:* each output depends on neighbouring days but all days stay in the result. `ROWS` is exact only because step 3 guarantees one row per day with no gaps.
5. **Divide by 15, keep `day >= '2012-08-01'`, order by day.**
   *Why here:* the divisor is the window length, always 15 (zero days included). The filter removes the July history rows after they have served the August windows.

Assembled:

```sql
WITH RECURSIVE calendar AS (                                                  -- step 1
  SELECT DATE '2012-07-18' AS day
  UNION ALL
  SELECT day + INTERVAL 1 DAY FROM calendar WHERE day < DATE '2012-08-31'
),
booked AS (                                                                   -- step 2
  SELECT DATE(b.starttime) AS day,
         SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
  FROM bookings b
  JOIN facilities f ON f.facid = b.facid
  WHERE b.starttime >= '2012-07-18' AND b.starttime < '2012-09-01'
  GROUP BY DATE(b.starttime)
),
daily AS (                                                                    -- step 3
  SELECT c.day, COALESCE(k.revenue, 0) AS revenue
  FROM calendar c LEFT JOIN booked k ON k.day = c.day
),
windowed AS (                                                                 -- step 4
  SELECT day, SUM(revenue) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW) AS window_total
  FROM daily
)
SELECT day AS `date`, window_total / 15 AS revenue                            -- step 5
FROM windowed
WHERE day >= DATE '2012-08-01'
ORDER BY day;
```

Self-check before you submit: the result has exactly 31 rows even on an empty `bookings` table. Pick one day and add the 15 daily figures by hand.

## 5. Approaches: brute force → optimal

### Approach 1: a correlated sum per August date (`solutions/01_correlated_sum_per_day.sql`)

```sql
WITH RECURSIVE august AS (
  SELECT DATE '2012-08-01' AS day
  UNION ALL SELECT day + INTERVAL 1 DAY FROM august WHERE day < DATE '2012-08-31'
)
SELECT a.day AS `date`,
       (SELECT COALESCE(SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END), 0)
          FROM bookings b JOIN facilities f ON f.facid = b.facid
         WHERE b.starttime >= a.day - INTERVAL 14 DAY
           AND b.starttime <  a.day + INTERVAL 1 DAY) / 15 AS revenue
FROM august a
ORDER BY a.day;
```

**Why it is correct:** the 31 August dates are the output rows; for each, a subquery totals the revenue of every booking from midnight 14 days earlier up to (not including) midnight of the next day, which is exactly the 15-day window. `COALESCE` turns an empty window into 0. The "< next midnight" bound includes bookings made late on the day itself.

**Cost model (reasoned):** 31 separate scans of the bookings, each reading its window and joining every booking to `facilities`. A booking in the middle of the period lies in 15 different windows, so it is read and priced 15 times. Without an index each scan is a full table scan; with `indexes.sql` each is an index range scan, but the repeated reading and pricing remain. The work scales with 15 × (bookings in the period).

### Approach 2: calendar join first, then a window (`solutions/02_calendar_join_then_window.sql`)

```sql
WITH RECURSIVE calendar AS (...),          -- 2012-07-18 .. 2012-08-31
daily AS (
  SELECT c.day,
         COALESCE(SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END), 0) AS revenue
  FROM calendar c
  LEFT JOIN bookings   b ON DATE(b.starttime) = c.day
  LEFT JOIN facilities f ON f.facid = b.facid
  GROUP BY c.day
),
windowed AS (
  SELECT day, SUM(revenue) OVER (ORDER BY day ROWS BETWEEN 14 PRECEDING AND CURRENT ROW) AS window_total FROM daily
)
SELECT day AS `date`, window_total / 15 AS revenue FROM windowed WHERE day >= DATE '2012-08-01' ORDER BY day;
```

**Why it is correct:** the calendar drives the `LEFT JOIN`, so all 45 days survive and empty days come out as one NULL-booking row summed to 0. The calendar has one row per day, so the `ROWS` frame is 15 days.

**Cost model (reasoned):** one pass over bookings, but with no range filter on the raw column: `DATE(starttime)` is a function on the column, so MySQL cannot use an index range and has to compare every booking in the table with the calendar. The history grows forever, while the question only concerns 45 days. The join is at booking grain (joined rows = matched bookings) and only then grouped.

### Approach 3 (optimal): filter, aggregate to days, then the calendar (`solutions/03_filter_aggregate_then_spine.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** same logic as approach 2, but the bookings are reduced first: only the 45 relevant days are read, and they are aggregated to one row per day before touching the calendar. The calendar join is therefore 45 rows against at most 45 rows.

**Cost model (reasoned):** with `indexes.sql`, one range scan over the 45 days of bookings (covering, so no table lookups), a `GROUP BY` on the date, and everything after that is tiny. Each booking is read and priced once, not up to 15 times as in approach 1, and bookings outside the period are never read. Without the index it is one table scan with a cheap filter.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:30-calculate-a-rolling-average-of-total-revenue -->
_Measured 2026-11-04 by the bench workflow: MySQL 8.0.46, AMD EPYC 7763 64-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/30-calculate-a-rolling-average-of-total-revenue.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_sum_per_day` | 13.3 ms | 1.19 s | 11.8 s | 21.0× |
| `02_calendar_join_then_window` | 1.79 ms | 86.2 ms | 747 ms | 1.3× |
| `03_filter_aggregate_then_spine` (optimal) | 1.69 ms | 58.5 ms | 564 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_sum_per_day` | 13.5 ms | 1.18 s | 11.8 s | 48.1× |
| `02_calendar_join_then_window` | 1.73 ms | 72.5 ms | 547 ms | 2.2× |
| `03_filter_aggregate_then_spine` (optimal) | 1.62 ms | 32.7 ms | 245 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 does the expensive work (reading and pricing bookings) exactly once per booking, restricts it to the 45 days that matter using a range on the raw column, and leaves only a 45-row calendar and a 45-row window to do the clever part. Approach 1 re-reads each booking in every window it belongs to; approach 2 reads the whole history because of the function on `starttime`. The shape (filter, aggregate, then join to the spine) is the general lesson: shrink the big table before attaching the scaffold.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 pays about 15 times for every booking in the period, and that multiplier (the window length) grows with a longer window. Approach 2 breaks as the booking history grows, since it reads all of it for a 45-day question. Approach 3 grows with the bookings *in the period* only.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `bookings (starttime, facid, memid, slots)`: covering, in time order. Approach 3's range predicate becomes a bounded index range scan that reads only the 45 days; approach 1's scans become range scans too (each still revisits its 15 days).
- Keep the predicate on the raw column. `DATE(starttime) BETWEEN ...` or `YEAR(...)` forms cannot use the index for a range.
- For history measured in years, `PARTITION BY RANGE` on `starttime` (by month) lets MySQL read only the July–September partitions (reasoned). The primary key would have to include `starttime`, which is a real migration cost.
- If this report runs every day, keep a `daily_revenue` table (section 6d) and run the window over its few thousand rows.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Pruning:* a range on `starttime` over a table clustered or partitioned by time reads only the micro-partitions or files for 45 days, which is the biggest single saving.
- *Join and shuffle:* `facilities` is tiny, so it is broadcast to every task (no shuffle of bookings for the price lookup). `SUM` is decomposable, so each task pre-aggregates revenue per day and the shuffle carries about one row per (task, day). The window and the calendar then operate on 45 rows.
- *The window has no `PARTITION BY`:* on a single partition. That is fine on 45 rows and would not be on raw bookings. Always aggregate first.
- *Calendar:* `GENERATOR` / `sequence` produces it in the engine without reading data.
- *Exactness:* this is money, so no approximate functions. Beware of float types for prices: use `DECIMAL`.

**(d) The data-engineering answer.** Daily revenue is a small, slowly-changing summary, so maintain it and put the window over it. Recompute the days that a batch touches, not add increments, because bookings can be edited or cancelled:

```sql
-- daily_revenue(day PRIMARY KEY, revenue). Recompute only the days touched by the batch of new/changed bookings.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO daily_revenue t
USING (
  SELECT d.day, COALESCE(SUM(b.slots * IFF(b.memid = 0, f.guestcost, f.membercost)), 0) AS revenue
  FROM (SELECT DISTINCT starttime::DATE AS day FROM booking_changes) d      -- days touched by the batch
  LEFT JOIN bookings b   ON b.starttime >= d.day AND b.starttime < DATEADD(day, 1, d.day)
  LEFT JOIN facilities f ON f.facid = b.facid
  GROUP BY d.day
) s ON t.day = s.day
WHEN MATCHED THEN UPDATE SET revenue = s.revenue
WHEN NOT MATCHED THEN INSERT (day, revenue) VALUES (s.day, s.revenue);

-- MySQL equivalent (no MERGE): INSERT ... SELECT ... ON DUPLICATE KEY UPDATE revenue = VALUES(revenue).
-- The report: approach 3's calendar + window over daily_revenue (45 rows) instead of over bookings.
```

Caveats: the recompute is idempotent (re-running a batch gives the same table), unlike an additive update. Days with no bookings need no row if the report keeps the `LEFT JOIN` to a calendar. A price change in `facilities` (a back-dated one) invalidates every affected day, so store the price with the booking or recompute the range.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`). Every dataset has 31 expected rows.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| July bookings reach into the first August windows; quiet days; a window that ends; guest vs member prices; a booking at 23:30 on Aug 31; a September booking | `tests/edge_typical.sql` | `calendar_starts_aug_1`, `no_calendar`, `fourteen_day_window`, `sixteen_day_window`, `guest_cost_for_all`, `guest_rule_inverted`, `rounded_revenue`, `midnight_cutoff`, `order_descending` |
| Window edges: 07-17 23:30 (one day too early), 07-18 00:00 (first instant of the Aug 1 window), 08-31 23:59:59, 09-01 00:00 | `tests/edge_window_boundaries.sql` | `sixteen_day_window`, `fourteen_day_window`, `midnight_cutoff`, `calendar_starts_aug_1` |
| All four guest/member × price-0/fractional-price combinations on one day | `tests/edge_member_vs_guest.sql` | `guest_cost_for_all`, `guest_rule_inverted`, `rounded_revenue` |
| No bookings at all: still 31 rows of 0 | `tests/edge_no_bookings.sql` | `no_calendar` (returns nothing) |
| Output order: bookings inserted out of date order | `tests/edge_ordering.sql` | `order_descending`, `fourteen_day_window`, `sixteen_day_window`, `guest_rule_inverted` |

No approach in `solutions/` is broken by any of these. The expected values are derived by hand from the booking prices (the comment on each row shows the window and the arithmetic).

## 8. Interviewer follow-ups

1. **"Do it for every month of 2012."** Generate the calendar for the whole year (plus the 14 days before January). The first 14 days of January then have incomplete windows; decide whether to divide by 15 anyway (treats the missing history as zero) or to drop those days.
2. **"Per facility."** The grid becomes (facility, day). Scaffold it with `facilities CROSS JOIN calendar`, `LEFT JOIN` the revenue, and use `PARTITION BY facid` in the window. Without the cross-joined scaffold, a facility with a quiet day silently loses the row and `ROWS` stops meaning days.
3. **"Why not `AVG(revenue) OVER (...)`?"** On a gap-free calendar with full windows it gives the same number. On the first rows of a calendar it divides by fewer than 15. Dividing by 15 states the rule from the spec. And `AVG` over booking rows (not days) is a different number.
4. **"What if bookings span midnight?"** Revenue would have to be split across days. That needs a spine of slots (generate each 30-minute slot, then group), a bigger rewrite and a different answer.
5. **"Make the window size a parameter."** Replace 14 and 15 with `N − 1` and `N`, and start the calendar `N − 1` days before the first output date.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- **Calendar from `GENERATOR`:** `TABLE(GENERATOR(ROWCOUNT => 45))` replaces the recursive CTE. `ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1` is used because `SEQ4()` on its own may have gaps. There is no recursion limit to worry about.
- **`IFF(memid = 0, guestcost, membercost)`** replaces the `CASE`; `starttime::DATE` replaces `DATE(starttime)`.
- **Pruning replaces indexes:** there are no secondary indexes, but a range predicate on the raw column `starttime` lets Snowflake skip every micro-partition outside the 45 days if the table is roughly ordered by time (or clustered by `starttime`). `DATE(starttime)` forms prune less reliably.
- Date-based windows are also possible with `RANGE BETWEEN INTERVAL '14 days' PRECEDING AND CURRENT ROW`, but on a gap-free calendar `ROWS` is equivalent and simpler.
- The number of decimals in the division result can differ from MySQL's 6 (the scale rules differ). The values agree; if you need a fixed scale, cast explicitly. This file is not run by CI.
- Unquoted identifiers are upper-cased in the result: `DATE`, `REVENUE`.

## 10. Pattern links

Same pattern (date spine, zero-fill, moving window):
- `29-restaurant-growth`: the same moving window when the guarantee "every day has data" makes a spine unnecessary.
- `09-count-salary-categories`: generating the rows that exist in no table, then `LEFT JOIN` the counts onto them.

Related:
- `01-market-analysis-i`: `LEFT JOIN` preservation with a zero instead of a NULL.
- `04-monthly-transactions-i`: bucketing by date before aggregating.
- `28-last-person-to-fit-in-the-bus`: running totals with a different frame (unbounded, with a threshold).
- `35-find-overbooked-employees`: time bucketing with two-level aggregation.
