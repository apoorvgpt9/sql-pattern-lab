# 05 · Find Loyal Customers

## 1. Problem & trigger phrases

Original: [Find Loyal Customers](https://leetcode.com/problems/find-loyal-customers/) (LeetCode 3657, medium). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** list the customers (ascending by id) who satisfy **all three** of: at least 3 purchase transactions; at least 30 days between their earliest and latest transaction (any type); and a refund share, refunds ÷ all their transactions, strictly below 20%.

| Trigger phrase | What it forces in SQL |
|---|---|
| "ALL the following criteria" | Every criterion is a fact about a **customer**, not a row. One `GROUP BY customer_id`, one predicate per criterion in `HAVING`, joined with `AND`. Not three queries `INTERSECT`ed. |
| "at least 3 purchase transactions" | A count of a *subset* of the customer's rows: `SUM(transaction_type = 'purchase') >= 3`, inside the aggregate. |
| "active for at least 30 days" | The span between the earliest and latest transaction **of any type**: `DATEDIFF(MAX(d), MIN(d)) >= 30`. No filter on type, and `>=`: exactly 30 qualifies. |
| "refund rate is less than 20%" | A share of the customer's **whole** history: refunds over all transactions. Strictly `<`: exactly 20% does not qualify. |

The crux hidden in the wording: the three criteria look at *different row sets*. Criterion 1 sees purchases only; criteria 2 and 3 see everything. That is why a single `WHERE transaction_type = 'purchase'` is wrong and the conditions live inside the aggregates.

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `customer_transactions` | one transaction (a purchase or a refund) | `transaction_id` (PK); `customer_id`; `transaction_date`; `transaction_type`. `amount` is irrelevant. |

**Output grain:** one row per qualifying customer: a single column, `customer_id`, in ascending order. Customers with no row in the table can't qualify and don't exist as far as this table is concerned.

**Where the grain changes:** transaction grain → customer grain, in one `GROUP BY customer_id`. Everything the question asks (counts, a date span, a ratio) is an aggregate over the customer's rows, so the filtering happens **after** grouping (`HAVING`), not before (`WHERE`).

## Assumptions

Confidence is `medium`. The statement is ambiguous in two places and the reference solution disagrees with the statement in one. Interpretations used here, each tested:

1. **"At least 3 purchase transactions" counts purchases only** (the statement's wording). One published reference solution counts all rows. **The difference is unobservable given the other rules.** A customer with at most 2 purchases and at least 1 refund fails the 20% rule (refunds are ≥ 1/3 of their rows); with no refunds, "all rows" equals "purchases". So both readings select exactly the same customers, and no test dataset can tell them apart. `solutions/` use purchases only.
2. **The 30-day span is measured over all of a customer's transactions, any type**, as the spec says. This one *is* observable: a customer whose refund falls long after their purchases qualifies under this reading only. `tests/edge_span_includes_refunds.sql` pins the interpretation; `span_purchases_only` shows the alternative. If LeetCode's checker turns out to use purchases only, change the one expression and that dataset's expected output.
3. **"Total transactions" is purchases + refunds, i.e. all rows**, because `transaction_type` is restricted to those two values (a `CHECK` constraint in `schema.sql`). If other types existed, the denominator would need an explicit `IN ('purchase','refund')`.
4. **Boundaries:** span of exactly 30 days qualifies (`>= 30`); a refund rate of exactly 0.20 does not (`< 0.2`). Tested in `edge_span_boundary` and `edge_refund_rate`.
5. **All columns are NOT NULL**, as the spec expects none. Dates are `DATE`, so "days between" is a whole-day difference (`DATEDIFF`).
6. **Output order is `customer_id` ascending** and is compared exactly. `edge_ordering` inserts rows out of order to test it.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **conditional aggregation + HAVING**. Per-customer measures computed in one `GROUP BY`, then each criterion filters on one measure.

</details>

<details><summary>Hint 2</summary>

Shape: (1) group the transactions by customer. (2) For each customer compute three things in the same pass: number of purchases, days between first and last transaction, refund share. (3) Keep customers where all three tests pass, sorted by id. Note which measure uses which rows: purchases uses a subset, the other two use everything.

</details>

<details><summary>Hint 3</summary>

Key trick: put the subset condition **inside** the aggregate: `SUM(transaction_type = 'purchase')`, `SUM(transaction_type = 'refund')`. Leave the date span unfiltered. For the rate, compare without dividing: `5 * refunds < total` is the same as `refunds / total < 0.2`, with no rounding to think about. Don't forget `ORDER BY customer_id`.

</details>

## 4. Decomposition

Read "customers meeting ALL of the following" as: *compute a profile per customer, then filter the profiles.* The sentence names the measures; each criterion names one threshold.

1. **`per_customer`: `GROUP BY customer_id` over `customer_transactions`.**
   *Why a GROUP BY here:* every criterion is about the customer's whole set of rows, so rows must collapse to customer grain before any criterion can be evaluated.
2. **Inside it, three measures, each with its own row set.**
   - `n_purchases = SUM(transaction_type = 'purchase')`: *why conditional:* it counts a subset while the other measures need every row, so a global `WHERE` is not an option.
   - `span_days = DATEDIFF(MAX(transaction_date), MIN(transaction_date))`: *why unfiltered:* "active" covers any transaction type.
   - `n_refunds = SUM(transaction_type = 'refund')` and `n_total = COUNT(*)`: *why both:* the rate is refunds over everything; the denominator is the unfiltered count.
3. **Filter: one predicate per criterion, `AND`ed.**
   *Why after grouping:* WHERE runs before aggregation and cannot see a count; `HAVING` (or a `WHERE` on the CTE) can. *Why `5 * n_refunds < n_total`:* it is `n_refunds / n_total < 0.2` without a division.
4. **Sort by `customer_id`.**
   *Why explicit:* the spec fixes the order, and a `GROUP BY` promises none.

```sql
WITH per_customer AS (                         -- steps 1 + 2: transaction grain -> customer grain
  SELECT customer_id,
         SUM(transaction_type = 'purchase')                  AS n_purchases,
         DATEDIFF(MAX(transaction_date), MIN(transaction_date)) AS span_days,
         SUM(transaction_type = 'refund')                    AS n_refunds,
         COUNT(*)                                            AS n_total
  FROM customer_transactions
  GROUP BY customer_id
)
SELECT customer_id                             -- steps 3 + 4
FROM per_customer
WHERE n_purchases >= 3
  AND span_days   >= 30
  AND 5 * n_refunds < n_total
ORDER BY customer_id;
```

`solutions/03_group_by_having.sql` folds the CTE into the `HAVING` clause; the two are equivalent.

Self-check: temporarily select the measures instead of filtering. For a customer you expect to fail, you should be able to say which one of the three fails.

## 5. Approaches: brute force → optimal

### Approach 1: one correlated subquery per criterion (`solutions/01_correlated_subqueries.sql`)

```sql
SELECT c.customer_id
FROM (SELECT DISTINCT customer_id FROM customer_transactions) c
WHERE (SELECT COUNT(*) FROM customer_transactions t
        WHERE t.customer_id = c.customer_id AND t.transaction_type = 'purchase') >= 3
  AND DATEDIFF((SELECT MAX(t.transaction_date) FROM customer_transactions t WHERE t.customer_id = c.customer_id),
               (SELECT MIN(t.transaction_date) FROM customer_transactions t WHERE t.customer_id = c.customer_id)) >= 30
  AND (SELECT COUNT(*) FROM customer_transactions t
        WHERE t.customer_id = c.customer_id AND t.transaction_type = 'refund')
    / (SELECT COUNT(*) FROM customer_transactions t WHERE t.customer_id = c.customer_id) < 0.2
ORDER BY c.customer_id;
```

**Why it is correct:** the outer derived table lists each customer once, and every criterion is a direct translation of the wording over that customer's rows. Each subquery sees exactly the row set its criterion names.

**Cost model (reasoned, plan shape checked with EXPLAIN on a sample):** five dependent subqueries per customer. The primary key is `transaction_id`, so without an index on `customer_id` each one is a full table scan: customers × rows × 5, which is quadratic. With `indexes.sql` each becomes a range read of that customer's entries.

### Approach 2: one aggregate per criterion, joined (`solutions/02_one_aggregate_per_criterion.sql`)

```sql
WITH purchases AS (
  SELECT customer_id, COUNT(*) AS n_purchases
  FROM customer_transactions WHERE transaction_type = 'purchase' GROUP BY customer_id
), span AS (
  SELECT customer_id, DATEDIFF(MAX(transaction_date), MIN(transaction_date)) AS span_days
  FROM customer_transactions GROUP BY customer_id
), refunds AS (
  SELECT customer_id, SUM(transaction_type = 'refund') / COUNT(*) AS refund_rate
  FROM customer_transactions GROUP BY customer_id
)
SELECT p.customer_id
FROM purchases p
JOIN span    s ON s.customer_id = p.customer_id
JOIN refunds r ON r.customer_id = p.customer_id
WHERE p.n_purchases >= 3 AND s.span_days >= 30 AND r.refund_rate < 0.2
ORDER BY p.customer_id;
```

**Why it is correct:** each CTE is one row per customer, so the joins are 1:1 on the key. A customer with no purchases is absent from `purchases` and so is dropped by the inner join, which is right since they can't have 3.

**Cost model (reasoned):** three scans of the table and three aggregations, each materialised into a temporary table (the sample plan shows three), then two key-lookup joins. Linear in rows, but three times the I/O and temp-table work of a single pass. Notice it computes a ratio by division and compares it to a decimal literal, the form the integer comparison in approach 3 avoids.

### Approach 3 (optimal): one GROUP BY, criteria in HAVING (`solutions/03_group_by_having.sql`)

```sql
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
   AND 5 * SUM(transaction_type = 'refund') < COUNT(*)
ORDER BY customer_id;
```

**Why it is correct:** the aggregates see exactly the rows each criterion names (subset, all, all). `HAVING` filters groups after aggregation. Integer arithmetic keeps the strict 20% boundary exact. The explicit `ORDER BY` fixes the output order.

**Cost model (reasoned):** one scan feeding one aggregation whose state per customer is a handful of numbers (a count, two counts, a min and a max). The aggregation is a temporary table keyed by `customer_id` unless an index provides the order, followed by a sort of the (small) result for the `ORDER BY`.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:05-find-loyal-customers -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 evaluates all criteria in the same pass over the same groups, so there is nothing to join and nothing to re-scan; the number of passes does not grow with the number of criteria (approach 1 grows with customers × criteria, approach 2 with criteria). Adding a fourth criterion is one more `HAVING` line, not another CTE and join. Its performance depends little on physical design, and its measures are decomposable, which is what distributed engines need (section 6c).

## 6. At scale

**(a) What breaks first.** *Reasoned, to be checked against the bench table:* approach 1 without an index on `customer_id` goes first (quadratic, with 5 scans per customer). Approach 2 is linear but pays three scans and three temporary tables, so it spills earlier. Approach 3 degrades last: one scan, and memory proportional to the number of distinct customers, not rows.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql` adds `(customer_id, transaction_type, transaction_date)`. It is covering for all three solutions, makes approach 1 feasible, and lets approaches 2 and 3 aggregate in index order without a temporary table. The bench runs with and without it.
- Because every row of every customer is needed, no index can *skip* data for the full question. If the follow-up adds a time window ("last 12 months"), a range predicate on the raw `transaction_date` plus an index starting with the date would then prune.
- At 100M+ rows, hash-partitioning by `customer_id` keeps each customer's rows together, so each partition can be aggregated independently (reasoned).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* the `GROUP BY customer_id` needs a shuffle by customer. `COUNT`, `SUM`, `MIN` and `MAX` are all decomposable, so each task pre-aggregates its rows into one partial `(purchases, refunds, total, min_date, max_date)` per customer and the shuffle carries only those. The `HAVING` runs after the final merge; it can't be pushed below the shuffle, because no partial group has the whole picture.
- *Skew:* a few very heavy customers (corporate or test accounts) would overload one reducer in a row-level shuffle; partial aggregation reduces them to one row per task.
- *Pruning:* with no time window, every partition is read. If the data is clustered by `customer_id`, partial aggregation barely reduces anything and the shuffle is nearly free.
- *Things to avoid:* a global sort over all transactions (only the final qualifying ids need sorting); approximate functions: this question has exact boundaries (exactly 30 days, exactly 20%), so a sketch is not acceptable here.

**(d) The data-engineering answer.** Every measure is a monoid (sum, sum, min, max), so a per-customer summary can be maintained by merging batches, and "loyal" becomes a cheap read of the summary:

```sql
-- customer_summary(customer_id PK, n_purchases, n_refunds, first_date, last_date)
-- Snowflake / ANSI MERGE (UNVERIFIED):
MERGE INTO customer_summary t
USING (SELECT customer_id,
              COUNT_IF(transaction_type = 'purchase') AS p, COUNT_IF(transaction_type = 'refund') AS r,
              MIN(transaction_date) AS d0, MAX(transaction_date) AS d1
       FROM transactions_batch            -- only rows not yet applied (watermark on transaction_id)
       GROUP BY customer_id) s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET n_purchases = t.n_purchases + s.p, n_refunds = t.n_refunds + s.r,
                             first_date = LEAST(t.first_date, s.d0), last_date = GREATEST(t.last_date, s.d1)
WHEN NOT MATCHED THEN INSERT (customer_id, n_purchases, n_refunds, first_date, last_date)
                      VALUES (s.customer_id, s.p, s.r, s.d0, s.d1);

-- MySQL equivalent (no MERGE):
INSERT INTO customer_summary (customer_id, n_purchases, n_refunds, first_date, last_date)
SELECT customer_id, SUM(transaction_type = 'purchase'), SUM(transaction_type = 'refund'),
       MIN(transaction_date), MAX(transaction_date)
FROM transactions_batch GROUP BY customer_id
ON DUPLICATE KEY UPDATE n_purchases = n_purchases + VALUES(n_purchases),
                        n_refunds   = n_refunds   + VALUES(n_refunds),
                        first_date  = LEAST(first_date, VALUES(first_date)),
                        last_date   = GREATEST(last_date, VALUES(last_date));

-- The question reads only the summary:
SELECT customer_id FROM customer_summary
WHERE n_purchases >= 3 AND DATEDIFF(last_date, first_date) >= 30
  AND 5 * n_refunds < n_purchases + n_refunds
ORDER BY customer_id;
```

Caveats interviewers probe. *Idempotency:* re-applying a batch double-counts, so track the applied watermark. *Deletes and corrections:* `MIN`/`MAX` cannot be un-merged: removing a customer's earliest transaction needs a recompute of that customer, or a retained per-day summary. *Loyalty is not monotonic:* a new refund can make a loyal customer stop qualifying, so the status is always derived from the current counters, never stored as sticky.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts each one fails every dataset it names.

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| One customer failing each criterion in turn: too few purchases, span too short, rate too high | `tests/edge_typical.sql` | `where_purchase_only` (the refund rate becomes 0, so customer 40 leaks in) |
| Span exactly 30 days qualifies; 29 days does not; all on one day; a span that crosses a leap February | `tests/edge_span_boundary.sql` | `span_strictly_greater` (`> 30`) |
| Refund rate exactly 20% does not qualify; 1/6 does; 1/4 does not | `tests/edge_refund_rate.sql` | `refund_rate_inclusive` (`<=`), `refund_rate_over_purchases` (wrong denominator), `where_purchase_only` |
| Refund extends the span beyond the purchase window | `tests/edge_span_includes_refunds.sql` | `span_purchases_only`, `where_purchase_only` |
| Output order is ascending by `customer_id` regardless of insertion order | `tests/edge_ordering.sql` | `no_order_by` |
| Empty table | `tests/edge_empty.sql` | none: an empty result |
| NULLs | not applicable: every column is NOT NULL | none |
| Counting purchases vs counting all rows for the "at least 3" criterion | not testable | indistinguishable given the rate rule (see Assumptions) |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong. Ties do not exist: output rows are distinct customer ids.

## 8. Interviewer follow-ups

1. **"Why `5 * refunds < total` and not `refunds / total < 0.2`?"** They are the same on paper. The integer form makes the strict boundary independent of how the engine rounds quotients. MySQL, for instance, rounds a displayed decimal quotient to 4 extra places (19999/100000 shows as 0.2000), and engines using doubles have their own rounding. Integer arithmetic removes the question.
2. **"Loyal in the last 12 months only."** Decide first whether the window restricts the rows (then it also changes the span and the rate, a `WHERE` on date) or only the purchase count. Say which, and show the range predicate on the raw date column so an index can prune.
3. **"Add a reason column: which criteria failed?"** Drop the `HAVING`, select the three booleans (`n_purchases >= 3`, `span_days >= 30`, `5 * n_refunds < n_total`) and filter in the outer query. This is why the `per_customer` CTE form is the more reusable shape.
4. **"What if `transaction_type` has more values?"** The denominator must name the types explicitly (`SUM(transaction_type IN ('purchase','refund'))`), not `COUNT(*)`. Also decide what the new types mean for "active".
5. **"`DATEDIFF` vs `TIMESTAMPDIFF` when the column is a datetime?"** `DATEDIFF` compares dates only: 29 days 23 hours counts as 30. `TIMESTAMPDIFF(DAY, …)` counts full 24-hour days: 29. The spec's "30 days" has to be pinned down with the interviewer.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes:

- `COUNT_IF(cond)` replaces `SUM(cond)` (a boolean cannot be summed directly in Snowflake).
- `DATEDIFF('day', MIN(d), MAX(d))` takes the unit as the first argument and the order of the dates is start, end, the reverse of MySQL's `DATEDIFF(end, start)`. Mixing them up flips the sign and silently returns no customers.
- Aggregate predicates in `HAVING` work the same. `QUALIFY` is not needed: there are no window functions here.
- No secondary indexes: `indexes.sql` has no equivalent. Data clustered by `customer_id` (or a clustering key on it) keeps each customer's rows in few micro-partitions, which lets the aggregation run with little shuffling. There is no pruning benefit without a time filter.
- Output order of `ORDER BY` is guaranteed; unquoted identifiers are returned upper-cased (`CUSTOMER_ID`).

## 10. Pattern links

Same pattern (conditional aggregation, several measures per group):
- `04-monthly-transactions-i`: the same one-pass conditional aggregates, grouped by (month, country), no HAVING.
- `06-find-golden-hour-customers`: the closest sibling: per-customer counts, shares and an average in `HAVING`.
- `02-confirmation-rate`: a conditional share per user, with the zero case.
- `07-trips-and-users`: a conditional ratio per day.
- `24-immediate-food-delivery-ii`: a conditional share over a derived subset.

Builds on it:
- `36-find-churn-risk-customers`, `33-find-users-with-persistent-behavior-patterns`: per-user profiles filtered with several conditions, plus a sequence or recency condition.
