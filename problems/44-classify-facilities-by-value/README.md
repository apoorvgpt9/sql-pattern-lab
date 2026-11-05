# 44 · Classify facilities by value

## 1. Problem & trigger phrases

Original: [Classify facilities by value](https://pgexercises.com/questions/aggregates/classify.html) (pgexercises, medium; no difficulty label on the site, rated by the curator).

> Adapted from PostgreSQL Exercises by Alisdair Owens (pgexercises.com), CC BY-SA 3.0. Spec reworded. See `LICENSE.md`.

**Spec (own words):** a booking earns `slots × guestcost` if it was made by the guest account (memid 0), otherwise `slots × membercost`. Total each facility's revenue over its bookings, considering only facilities that have bookings. Rank facilities by revenue, highest first, and split them into three groups of sizes as equal as possible, with any extra facilities going to the earlier groups. Label the groups `high`, `average` and `low`. Output each facility's name and its label, in a column called `revenue`. Sort by group (high first), then by name. The original is PostgreSQL; this folder uses MySQL 8.0, without the `cd.` prefix, and with its own generated data.

| Trigger phrase | What it forces in SQL |
|---|---|
| "equally sized groups" | Group sizes are decided by **count**, not by revenue thresholds. That is `NTILE(3) OVER (ORDER BY revenue DESC)`: rows are dealt out by position, and with n not divisible by 3 the first groups get one extra row. Value-based cut-offs (thirds of the max revenue) or `RANK`-based groups give different sizes. |
| "high, average, and low" | Map bucket 1/2/3 to labels with `CASE`. Keep the **bucket number** for sorting: the labels sort alphabetically as `average < high < low`, which is not the required order. |
| "based on their revenue" | Two levels of aggregation. First compute revenue per facility (a `GROUP BY` over bookings), then rank the facilities (a window over the grouped rows). A window function cannot see a total that has not been computed yet, so the aggregate must come first, in a CTE or a derived table. |

Also notice: the output column called `revenue` holds the **label**, not a number. And "facilities with bookings" means an inner join: a facility nobody booked is not ranked at all, not ranked last with 0.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `bookings` | one booking of one facility by one member (or the guest) | `facid`, `memid` (0 = guest), `slots` |
| `facilities` | one facility, with its two prices | `facid` (PK), `name`, `membercost`, `guestcost`. `initialoutlay` and `monthlymaintenance` are not needed. |

**Output grain:** one row per facility that has at least one booking.

**Where the grain changes, and the order it must happen in:**
1. *Booking grain*: price each booking. The price depends on a booking attribute (`memid = 0`) and a facility attribute (the two costs), so the booking must meet its facility's prices, through a join or after aggregating.
2. *Facility grain*: `GROUP BY facid`, sum. Every booking collapses into one revenue number per facility.
3. *Ranking over facilities*: `NTILE(3)` looks across all facility rows at once. This does not change the grain; it adds a bucket to each facility row. It must run **after** step 2: a window is evaluated after `GROUP BY` in the same `SELECT`, so `NTILE(3) OVER (ORDER BY SUM(...) DESC)` in the grouped query would also work. A window over the raw bookings would rank bookings, not facilities.

## Assumptions

1. **Ties on revenue are broken by `facid` ascending.** NTILE is positional: it deals rows out in the window's order, so two facilities with equal revenue at a group boundary land in different groups. The spec accepts that ("equal revenues may land in different buckets"), but it does not say *which* of the tied facilities goes first. With `ORDER BY revenue DESC` alone, MySQL may order the ties any way, so the expected output would be undefined. Every solution here uses `ORDER BY revenue DESC, facid ASC`. *Tested:* `tests/edge_revenue_ties.sql` puts two facilities with revenue 30 across the high/average boundary, with names in the opposite order to their facids, so only the facid rule produces the expected rows. The generator also makes more than a third of all facilities tie at revenue 0, straddling the average/low boundary in every random dataset. The differential test therefore compares tie-broken buckets on every seed.
2. **"Facilities with bookings" = an inner join.** A facility with zero bookings is excluded rather than ranked with revenue 0. *Tested:* `tests/edge_typical.sql` (Hot Tub is never booked) and `tests/edge_no_bookings.sql` (empty result). `mistakes/include_unbooked_facilities.sql` must fail both.
3. **A booking for a facid that is not in `facilities` is ignored** (inner join on both paths). The original has a foreign key, so this cannot occur there; the edge data never contains one, and `gen.py` never produces one.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **aggregate, then bucket with a window**: `NTILE` over a per-group total, with a `CASE` to name the buckets.

</details>

<details><summary>Hint 2</summary>

Shape: (1) price every booking (guest vs member cost) and total per facility. (2) Deal the facilities into 3 position-based groups by revenue, highest first. (3) Label the groups, then sort by group number and name.

</details>

<details><summary>Hint 3</summary>

Key clause: `NTILE(3) OVER (ORDER BY revenue DESC, facid)` over a CTE with one row per facility. Keep the NTILE value as its own column (`bucket`) and `ORDER BY bucket, name`; sorting by the label text puts `average` first. Faster: sum guest slots and member slots per facility first, then multiply by the two costs once per facility.

</details>

## 4. Decomposition

The sentence has three verbs. "Revenue per booking" is a row expression, "total per facility" is a `GROUP BY`, and "split into groups" is a window. Each verb is one CTE, in that order, because each one needs the previous one's output.

1. **`slot_totals`: per facility, total guest slots and total member slots (`GROUP BY facid` with `CASE WHEN memid = 0`).**
   *Why GROUP BY before the join:* revenue is `Σ slots × price`, and the price is constant within (facility, guest-or-member). So `Σ(slots × price) = (Σ slots) × price` for each of the two prices. Summing slots first collapses the big table to one row per facility. The prices are then applied once per facility instead of once per booking. Inner-joining later also enforces "facilities with bookings": only facids that appear in `bookings` get a row.
2. **`rev`: `JOIN facilities`, `revenue = guest_slots × guestcost + member_slots × membercost`.**
   *Why a JOIN here:* the prices live on the facility. After step 1 this is a 1:1 join of two small sets.
3. **`bucketed`: `NTILE(3) OVER (ORDER BY revenue DESC, facid)`.**
   *Why a window here:* "split into equally sized groups" compares each facility with all the others. A window adds that comparison without collapsing rows. *Why `DESC`:* bucket 1 must be the highest earners. *Why `facid`:* a deterministic tie-break (Assumptions 1).
4. **Final: `CASE bucket …` as `revenue`, `ORDER BY bucket, name`.**
   *Why sort by `bucket`, not by the label:* the required order is high, average, low, which is the bucket order. It is not alphabetical.

```sql
WITH slot_totals AS (                                -- step 1: bookings -> one row per booked facility
  SELECT facid,
         SUM(CASE WHEN memid = 0 THEN slots ELSE 0 END) AS guest_slots,
         SUM(CASE WHEN memid = 0 THEN 0 ELSE slots END) AS member_slots
  FROM bookings
  GROUP BY facid
),
rev AS (                                             -- step 2: price once per facility
  SELECT f.facid, f.name,
         s.guest_slots * f.guestcost + s.member_slots * f.membercost AS revenue
  FROM slot_totals s
  JOIN facilities f ON f.facid = s.facid
),
bucketed AS (                                        -- step 3: deal into 3 groups by position
  SELECT name, NTILE(3) OVER (ORDER BY revenue DESC, facid ASC) AS bucket
  FROM rev
)
SELECT name,                                         -- step 4: label, sort by the NUMBER
       CASE bucket WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM bucketed
ORDER BY bucket, name;
```

Self-check: the group sizes must differ by at most 1, and must never increase from high to low. With n facilities: ⌈n/3⌉ high, then the rest split as evenly as possible.

## 5. Approaches: brute force → optimal

### Approach 1: correlated position, arithmetic buckets (`solutions/01_correlated_position.sql`)

```sql
WITH rev AS (SELECT f.facid, f.name,
                    SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
             FROM bookings b JOIN facilities f ON f.facid = b.facid
             GROUP BY f.facid, f.name),
pos AS (SELECT r.name,
               1 + (SELECT COUNT(*) FROM rev o
                    WHERE o.revenue > r.revenue OR (o.revenue = r.revenue AND o.facid < r.facid)) AS position,
               (SELECT COUNT(*) FROM rev) AS n
        FROM rev r)
SELECT name, CASE ((position - 1) * 3) DIV n WHEN 0 THEN 'high' WHEN 1 THEN 'average' ELSE 'low' END AS revenue
FROM pos
ORDER BY ((position - 1) * 3) DIV n, name;
```

**Why it is correct:** `position` is the facility's 1-based place in the order (revenue DESC, facid ASC). It counts the facilities strictly ahead of it, and the facid term breaks ties exactly as the window versions do. For **three** buckets, `((p − 1) × 3) DIV n` reproduces NTILE's sizes. Write n = 3q + r. Bucket b receives the positions with (b−1)·n/3 ≤ p−1 < b·n/3, which is ⌈b·n/3⌉ − ⌈(b−1)·n/3⌉ positions. That gives q + [r ≥ 1], q + [r ≥ 2] and q, NTILE's sizes exactly. Integer `DIV` avoids MySQL's 4-digit division rounding. *This does not generalise:* for 4 buckets and n = 6 the formula gives sizes 2, 1, 2, 1 where NTILE gives 2, 2, 1, 1. The general formula needs the q/r case split. This is the natural answer without window functions: rank by counting who beats you, then do the arithmetic by hand. Getting the arithmetic right is the hard part; `mistakes/ceil_bucket_formula.sql` is the version people usually write first.

**Cost model (reasoned, plan shape checked with `EXPLAIN FORMAT=TREE`):** the aggregation is the same as approach 2's: a PK lookup into `facilities` for every booking, then a temp-table aggregate. The correlated position count is quadratic, but only in the number of **facilities** (≤ 1,000 even at 1M bookings in `gen.py`), so it is small next to the bookings scan. The lesson is that a quadratic step is harmless when it runs after the big table has been reduced to the small grain. The bench shows whether that holds.

### Approach 2: join, aggregate, NTILE (`solutions/02_join_aggregate_ntile.sql`)

```sql
WITH rev AS (SELECT f.facid, f.name,
                    SUM(b.slots * CASE WHEN b.memid = 0 THEN f.guestcost ELSE f.membercost END) AS revenue
             FROM bookings b JOIN facilities f ON f.facid = b.facid
             GROUP BY f.facid, f.name),
bucketed AS (SELECT name, NTILE(3) OVER (ORDER BY revenue DESC, facid ASC) AS bucket FROM rev)
SELECT name, CASE bucket WHEN 1 THEN 'high' WHEN 2 THEN 'average' ELSE 'low' END AS revenue
FROM bucketed
ORDER BY bucket, name;
```

**Why it is correct:** each booking is priced with the cost for its member type, totals are per facility, and NTILE deals the facilities into three position-based groups.

**Cost model (reasoned, plan shape checked):** the plan is a nested loop: a scan of `bookings`, and for each booking a single-row PK lookup into `facilities`. Then the per-row `CASE` and multiplication, an "aggregate using temporary table" keyed by `(facid, name)`, a sort of the facility rows for the window, and a final sort. The window and the sorts touch only one row per facility. The cost is the join and the aggregation over every booking.

### Approach 3 (optimal): aggregate slots first, price per facility (`solutions/03_aggregate_slots_then_price.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** within one facility, each booking's price is either `guestcost` or `membercost`, so `Σ slots × price = guest_slots × guestcost + member_slots × membercost`. `DECIMAL` multiplication and addition are exact, so the revenue values, and therefore their ties, are identical to approach 2's. The differential test checks that bucket for bucket.

**Cost model (reasoned, plan shape checked):** `bookings` is aggregated **on its own**: no join per booking, and only integer sums. The join to `facilities` then runs once per facility. With `indexes.sql` (`bookings (facid, memid, slots)`), the plan becomes a streaming "Group aggregate" over the covering index in `facid` order, with no temporary table and no table rows read. Without the index it is one temp-table aggregate over `bookings`.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:44-classify-facilities-by-value -->
_Measured 2026-11-05 by the bench workflow: MySQL 8.0.46, AMD EPYC 9V45 96-Core Processor, 2 vCPU. Median of 3 runs after 1 warm-up; each statement capped at 60 s. Sizes are main-table rows from `gen.py`. Raw numbers and EXPLAIN ANALYZE: `bench/results/44-classify-facilities-by-value.json`._

**Without indexes**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_position` | 1.58 ms | 94.6 ms | 1.08 s | 3.9× |
| `02_join_aggregate_ntile` | 1.41 ms | 94.2 ms | 1.02 s | 3.7× |
| `03_aggregate_slots_then_price` (optimal) | 823 µs | 27.9 ms | 275 ms | 1.0× |

**With `indexes.sql`**

| Solution | 1,000 rows | 100,000 rows | 1,000,000 rows | × slower than optimal @ 1,000,000 |
|---|---:|---:|---:|---:|
| `01_correlated_position` | 1.15 ms | 45.9 ms | 1.65 s | 12.3× |
| `02_join_aggregate_ntile` | 1.05 ms | 45.1 ms | 1.57 s | 11.6× |
| `03_aggregate_slots_then_price` (optimal) | 672 µs | 14.7 ms | 135 ms | 1.0× |

> GitHub-hosted runners are shared, noisy VMs: compare the ratios between rows, not the absolute times.
<!-- /BENCH -->

### Why the optimal one wins

All three approaches end with the same cheap step, ranking about 1,000 facility rows. Their cost is how they reach one row per facility. Approaches 1 and 2 join every booking to its facility before aggregating. Approach 3 notices that the price is constant per (facility, member type), sums only the slots, and prices afterwards. That is "aggregate before join" applied to arithmetic, and it is what lets the covering index stream the whole aggregation. Measured at 1M bookings: approach 3 took 275 ms against about 1.0–1.1 s for approaches 1 and 2 (3.7× faster), and 135 ms vs 1.6 s with the index (12×). The window function is the convenience here; the pre-aggregation is the performance step.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* the per-booking join + temp-table aggregate in approaches 1 and 2 grows with bookings. Approach 3's slot aggregation grows with bookings too, but it is narrower (no join) and can stream off the index. The window and the correlated ranking only see facility rows, so they stay trivial until there are millions of *facilities*. At that point approach 1's correlated count (facilities²) is the first thing to fail.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `bookings (facid, memid, slots)`. It is covering for every read of `bookings` here, and it lets approach 3's `GROUP BY facid` stream in index order without a temporary table: measured at 1M rows, approach 3 went from 275 ms to 135 ms. It made approaches 1 and 2 *slower* (1.02 s → 1.57 s for approach 2). Their plans show the join getting about 4× cheaper (now an index lookup per facility instead of a PK lookup per booking), but the `Aggregate using temporary table` above it took roughly three times as long. The plan does not say why. The lesson that is measured: an index on the input does not make a temporary-table aggregate cheaper, so check the plan before claiming a speed-up.
- With bookings spread over years, the real question usually has a date range (revenue this quarter). Then put `starttime` into the index after `facid`, or partition by month, so that the range read is narrow.
- `NTILE` needs all facility totals before it can assign the first bucket, because it must know n. That is inherent, and cheap here because n is small.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the `GROUP BY facid` is decomposable (sums). Each task pre-aggregates, so the shuffle carries about one row per (facility, task). `facilities` is tiny, so it is **broadcast** to the tasks: no shuffle for the join, whether before or after aggregating. Approach 3's advantage shrinks to less CPU per row.
- *Skew:* a few very popular facilities would be hot keys in a join-first plan. Partial aggregation removes that skew.
- *The window is a global operation:* `NTILE(…) OVER (ORDER BY …)` with no `PARTITION BY` sends every facility row to one worker to be sorted. For about 1,000 rows that is nothing. For millions of keys (customers in revenue terciles), it is a single-threaded sort, the classic window bottleneck. The scalable alternative is to compute thresholds once, then bucket by value: `APPROX_PERCENTILE(revenue, 0.333)` and `0.667`, or exact percentiles over a pre-sorted aggregate. But that changes the semantics from equal *counts* to value cut-offs, and ties then stay together. It is acceptable for segmentation dashboards, but not when the spec says equal-sized groups.

**(d) The data-engineering answer.** Revenue per facility is additive, so maintain it; the classification is recomputed from the small table on demand:

```sql
-- facility_revenue(facid PRIMARY KEY, guest_slots, member_slots), fed by each batch of new bookings.
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO facility_revenue t
USING (SELECT facid,
              SUM(IFF(memid = 0, slots, 0)) AS g,
              SUM(IFF(memid = 0, 0, slots)) AS m
       FROM new_bookings GROUP BY facid) s
ON t.facid = s.facid
WHEN MATCHED THEN UPDATE SET guest_slots = t.guest_slots + s.g, member_slots = t.member_slots + s.m
WHEN NOT MATCHED THEN INSERT (facid, guest_slots, member_slots) VALUES (s.facid, s.g, s.m);

-- MySQL equivalent:
INSERT INTO facility_revenue (facid, guest_slots, member_slots)
SELECT facid, SUM(CASE WHEN memid = 0 THEN slots ELSE 0 END), SUM(CASE WHEN memid = 0 THEN 0 ELSE slots END)
FROM new_bookings GROUP BY facid
ON DUPLICATE KEY UPDATE guest_slots = guest_slots + VALUES(guest_slots),
                        member_slots = member_slots + VALUES(member_slots);
-- Steps 2-4 of section 4 then read facility_revenue (one row per facility) instead of bookings.
```

Storing *slots* rather than revenue is deliberate: a price change then needs no backfill if the business wants current prices applied, or a dated price table if it does not. Ask which. Caveats interviewers probe: *cancelled bookings* need negative deltas; *replayed batches* double-count unless applied by watermark; and the **classification itself is not incremental**. One facility's new booking can move other facilities between buckets, so recompute the (cheap) NTILE every time and never store the label.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Six facilities, guest vs member prices, one free for members, one never booked | `tests/edge_typical.sql` | `member_price_for_everyone` (Climbing Wall's guest income vanishes), `include_unbooked_facilities` (Hot Tub joins the ranking: 7 rows, sizes change), `order_by_label_text`, `ntile_ascending` |
| Four facilities: sizes 2, 1, 1 | `tests/edge_uneven_four.sql` | `ceil_bucket_formula` (gives sizes 1, 1, 2), `order_by_label_text`, `ntile_ascending` |
| Two facilities: no `low` bucket at all | `tests/edge_two_facilities.sql` | `ceil_bucket_formula` (labels them average and low), `order_by_label_text`, `ntile_ascending` |
| Revenue tie across the high/average boundary | `tests/edge_revenue_ties.sql` | `rank_keeps_ties_together` (both tied facilities in `high`: sizes 3, 0, 1). It also pins the facid tie-break (Assumptions 1). |
| No bookings at all | `tests/edge_no_bookings.sql` | `include_unbooked_facilities` (ranks three facilities with NULL revenue) |
| Ordering: names run opposite to revenue in every bucket; label text order ≠ bucket order | `tests/edge_order.sql` | `order_by_label_text` (average rows first), `ntile_ascending` |

NULLs: every column is `NOT NULL` in the original schema, so there are no NULL inputs. The NULLs to watch are *produced* ones. A LEFT JOIN from `facilities` gives unbooked facilities a NULL revenue, which `ORDER BY revenue DESC` sorts **last** in MySQL, quietly placing them in `low` (`include_unbooked_facilities`).

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"Equal revenues must share a group."** Then the groups cannot be exactly equal-sized; say so, and pick a rule. One option: bucket by the NTILE of the *first* row of each tie group, using `FIRST_VALUE(NTILE…)` over `PARTITION BY revenue`, or `MIN(bucket) OVER (PARTITION BY revenue)`. Another: switch to value cut-offs with `PERCENT_RANK()` (`< 1/3` → high, and so on). Either way, it is no longer NTILE semantics.
2. **"Quartiles instead of terciles."** `NTILE(4)` and four labels. Note that approach 1's `((p − 1) × k) DIV n` trick no longer matches NTILE for k = 4 (section 5). This is the kind of "works for my test" formula an interviewer likes to probe.
3. **"Classify within each facility type separately."** `NTILE(3) OVER (PARTITION BY type ORDER BY revenue DESC, facid)`. The window becomes per partition, which also removes the single-worker bottleneck from section 6c.
4. **"Show the revenue number as well, and each bucket's revenue range."** Keep `revenue` as a number in the CTE. Then `MIN(revenue) OVER (PARTITION BY bucket)` and `MAX(…)` give each bucket's range, a window over a window result, so it needs one more CTE level.
5. **"Why not `NTILE(3) OVER (ORDER BY SUM(…) DESC)` directly in the grouped query?"** That is valid: windows run after `GROUP BY`, so they can order by an aggregate. It saves a CTE. The CTE version is easier to debug, because you can select the revenue numbers before bucketing them.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps approach 3. What changes, and why:

- `DECODE(bucket, 1, 'high', 2, 'average', 'low')` is a compact `CASE`. `IFF(memid = 0, slots, 0)` replaces the two-branch `CASE`.
- The NTILE is computed directly over the joined aggregate, with the same expression in `ORDER BY`. `QUALIFY` is not needed, since nothing is filtered by the window.
- No indexes. The aggregation over `bookings` is a parallel hash aggregate. With a date filter (the realistic version), clustering by `starttime` lets micro-partition pruning skip old bookings.
- For very many keys, `APPROX_PERCENTILE` / `PERCENTILE_CONT` give value-based cut-offs without a global sort, with the semantic change described in section 6c.
- Postgres (the original's dialect) supports the MySQL solutions unchanged, apart from the `cd.` prefix.

## 10. Pattern links

Same "aggregate, then window over the aggregate" shape:
- `45-median-order-amount-per-store`: position-based logic (`ROW_NUMBER` + `COUNT`) over sorted values. Same family as NTILE, and the same tie-break question.
- `29-restaurant-growth`: pre-aggregate per day, then a moving window over the daily totals.
- `17-seasonal-sales-analysis`, `19-department-top-three-salaries`: ranking functions over aggregated rows, with explicit tie rules.

Same "aggregate before join" idea:
- `01-market-analysis-i`: shrink the big table before it meets the small one.
- `40-friend-requests-ii-who-has-the-most-friends`: aggregate per role, then combine.
