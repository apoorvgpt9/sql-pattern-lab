# 15 · Employees Qualified for Every Required Skill of a Role

## 1. Problem & trigger phrases

Original problem written for this repo (SPL-DIV-01); there is no external statement to link.

**Spec (own words):** `RoleRequirements` says which skills each role requires. `EmployeeSkills` says which skills each employee claims; the same claim can be recorded more than once. For every role, list every employee who holds **all** of that role's required skills (extra skills do not matter). An employee can qualify for several roles. A role that nobody fully satisfies yields no rows. Skills match only if the strings are exactly equal. Sort by role, then employee id.

| Trigger phrase | What it forces in SQL |
|---|---|
| "has every skill required" | **Relational division**: for all required skills there exists a matching claim. Encode it by counting (matched skills = required skills) or by double negation (no required skill without a matching claim). Not "has some required skill", and not "has exactly the required skills". |
| "for each role" | The target set is **different per group**. In problem 14 the divisor was one table-wide number; here each role has its own requirement count, so the comparison is `matched_for_this_role = required_by_this_role`, and a global count is wrong. The output grain is `(role, employee)`. |
| "skills table may repeat" | `EmployeeSkills` can hold the same `(employee, skill)` twice. The unit is the distinct skill, not the row: deduplicate before counting, or `COUNT(DISTINCT skill)`. |

Hidden in "exact string equality": `'sql'`, `'SQL'` and `'SQL '` are three different skills. That is a statement about the comparison, and MySQL's default collation would blur it (see Assumptions).

## 2. Schema & grain

| Table | One row means | Columns that matter |
|---|---|---|
| `EmployeeSkills` | one claim "this employee has this skill"; exact repeats allowed (no primary key) | `employee_id`, `skill` |
| `RoleRequirements` | one skill required by one role; unique `(role, skill)` | `role`, `skill` |

**Output grain:** one row per `(role, employee)` pair that qualifies. The set of roles comes only from `RoleRequirements`; the set of employees only from `EmployeeSkills` (there is no employee table, so an employee with no claims does not exist for this query).

**Where the grain changes:** four moves.

1. *Claims → distinct claims:* deduplicate `(employee, skill)`, the real grain of "has this skill".
2. *Up:* join requirements to claims on `skill`. The result has one row per `(role, skill, employee)` where the employee holds a skill the role requires. The join key is the skill, not the employee or the role.
3. *Down:* `GROUP BY role, employee` counts how many of the role's skills the employee matched.
4. *Compare:* with the number the role requires, which comes from a different grouping of `RoleRequirements` (`GROUP BY role`) and joins back 1:1.

## Assumptions

Confidence is `high`, and the spec is authoritative. The points below are consequences or gaps the guide makes explicit.

1. **"Exact string equality" is enforced by the schema.** `schema.sql` declares both `skill` columns with `COLLATE utf8mb4_0900_bin`, a byte-for-byte comparison with no case folding and no trailing-space padding. With MySQL's default (`utf8mb4_0900_ai_ci`) the query `'sql' = 'SQL'` is true and the spec would be violated. Tested in `tests/edge_exact_match.sql` (wrong case, trailing space). Any solution that adds `LOWER`/`TRIM` is wrong by the spec.
2. **A role with no requirements does not exist** for this query (roles come from `RoleRequirements`). So the "vacuous truth" case (everyone qualifies for a role that needs nothing) cannot arise.
3. **An employee must have at least one claim to be considered.** An employee with none cannot be listed, because no table lists them.
4. **Role names are compared and sorted with the default collation.** The datasets use roles that differ by more than case.

## 3. Hint ladder

<details><summary>Hint 1</summary>

Pattern: **relational division, per group**. "Employees who have all of the role's required skills" is a division of the claims by the role's requirement set, done separately for each role.

</details>

<details><summary>Hint 2</summary>

Shape: (1) count how many skills each role requires, (2) count, for each (role, employee), how many of that role's skills the employee holds (counting each skill once), (3) keep the pairs where the two counts are equal, (4) sort.

</details>

<details><summary>Hint 3</summary>

