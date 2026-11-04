# Curation report: sql-pattern-lab problems.yaml

Curated 2026-11-04. 45 problems: 32 Medium and 13 Hard. Sources: 39 LeetCode, 4 pgexercises (CC BY-SA 3.0), 2 original.

## Count by primary pattern

| pattern_primary | Medium | Hard | Total | Notes |
|---|---|---|---|---|
| anti_join (existence / LEFT JOIN preserve) | 3 | 0 | 3 | 608 and 3617 use it as a secondary pattern |
| conditional_aggregation | 3 | 1 | 4 | |
| pivot | 3 | 0 | 3 | 3220, 3601, 3497 |
| date_spine (scaffold / calendar fill) | 1 | 1 | 2 | 1907 (category scaffold), pgex rollingavg (real calendar) |
| self_join / pairwise | 2 | 1 | 3 | 3521, 3554, 602 |
| relational_division | 1 | 1 | 2 | 1045 plus 1 original |
| ranking_per_group | 3 | 1 | 4 | |
| dedup_latest (latest/first record per key) | 4 | 0 | 4 | 3716 is the hardest of these |
| retention_cohort | 2 | 0 | 2 | 550, 1174 |
| lag_lead | 2 | 1 | 3 | |
| running_totals / moving windows | 2 | 0 | 2 | pgex rollingavg covers moving window as a secondary pattern |
| gaps_and_islands | 1 | 2 | 3 | |
| sessionization / event sequencing | 2 | 2 | 4 | |
| recursive_cte / hierarchy | 2 | 2 | 4 | 608, pgex x2, 3482 |
| median_percentile | 1 | 1 | 2 | pgex NTILE plus 1 original |

Batches: B1 7, B2 8, B3 9, B4 7, B5 7, B6 7. They run from foundations to advanced, as listed in the header of problems.yaml.

## How free status was verified

- I checked every LeetCode pick against 3 indexes. The doocs/leetcode `DATABASE_README_EN.md` shows no lock. The Zanger67/leetcode-question-data `data/leetcode.json` has `paidOnly=false`; this is a raw LeetCode GraphQL dump committed 2026-11-04. kamyu104/LeetCode-Solutions is the third index.
- doocs and Zanger67 agree on all 50 free Medium/Hard database problems. kamyu104 still shows a lock on 19 of the older ones (550, 570, 585, 602, 608, 1045, 1070, 1158, 1164, 1174, 1193, 1204, 1321, 1341, 1393, 1907, 1934, 3374, 3421). They look like former Premium problems that are now free; kamyu's README is out of date there. I accepted them because the two current sources agree, and I recorded the disagreement in `free_evidence`.
- I could not reach leetcode.com or leetcode.cn directly (the proxy returns 403), so `postgres_on_leetcode` is `unknown` for every LeetCode item.

## Gaps in the free pool and what I did

There are only about 50 free Medium/Hard database problems in total. The ones that would naturally cover these patterns are Premium: 569/571 (median), 579 (cumulative), 1127/1384/1635 (spine/calendar), 1225/1285 (islands), 534 (running total) and the Game Play cohort series.

- **median_percentile**: there is no free LeetCode problem for this. I added pgexercises `aggregates/classify` (NTILE terciles, CC BY-SA). I also wrote an original problem, SPL-MED-01, for the true median with odd/even counts.
- **date_spine**: there is no free LeetCode calendar problem. 1907 only teaches the scaffold + LEFT JOIN idea. I added pgexercises `aggregates/rollingavg`, which needs a 31-day calendar with zero-fill. On MySQL that calendar has to come from a recursive CTE.
- **recursive_cte**: the only free LeetCode problem that needs recursion is 3482. I added pgexercises `recursive/getdownward` and `recursive/getupwardall` as a medium-to-hard ramp. 608 Tree Node is tagged here as an easy way in, but it does not actually need recursion.
- **relational_division**: the only free LeetCode problem is 1045. I wrote SPL-DIV-01 for per-group division.
- **retention_cohort and running_totals**: only 2 problems each, both Medium. I accepted this. 3716, 3764 and the pgex rolling average add depth as secondary patterns.
- **pgexercises license**: content is CC BY-SA 3.0. Evidence is the site footer and `questions/LICENSE` in github.com/AlisdairO/pgexercises. Specs are reworded and carry an `attribution` field. **Any repo files derived from them must stay CC BY-SA and keep that attribution.** Build sessions will not have the clubdata dump, so they must create fixtures that match the schema given in the YAML.
- I did not use StrataScratch, DataLemur or HackerRank. They are not openly licensed, and the gaps were covered without them.

## Problems with confidence below high

| id | LC # | confidence | What is uncertain |
|---|---|---|---|
| 4 | 1193 | medium | Hidden tests probably include a NULL `country`. I remember this from community discussion; it is not in the statement text. |
| 5 | 3657 | medium | The statement says "3 purchase transactions", but the reference solution counts all transactions. It is also unclear whether the 30-day span counts all transactions or purchases only. |
| 6 | 3705 | medium | Whether `peak_hour_percentage` is rounded to an integer, and whether exactly 14:00 and 21:00 count as peak. Both are inferred from the reference solution. |
| 10 | 3601 | medium | Dropping drivers who did not improve is inferred from the title and the reference solution. |
| 18 | 3626 | medium | The statement does not say how to break price ties within a store. I used the reference tiebreak (quantity DESC). |
| 33 | 3832 | medium | Not specified what happens when one user has two longest streaks of equal length. |
| 35 | 3611 | medium | The statement says "> 20 hours" but the reference solution uses ">= 20". |
| 37 | 3673 | medium | The statement says "more than 30 minutes" but the reference solution uses ">= 30". |
| 38 | 3617 | low | The definition of the pattern is vague. My spec follows the doocs reference interpretation: the whole history must be the cycle, with no search for a qualifying sub-window. Check this on LeetCode before writing tests. |

I based the specs on the doocs mirror of the problem statements and its reference MySQL solutions. Where the two disagree, `rules.other` says so.

## Other decisions

- Pattern keys are snake_case versions of the requested names: `dedup_latest`, `retention_cohort` and `median_percentile`.
- I left out the free problems that do not fit the target patterns: string and regex problems (3374, 3451, 3475) and the simple top-1 problems (176, 177, 178, 1341, 1393, 3642, 3808, 570). 3808 and 3642 would make good extra conditional_aggregation practice if you want more.

## Sources

- https://github.com/doocs/leetcode (solution/DATABASE_README_EN.md and the per-problem README_EN.md files)
- https://github.com/Zanger67/leetcode-question-data (data/leetcode.json)
- https://github.com/kamyu104/LeetCode-Solutions (README SQL section)
- https://pgexercises.com/ and https://github.com/AlisdairO/pgexercises (questions/LICENSE, CC BY-SA 3.0)
