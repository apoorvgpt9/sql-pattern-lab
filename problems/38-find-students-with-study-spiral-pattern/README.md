# 38 · Find Students with Study Spiral Pattern

## 1. Problem & trigger phrases

Original: [Find Students with Study Spiral Pattern](https://leetcode.com/problems/find-students-with-study-spiral-pattern/) (LeetCode 3617, hard). Read the statement there; this guide only restates the spec in its own words.

**Spec (own words):** put each student's sessions in order by date, then by session id. Let k be the number of different subjects the student studied. The student follows a *spiral* if all of the following hold:
- k is at least 3;
- no two consecutive sessions are more than 2 days apart;
- the number of sessions is a multiple of k and at least 2k;
- the whole sequence is the first k subjects repeated: session n has the same subject as session ((n−1) mod k) + 1.

Report k and the total hours over all sessions. Larger k first, then more hours first.

| Trigger phrase | What it forces in SQL |
|---|---|
| "repeating sequence" | Position matters, so you need `ROW_NUMBER()` over (`session_date`, `session_id`). Then compare each session with the session in the same **slot** of the first cycle, `(n − 1) mod k`. |
| "at least 2 complete cycles" | Two count rules: `n_sessions >= 2 * k` **and** `n_sessions % k = 0`. A started third cycle is not complete. |
| "no gaps longer than 2 days" | Adjacent-row comparison: `DATEDIFF(session_date, LAG(session_date))`, and the *maximum* gap per student must be ≤ 2. `<= 2`, so a gap of exactly 2 is fine. |
| "cycle length of at least 3" | k is `COUNT(DISTINCT subject)` per student, **not** the length of the shortest repeating block. MySQL has no `COUNT(DISTINCT …) OVER`, so k comes from a `GROUP BY` (or `DENSE_RANK` + `MAX`). |

## 2. Schema & grain

| Table | One row means | Keys that matter here |
|---|---|---|
| `students` | one student | `student_id` (PK), `student_name`, `major` |
| `study_sessions` | one study session | `session_id` (PK, and the same-day tiebreak), `student_id` (no FK), `subject`, `session_date`, `hours_studied` |

**Output grain:** one row per qualifying student.

**Where the grain changes:** at session grain you compute things that depend on *order*: position n and the gap to the previous session. At student grain you compute k, the count, the total hours, the maximum gap and the slot check. The order-dependent values must be computed while still at session grain (window functions), and only then aggregated. Two traps follow from that:

- k is a student-level value that the session-level slot formula needs (`(n − 1) mod k`). So k has to come back down to session rows, through a join to a per-student `GROUP BY` or a window `MAX` over a `DENSE_RANK`.
- The slot check looks like it needs a self-join (session n against session ((n−1) mod k)+1). It does not. "Every session repeats its slot's first subject" is the same as "each slot holds a single subject", and that is a `GROUP BY` fact: `COUNT(DISTINCT slot, subject) = k`.

## Assumptions

Confidence in `problems.yaml` is `low`: the statement is vague. The spec there mirrors the reference interpretation of the doocs/leetcode mirror. Its problem page and reference solution were re-read for this guide and agree with each point below. LeetCode itself could not be reached from the build environment (HTTP 403), so the checker's behaviour on these corner cases is **unverified**. Each interpretation is tested by a dataset:

1. **The whole history is the pattern.** There is no search for a qualifying sub-window inside a longer, noisier history. Hal (`tests/edge_partial_trailing_cycle.sql`) has a perfect 6-session spiral followed by one extra session and is excluded. Kai (`tests/edge_gap_boundary.sql`) has a perfect spiral broken by one 3-day gap and is excluded entirely.
2. **k is the number of distinct subjects over all sessions**, not the length of the shortest repeating block. Mo (`tests/edge_broken_sequence.sql`) repeats the block A, B, A, C twice. The block length is 4, but k = 3 and 8 is not a multiple of 3, so Mo is excluded.
3. **Complete cycles only:** a partial trailing cycle disqualifies (Hal; `mistakes/no_multiple_of_k_check.sql` shows the failure).
4. **Order is (`session_date`, `session_id`)**, and gaps are measured in that order. Sessions on the same day have gap 0 (`tests/edge_same_day_order.sql`).
5. **Total hours cover every session** (they are all "in the pattern" under assumption 1), and a NULL `hours_studied` adds nothing but still counts as a session (`tests/edge_nulls.sql`).
6. **Sessions of a `student_id` not in `students` are ignored**, because the output needs a name (`tests/edge_nulls.sql`, student 99).
7. Ordering ties beyond (`cycle_length`, `total_study_hours`) are unspecified. No edge dataset contains such a tie.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **ordered-sequence validation per entity**. Number the rows, look at neighbours, then aggregate pass/fail facts per student.

</details>

<details><summary>Hint 2</summary>

Shape: (1) number each student's sessions in (date, id) order and compute the gap to the previous one. (2) Compute k per student. (3) Per student, check four things: the k bound, the counts, the maximum gap, and that the sequence repeats. (4) Join student details, sort.

</details>

<details><summary>Hint 3</summary>

Key trick: slot r = `(n − 1) % k`. The sequence repeats its first k subjects exactly when every slot holds one subject only. Because every slot is used (n ≥ k), that is `COUNT(DISTINCT MOD(n - 1, k), subject) = k`: one `GROUP BY`, with no self-join and no `NOT EXISTS`.

</details>

## 4. Decomposition

Each rule in the wording names its grain: "between sessions" is about adjacent rows, "different subjects" and "complete cycles" are about the student, and "repeating sequence" is about positions. Compute row-level facts first, then turn every rule into an aggregate.

1. **`ordered`: `ROW_NUMBER() OVER w AS n`, `DATEDIFF(session_date, LAG(session_date) OVER w) AS gap`, with `w = PARTITION BY student_id ORDER BY session_date, session_id`.**
   *Why a window here:* position and "the previous session" exist only in an order, and only a window sees it. `session_id` in the `ORDER BY` is the tiebreak for same-day sessions (Assumption 4). Without it, `n` is arbitrary on those days.
2. **`ks`: `GROUP BY student_id`, `COUNT(DISTINCT subject) AS k`, `HAVING k >= 3`.**
   *Why a separate GROUP BY:* k is needed on every session row (step 3 uses it in `MOD`), and MySQL cannot compute `COUNT(DISTINCT)` as a window. The `HAVING` drops k < 3 students early.
3. **`per_student`: `ordered JOIN ks`, then `GROUP BY student_id, k` with `COUNT(*)`, `SUM(hours_studied)`, `MAX(gap)` and `COUNT(DISTINCT MOD(n - 1, k), subject)`.**
   *Why a GROUP BY:* every remaining rule is a statement about all of a student's sessions at once: "every gap", "the count", "the sequence". `MAX(gap) <= 2` is "every gap ≤ 2". The slot-pairs count encodes "the sequence repeats".
4. **Final: `JOIN students`, `WHERE n_sessions >= 2*k AND n_sessions % k = 0 AND max_gap <= 2 AND slot_subject_pairs = k`, `ORDER BY cycle_length DESC, total_study_hours DESC`.**
   *Why WHERE here:* after step 3 every fact is a plain column of a one-row-per-student CTE.

```sql
WITH ordered AS (                                    -- step 1: position and gap, session grain
  SELECT student_id, subject, hours_studied,
         ROW_NUMBER() OVER w                              AS n,
         DATEDIFF(session_date, LAG(session_date) OVER w) AS gap
  FROM study_sessions
  WINDOW w AS (PARTITION BY student_id ORDER BY session_date, session_id)
),
ks AS (                                              -- step 2: k per student
  SELECT student_id, COUNT(DISTINCT subject) AS k
  FROM study_sessions
  GROUP BY student_id
  HAVING COUNT(DISTINCT subject) >= 3
),
per_student AS (                                     -- step 3: every rule as an aggregate
  SELECT o.student_id, ks.k,
         COUNT(*)                                      AS n_sessions,
         SUM(o.hours_studied)                          AS total_hours,
         MAX(o.gap)                                    AS max_gap,
         COUNT(DISTINCT MOD(o.n - 1, ks.k), o.subject) AS slot_subject_pairs
  FROM ordered o
  JOIN ks ON ks.student_id = o.student_id
  GROUP BY o.student_id, ks.k
)
SELECT st.student_id, st.student_name, st.major,     -- step 4: filter, details, sort
       p.k AS cycle_length, p.total_hours AS total_study_hours
FROM per_student p
JOIN students st ON st.student_id = p.student_id
WHERE p.n_sessions >= 2 * p.k
  AND p.n_sessions % p.k = 0
  AND p.max_gap <= 2
  AND p.slot_subject_pairs = p.k
ORDER BY cycle_length DESC, total_study_hours DESC;
```

**Why the slot-pairs test is exact.** Suppose the sequence repeats. Then slot r holds only the subject of session r+1, so there are exactly k pairs. Conversely, suppose there are exactly k distinct (slot, subject) pairs. There are k slots and every one is used, since n ≥ 2k > k, so each slot has exactly one subject, which is the subject of its first session. That is the repeat rule. Worked example, Lu in `tests/edge_broken_sequence.sql`: A B C A C B gives slots 0 1 2 0 1 2 and pairs (0,A) (1,B) (2,C) (1,C) (2,B). That is 5 pairs, not 3, so Lu is out.

## 5. Approaches: brute force → optimal

### Approach 1: correlated positions + NOT EXISTS (`solutions/01_correlated_positions.sql`)

```sql
WITH pos AS (                     -- position = number of the student's sessions at or before this one
  SELECT s.student_id, s.subject, s.session_date,
         (SELECT COUNT(*) FROM study_sessions t
           WHERE t.student_id = s.student_id
             AND (t.session_date < s.session_date
                  OR (t.session_date = s.session_date AND t.session_id <= s.session_id))) AS n
  FROM study_sessions s
),
per_student AS (
  SELECT student_id, COUNT(*) AS n_sessions, COUNT(DISTINCT subject) AS k, SUM(hours_studied) AS total_hours
  FROM study_sessions GROUP BY student_id
)
SELECT st.student_id, st.student_name, st.major, ps.k AS cycle_length, ps.total_hours AS total_study_hours
FROM per_student ps JOIN students st ON st.student_id = ps.student_id
WHERE ps.k >= 3 AND ps.n_sessions >= 2 * ps.k AND ps.n_sessions % ps.k = 0
  AND NOT EXISTS (SELECT 1 FROM pos a JOIN pos b ON b.student_id = a.student_id AND b.n = a.n + 1
                  WHERE a.student_id = ps.student_id AND DATEDIFF(b.session_date, a.session_date) > 2)
  AND NOT EXISTS (SELECT 1 FROM pos x JOIN pos f ON f.student_id = x.student_id AND f.n = MOD(x.n - 1, ps.k) + 1
                  WHERE x.student_id = ps.student_id AND x.subject <> f.subject)
ORDER BY cycle_length DESC, total_study_hours DESC;
```

**Why it is correct:** the correlated count is a pre-window `ROW_NUMBER()`. It counts sessions that come strictly earlier in (date, id) order, plus the session itself. The first `NOT EXISTS` finds any adjacent pair too far apart. The second finds any session that disagrees with its slot's anchor. Each rule is one readable clause, which is why this is the natural first attempt.

**Cost model (reasoned from EXPLAIN):** the position subquery is *dependent* and runs once per session. Without an index each run is a `Table scan on t` of the whole table, so the cost is sessions × sessions. Both `NOT EXISTS` self-join `pos` (MySQL materialises it and builds auto-keys on (`student_id`, `n`)), which is roughly linear after that. With `indexes.sql`, the position count becomes a `Covering index lookup … (student_id=…)` over one student's sessions, so the total is about the sum of (sessions per student)².

### Approach 2: ROW_NUMBER + anchor self-join (`solutions/02_row_number_anchor_join.sql`)

```sql
WITH ordered AS (
  SELECT student_id, subject, hours_studied,
         ROW_NUMBER() OVER w AS n, DATEDIFF(session_date, LAG(session_date) OVER w) AS gap
  FROM study_sessions WINDOW w AS (PARTITION BY student_id ORDER BY session_date, session_id)
),
per_student AS (
  SELECT student_id, COUNT(*) AS n_sessions, COUNT(DISTINCT subject) AS k,
         SUM(hours_studied) AS total_hours, MAX(gap) AS max_gap
  FROM ordered GROUP BY student_id
),
candidates AS (
  SELECT * FROM per_student
  WHERE k >= 3 AND n_sessions >= 2 * k AND n_sessions % k = 0 AND max_gap <= 2
)
SELECT st.student_id, st.student_name, st.major, c.k AS cycle_length, c.total_hours AS total_study_hours
FROM candidates c JOIN students st ON st.student_id = c.student_id
WHERE NOT EXISTS (SELECT 1 FROM ordered o
                  JOIN ordered f ON f.student_id = o.student_id AND f.n = MOD(o.n - 1, c.k) + 1
                  WHERE o.student_id = c.student_id AND o.subject <> f.subject)
ORDER BY cycle_length DESC, total_study_hours DESC;
```

**Why it is correct:** the same rules as approach 1, with positions and gaps from one window pass. The count rules are applied first (`candidates`), so the mismatch search only runs for students that could still qualify.

**Cost model (reasoned from EXPLAIN):** one sort for the window, a group-by for the per-student facts, and then, per candidate, a nested anti-join that probes `ordered` twice through auto-keys on (`student_id`, `n`). That is linear, but it reads `ordered` three times in total and does a hash probe per session.

### Approach 3 (optimal): slot-subject pairs (`solutions/03_slot_subject_pairs.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** see "Why the slot-pairs test is exact" in section 4. The other rules are the same aggregates as in approach 2.

**Cost model (reasoned from EXPLAIN):** one sort for the window (`Sort: student_id, session_date, session_id`). One streaming group-by computes k, with its own sort by `student_id`, or an index scan with `indexes.sql`. A hash-probe join puts k on every row, and a single `Group aggregate` checks every rule, including `count(distinct tmp_field, subject)`. There is no self-join and no anti-join, and each session row is read once after the window. The `COUNT(DISTINCT …)` needs a sort of its own inside the group, but over (slot, subject) pairs per student, which is small.

A tempting alternative avoids the `ks` join by computing k with `MAX(DENSE_RANK() OVER (PARTITION BY student_id ORDER BY subject))`. That adds a second full sort (by subject) and another window level, so it is not used here. It is the form to know for engines without a cheap join.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:38-find-students-with-study-spiral-pattern -->
<!-- /BENCH -->

### Why the optimal one wins

Approach 3 turns the one rule that looks inherently pairwise ("session n matches session ((n−1) mod k)+1") into a group-level count. Once every rule is an aggregate, one `GROUP BY` checks them all in a single pass after the window. Approach 2 keeps the pairwise form and pays for it with a self-join and an anti-join. Approach 1 additionally pays a correlated count per session to compute positions. The general move to keep: when a check is "every row agrees with some other row determined by position", look for an invariant that can be counted per group.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1 without the index (one full scan per session for its position). Then approach 2's anti-join, whose probes grow with the number of candidate students' sessions. Approach 3 is bounded by the window sort.

**(b) One machine, ~1M–100M rows.**
- `indexes.sql`: `(student_id, session_date, session_id, subject)` is exactly the session order the spec defines, and it covers the position, gap and slot logic. It fixes approach 1's correlated count. MySQL 8.0 still sorts for the window even with it (EXPLAIN keeps `Sort: student_id, session_date, session_id`), so for approaches 2 and 3 the index mainly speeds up the k `GROUP BY`.
- Pre-filtering is the biggest lever: most students fail cheap rules (k < 3, too few sessions). Apply `ks`'s `HAVING k >= 3`, plus `COUNT(*) >= 2 * k` and `COUNT(*) % k = 0` per student, *before* the window, by joining the candidate student list into `ordered`. Then only plausible students are sorted (reasoned).

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Shuffle:* everything is per student, so there is one shuffle by `student_id`, then a sort within each partition for the window. The k aggregation and the main aggregation can reuse that partitioning. In Spark, `repartition(student_id)` followed by `sortWithinPartitions(session_date, session_id)` makes both the window and the group-by local.
- *COUNT DISTINCT:* both `COUNT(DISTINCT subject)` and `COUNT(DISTINCT slot, subject)` are computed **per student**, after the shuffle. That is cheap, unlike a global `COUNT DISTINCT`, which would need every distinct value collected in one place. Approximate distinct counts are never acceptable here: the rule is "equals k" exactly.
- *Skew:* students with very long histories are big partitions, but the window and the aggregate are linear in partition size, and only one sort is needed.
- *Early exit:* a student fails at the first bad gap or first slot mismatch. SQL cannot stop early, but a UDAF or Spark `mapGroups` can. For huge histories that is a legitimate reason to leave pure SQL.

**(d) The data-engineering answer.** The spiral state of a student is small: k, the first cycle's subjects, the current position, the last date, and a "still valid" flag. New sessions only append, so keep that state and advance it per session instead of recomputing whole histories:

```sql
-- spiral_state(student_id PK, first_cycle VARCHAR, k INT, n INT, last_date DATE, valid BOOLEAN, total_hours DECIMAL)
-- first_cycle is fixed once the first repeat appears; until then k grows with each new subject.
-- Per new session s (in (session_date, session_id) order), conceptually:
--   valid := valid AND DATEDIFF(s.session_date, last_date) <= 2
--            AND (n < k OR s.subject = element((n mod k) + 1) of first_cycle)
--   n := n + 1; last_date := s.session_date; total_hours += COALESCE(s.hours_studied, 0)
-- A student qualifies when valid AND k >= 3 AND n >= 2k AND n % k = 0.
```

In SQL this is awkward: the update for session i depends on the state after session i−1, which is a fold, not a set operation. For a daily batch, the practical version is to **recompute only the students that appear in the batch** with approach 3 (`WHERE student_id IN (SELECT student_id FROM sessions_batch)`) and `MERGE` their rows into a results table. That is incremental in the number of touched students, and correct by construction. Caveats: a late session dated in the past changes positions for the whole student, which the touched-student recompute handles. Once a student is invalid they stay invalid forever (under Assumption 1), so they can be skipped cheaply.

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| 3-subject spiral; a perfect 2-subject rotation; a student without sessions | `tests/edge_typical.sql` | `cycle_length_2_allowed` |
| k = 4 with fewer hours ranks above k = 3 with more hours | `tests/edge_ordering_cycle_length.sql` | none reliably; every approach sorts explicitly |
| Equal k: more hours first; ids run the other way | `tests/edge_ordering_hours.sql` | `hours_ascending` |
| Two full cycles plus one extra session (Assumptions 1, 3) | `tests/edge_partial_trailing_cycle.sql` | `no_multiple_of_k_check` |
| Every gap exactly 2 days, three cycles; one 3-day gap | `tests/edge_gap_boundary.sql` | `no_gap_check`, `gap_less_than_2` |
| Balanced counts in the wrong order; block A, B, A, C repeated (Assumption 2) | `tests/edge_broken_sequence.sql` | `balanced_counts_not_order` |
| Two sessions on one day; session ids not chronological across days (Assumption 4) | `tests/edge_same_day_order.sql` | `order_by_session_id_only` |
| NULL hours inside a cycle; NULL major; a perfect cycle for an unknown student (Assumptions 5, 6) | `tests/edge_nulls.sql` | `drive_from_sessions` |

No approach in `solutions/` is broken by any of these. Approach 1 is slow without an index, not wrong.

## 8. Interviewer follow-ups

1. **"Find the longest qualifying sub-window instead of requiring the whole history."** This reverses Assumption 1 and makes the problem much harder. First split the history into islands at every gap > 2 (flag-and-count, as in `33-find-users-with-persistent-behavior-patterns`). Then, inside each island, the cycle can start anywhere, so for each candidate start and each k you would test the slot rule. Say up front that this is quadratic per island, and ask whether it is really needed.
2. **"Allow at most one off-pattern session."** Count mismatches instead of requiring zero: `SUM(o.subject <> f.subject)` with approach 2's anchor join, or `COUNT(*) - COUNT(DISTINCT …)`-style slack in approach 3. Approach 2's shape generalises more easily here.
3. **"Report the cycle itself (A → B → C)."** `GROUP_CONCAT(subject ORDER BY n SEPARATOR ' → ')` over rows with `n <= k`, per qualifying student.
4. **"Why can't you use `COUNT(DISTINCT subject) OVER (PARTITION BY student_id)`?"** MySQL (and SQL Server) do not support `DISTINCT` inside window aggregates. Either join a `GROUP BY` result back, or use `MAX(DENSE_RANK() OVER (… ORDER BY subject))`. Snowflake does support it (section 9).
5. **"Is `subject` comparison case-sensitive?"** Not under MySQL's default `utf8mb4_0900_ai_ci`: 'Math' and 'math' are the same subject for `COUNT(DISTINCT)`, `DENSE_RANK` and `=`. That is consistent, but it may not be what the business means. Snowflake compares case-sensitively by default, so the same data can give a different k.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3. What changes, and why:

- `COUNT(DISTINCT subject) OVER (PARTITION BY student_id)` is allowed in Snowflake, so k goes into the same window pass as `ROW_NUMBER` and `LAG`, and the `ks` join disappears.
- `QUALIFY` is not needed: the final filter is over a `GROUP BY` result, so it is `HAVING`.
- `COUNT(DISTINCT MOD(n - 1, k), subject)`: Snowflake accepts multi-argument `COUNT(DISTINCT a, b)`, but note that a NULL in any argument drops the row. `subject` is never NULL here.
- `DATEDIFF(day, LAG(session_date) OVER w, session_date)`: the argument order is the reverse of MySQL's.
- String comparison is case-sensitive by default, so k can differ from MySQL's on mixed-case data (section 8.5).

## 10. Pattern links

Same pattern (ordered-sequence validation per entity):
- `33-find-users-with-persistent-behavior-patterns`: per-user ordered runs, with a gap rule that splits them.
- `26-find-consistently-improving-employees`: "every adjacent pair satisfies X" via `LAG`, then `MIN`/`MAX` of the pass flag per entity.
- `27-most-common-course-pairs`: transitions between consecutive rows (`LEAD`) inside an ordered history.

Related:
- `32-human-traffic-of-stadium`: position arithmetic with `ROW_NUMBER()` (`id - rn`), the same "turn an order into a number" move.
- `14-customers-who-bought-all-products`: `COUNT(DISTINCT …) = k` as an exact set test, which is what the slot-pairs check is.