Key clauses: join `RoleRequirements` to the employee's claims on `skill`, `GROUP BY role, employee_id`, then `HAVING <distinct matched skills> = <that role's required count>`. Get the required count from `GROUP BY role` over `RoleRequirements`, not from a global count. Remove duplicate claims first (or use `COUNT(DISTINCT rr.skill)`) so that repeated rows cannot fake coverage. Do not wrap the strings in `LOWER` or `TRIM`.

</details>

## 4. Decomposition

Read the output: `(role, employee_id)`. Two things have to be established for a pair to appear: how many skills the role needs, and how many of them the employee has. Everything else follows from comparing those two numbers.

1. **`req`: per role, `COUNT(*)` of its required skills.**
   *Why a GROUP BY here:* "for each role" says the target differs per group. This is the divisor, one row per role, so that it can be joined back 1:1.
2. **Join `RoleRequirements` to `EmployeeSkills` on `skill`.**
   *Why a JOIN on skill:* a required skill and a claimed skill are related only by being the same string. The result has one row per `(role, required skill, claim)`: the grain goes **up**, and an employee's claims for skills the role does not require simply find no partner. Extra skills are fine for that reason.
3. **`GROUP BY role, employee_id`, `COUNT(DISTINCT rr.skill)`.**
   *Why a GROUP BY on the pair, and why DISTINCT:* the pair is the thing being qualified, and the count is how many of the role's skills the employee matched. "Skills table may repeat" means the same claim can reach the join several times; counting distinct *required skills* makes a repeat count once.
4. **Compare in `HAVING`: matched skills = `req.n_required`.**
   *Why equality is exact:* the counted skills are distinct and belong to the role, so they cannot exceed the role's total; equal means "all of them". Employees with no match never form a group, which is right: they cannot qualify for a role that requires something.
5. **`ORDER BY role, employee_id`.**
   *Why explicit:* the order is part of the spec, and `(role, employee_id)` is unique, so it is total.

Assembled (this is `solutions/03_join_count_distinct.sql`):

```sql
WITH req AS (                                                   -- step 1: the per-role divisor
  SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role
)
SELECT rr.role, es.employee_id
FROM RoleRequirements rr
JOIN EmployeeSkills es ON es.skill = rr.skill                    -- step 2: grain up, matches only
JOIN req ON req.role = rr.role
GROUP BY rr.role, es.employee_id, req.n_required                 -- step 3: grain down to (role, employee)
HAVING COUNT(DISTINCT rr.skill) = req.n_required                 -- step 4: all of the role's skills
ORDER BY rr.role, es.employee_id;                                -- step 5
```

Where to put the deduplication is a design choice: `COUNT(DISTINCT …)` after the join (above), or `SELECT DISTINCT employee_id, skill` before it (approach 2). Both are correct.

Self-check: take one reported pair and check that every required skill appears in the employee's claims. Take a role you know has a pair "one skill short" and confirm it is absent. Add a duplicate claim for an employee who is short, and confirm they are still absent.

## 5. Approaches: brute force → optimal

### Approach 1: double `NOT EXISTS` over every (role, employee) (`solutions/01_double_not_exists.sql`)

```sql
SELECT r.role, e.employee_id
FROM (SELECT DISTINCT role FROM RoleRequirements) r
CROSS JOIN (SELECT DISTINCT employee_id FROM EmployeeSkills) e
WHERE NOT EXISTS (
  SELECT 1 FROM RoleRequirements rr
  WHERE rr.role = r.role
    AND NOT EXISTS (SELECT 1 FROM EmployeeSkills es
                    WHERE es.employee_id = e.employee_id AND es.skill = rr.skill))
ORDER BY r.role, e.employee_id;
```

**Why it is correct:** the definition of division. For a given role and employee, if some required skill has no claim from that employee, the pair is rejected. The pairs that survive have no such skill. Duplicates and extra skills are irrelevant to an existence test, and there is no count to get wrong. It reads as "there is no required skill that the employee lacks".

**Cost model (reasoned):** it starts from the full grid roles × employees, and for each pair loops over the role's required skills and probes the claims. Work is roughly roles × employees × skills-per-role probes, independent of how many pairs qualify. The probe is a scan of `EmployeeSkills` without an index, a point lookup with `(employee_id, skill)`.

### Approach 2: deduplicate the claims first, then count (`solutions/02_dedupe_then_count.sql`)

```sql
WITH claims AS (SELECT DISTINCT employee_id, skill FROM EmployeeSkills),
req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role),
hits AS (SELECT rr.role, c.employee_id, COUNT(*) AS n_hit
         FROM RoleRequirements rr JOIN claims c ON c.skill = rr.skill
         GROUP BY rr.role, c.employee_id)
SELECT h.role, h.employee_id
FROM hits h JOIN req ON req.role = h.role
WHERE h.n_hit = req.n_required
ORDER BY h.role, h.employee_id;
```

**Why it is correct:** after `DISTINCT`, each `(employee, skill)` occurs once, so each requirement matches at most one claim per employee and the plain `COUNT(*)` in `hits` equals the number of covered skills. The comparison with the role's own requirement count then decides.

**Cost model (reasoned):** one extra pass to deduplicate (a temporary table with deduplication), then a join whose output contains no repeated claims, then a `COUNT(*)` that needs no per-group set. The idea is to put the deduplication where it is cheapest, before the multiplying join. It pays when duplicates are the main source of join rows (as in problem 13, where several products map to one category). Here duplicates are exact repeats of a single row, so the join has far fewer rows to lose, while the deduplication has to materialise and index the whole claims table, and `hits` then materialises one row per (role, employee) pair that shares *any* skill before the comparison filters them. That is more work than the filter-while-grouping in approach 3, and it is the form MySQL handles worse: treat this as an optimisation to be tested, not assumed (the bench table is the arbiter).

### Approach 3 (optimal): join, then `COUNT(DISTINCT)` in `HAVING` (`solutions/03_join_count_distinct.sql`)

The SQL is the assembled query in section 4.

**Why it is correct:** the join yields one row per `(role, required skill, claim)`, so the grouped rows of a pair hold every claim that matched a required skill of that role. `COUNT(DISTINCT rr.skill)` counts the role's skills covered, ignoring repeated claims. The `HAVING` compares with this role's count, joined 1:1. Remove the `DISTINCT` and duplicate claims distort the count in both directions (`mistakes/count_star_on_join.sql`); replace `req.n_required` by a global count and the typical dataset breaks (`mistakes/global_requirement_count.sql`).

**Cost model (reasoned):** the join starts from the pairs that have at least one match, so it never builds the full roles × employees grid. Its output is Σ over skills of (roles requiring the skill × claim rows holding it), duplicates included, which can be large for popular skills. The group-by collapses it and discards the short groups in `HAVING` as they complete, so only qualifying pairs reach the sort. No intermediate table is materialised and indexed.

**Measured** (`gen.py` data, generated by the bench workflow; the table is filled in automatically, so never type numbers here):

<!-- BENCH:15-employees-qualified-for-every-required-skill-of-a-role -->
<!-- /BENCH -->

### Why the optimal one wins

Approaches 2 and 3 touch only pairs that share at least one skill, whereas approach 1 pays for every role × employee pair, most of which are hopeless. Between 2 and 3, approach 3 is one join and one aggregation that filters in `HAVING`, with no intermediate result materialised, while approach 2 adds a deduplication pass and an intermediate table. The tempting rule "deduplicate before a multiplying join" (problem 13) is a heuristic, not a law: it helps when duplicates cause most of the join's rows, and costs a pass otherwise. When the heuristic and the measurement disagree, the measurement wins; that is why this guide's optimal approach is the one that does not apply it.

## 6. At scale

**(a) What breaks first.** *Reasoned, then checked by the bench table:* approach 1, because roles × employees grows with both, and most pairs are hopeless. Approaches 2 and 3 share the same limit, the size of the skill-matching join (popular skills); approach 2 adds the cost of deduplicating and materialising before it.

**(b) One machine, ~1M–100M rows.**
- `EmployeeSkills` is a heap. `indexes.sql` adds `(skill, employee_id)`, which lets the join from each required skill read the holders' ids from the index alone, and `(employee_id, skill)`, which turns approach 1's innermost probe into a point lookup. Both are covering for what they serve.
- Both `skill` columns use a binary collation (Assumption 1). It should make comparisons cheaper (reasoned: a byte comparison, no collation weights) and it makes the indexes exact, but it is a schema decision that has to be in place before the data is loaded.
- The join output is Σ over skills of (roles requiring × holders). A skill held by most employees and required by many roles dominates. Putting rare required skills first and intersecting is the classic remedy, but SQL engines choose join order for you; check the plan.
- **Bitmask alternative (reasoned):** if the skill universe is small (at most 64 skills), map each skill to a bit position, build each employee's mask with `BIT_OR(1 << idx)` and each role's mask the same way, and qualify with `(emp_mask & role_mask) = role_mask`. That is one pass over claims, duplicates are harmless (OR is idempotent), and the role-employee comparison is a single integer test over roles × employees rows of aggregates. It does not generalise to hundreds of skills without wider bitsets.

**(c) Distributed engines, billions of rows. *Reasoned, not measured.***
- *Join strategy:* `RoleRequirements` is small, so it is broadcast to every worker and the big `EmployeeSkills` side is not shuffled for the join. The shuffle is the later `GROUP BY (role, employee_id)`; partial counts per task shrink it.
- *Deduplicating claims:* a global `DISTINCT (employee_id, skill)` is a shuffle by both columns; if the source guarantees uniqueness (a key at load time) skip it, otherwise it is the price of approach 2. Approach 3 instead pays with a `COUNT(DISTINCT)`, which cannot pre-aggregate to one number per task; which is cheaper depends on how many duplicates there are, so measure on the engine you use.
- *Skew:* popular skills create popular join keys when the join is a shuffle join. With the small side broadcast, skew only matters for the group-by, where an employee with an enormous number of claims is one key.
- *Output size:* the answer itself can be roles × employees if roles are lenient. For downstream use, store it as a table and maintain it, rather than recomputing.
- *Approximate functions:* never. The comparison is an exact count equality; an HLL estimate would turn qualified employees into unqualified ones at random.

**(d) The data-engineering answer.** Maintain, for each `(role, employee)`, how many distinct required skills the employee holds, and update it when claims or requirements change. Qualification is then `n_hit = n_required`, a lookup rather than a query.

```sql
-- claims_seen(employee_id, skill, PRIMARY KEY (employee_id, skill))    -- the deduplicated claims (idempotent set)
-- role_employee_hits(role, employee_id, n_hit, PRIMARY KEY (role, employee_id))
-- Snowflake / ANSI MERGE (UNVERIFIED). One batch of new claims:
CREATE OR REPLACE TEMPORARY TABLE new_claims AS
SELECT DISTINCT b.employee_id, b.skill
FROM claims_batch b
WHERE NOT EXISTS (SELECT 1 FROM claims_seen s WHERE s.employee_id = b.employee_id AND s.skill = b.skill);

MERGE INTO role_employee_hits t
USING (SELECT rr.role, n.employee_id, COUNT(*) AS add_hit
       FROM new_claims n JOIN RoleRequirements rr ON rr.skill = n.skill
       GROUP BY rr.role, n.employee_id) s
ON t.role = s.role AND t.employee_id = s.employee_id
WHEN MATCHED THEN UPDATE SET n_hit = t.n_hit + s.add_hit
WHEN NOT MATCHED THEN INSERT (role, employee_id, n_hit) VALUES (s.role, s.employee_id, s.add_hit);

INSERT INTO claims_seen SELECT employee_id, skill FROM new_claims;

-- Read side: qualified pairs.
SELECT h.role, h.employee_id
FROM role_employee_hits h JOIN (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role) r ON r.role = h.role
WHERE h.n_hit = r.n_required ORDER BY h.role, h.employee_id;
```

Caveats interviewers probe. *Idempotency:* the `NOT EXISTS` against `claims_seen` is what makes a replayed batch add nothing. *Changing requirements:* adding a required skill to a role raises `n_required` and gives each employee already holding that skill one more hit, which means joining `claims_seen` with just the new requirement; removing one needs the opposite. *Retractions:* an employee losing a skill must decrement the hits of each role that requires it, but only when the employee has no other claim for that skill (hence the deduplicated set).

## 7. Edge cases

Each "breaks" claim below is checked by execution: `mistakes/*.sql` are the tempting wrong queries, and the harness asserts that each one fails every dataset it names (`harness/test_mistakes.py`).

| Case | Dataset | Wrong queries it catches (`mistakes/`) |
|---|---|---|
| Roles with different requirement counts; one employee qualifying for two roles; extra skills | `tests/edge_typical.sql` | `global_requirement_count`, `exact_skill_set` (rejects extras), `any_required_skill` |
| Duplicate claim rows: same count of rows as requirements but fewer skills; extra duplicates overshooting the count | `tests/edge_duplicates.sql` | `count_star_on_join` |
| A role nobody satisfies (everyone has two of three) next to a role they do satisfy | `tests/edge_unsatisfied_role.sql` | `any_required_skill` |
| Exact matching: wrong case, trailing space | `tests/edge_exact_match.sql` | `lower_trim_match`, `case_insensitive_collation` |
| Scrambled input order; employee ids 3, 20, 100 | `tests/edge_ordering.sql` | `employee_first_ordering` |
| Roles exist, no claims | `tests/edge_empty.sql` | none |

No approach in `solutions/` is broken by any of these.

## 8. Interviewer follow-ups

1. **"What if some roles need at least 3 of a list of 5 skills?"** The divisor becomes a per-role threshold: store `min_required` per role and compare `n_hit >= min_required`. The counting form generalises; double negation does not. This is why counting is the answer to keep.
2. **"Also return the missing skills for near-misses."** An anti-join per (role, employee): requirements minus claims. Generate the candidate pairs first (for example employees who match at least half), then `LEFT JOIN` claims and keep the unmatched requirements. See the grid approach in `14-customers-who-bought-all-products`.
3. **"Why not compare sorted skill lists as strings?"** `GROUP_CONCAT` of each side only works for *equal* sets, not "contains", and depends on collation and ordering. Containment needs `JSON_CONTAINS` or a join, and neither can use an index.
4. **"A new employee table exists; list employees with no skills too."** Then "every skill of a role" has a vacuous truth for roles with no requirements and none otherwise; the employees with no claims never match a non-empty role. Decide whether roles without requirements should appear (spec: they do not).
5. **"The skill names are dirty ('SQL', 'sql ')."** Normalise **upstream** (in the load) and keep the exact comparison in the query. Normalising inside the query hides the problem and defeats indexes (`LOWER(skill)` is not indexable without a functional index).
6. **"Compare with problem 14."** Same division, but there the divisor was a single table-wide number, here it is per group. If you only remember one thing: *for each group* means the divisor is a join, not a scalar.

## 9. Snowflake notes (UNVERIFIED)

`snowflake.sql` keeps the shape of approach 3, without any collation clause.

- Snowflake compares strings **case-sensitively with no padding** by default, which is exactly the spec's "exact string equality". That is the opposite of MySQL's default, so the MySQL schema needs the binary collation and Snowflake needs nothing. If the columns were created with a case-insensitive collation (`COLLATE 'en-ci'`), that would break the spec in Snowflake too.
- Unlike MySQL, primary keys are not enforced in Snowflake. `RoleRequirements` could contain a duplicate `(role, skill)`, which would inflate `n_required`. Defend with `SELECT DISTINCT role, skill` in the `req` CTE if the source is not trusted.
- An array-based alternative: `ARRAY_AGG(DISTINCT skill)` per employee, and `ARRAY_AGG(skill)` per role, then test containment with `ARRAY_INTERSECTION` and `ARRAY_SIZE`. It avoids the join but builds arrays per employee and per role; it is attractive when each employee has few skills.
- No indexes; `indexes.sql` has no equivalent. Costs are bytes scanned and the size of the group-by after the join. Clustering `EmployeeSkills` by `skill` helps pruning for narrow skill lists.
- Unquoted identifiers are returned upper-cased (`ROLE`, `EMPLOYEE_ID`).

## 10. Pattern links

Same pattern (relational division):
- `14-customers-who-bought-all-products`: the same division with a single global divisor; read it first.
- `11-analyze-subscription-conversion`: "has both of two values", the smallest division.

Related (deduplicate before a multiplying join, count at the right grain):
- `13-find-category-recommendation-pairs`: dedupe to `(customer, category)` before the self-join, where the heuristic does pay.
- `12-find-product-recommendation-pairs`: the pair-counting version of "who shares what".
