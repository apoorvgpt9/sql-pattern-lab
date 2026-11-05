# Review A: problems 01–24 (independent pass)

Scores are 1–5 (5 = no change needed). "Correctness" covers spec fidelity and adversarial testing: every
new dataset was run on MySQL 8.0.46 against every solution, and its expected output was computed by hand.
"At scale" covers whether the performance text matches `bench/results/<dir>.json` (bench run of 2026-11-04).

Solution files were **not renumbered** in this pass, even where the bench shows a non-"optimal" approach
ahead. The bench workflow commits only from `main`, so renamed files would leave the rendered tables showing
stale names until someone re-runs it. In every case in 01–24 the gap without indexes is ≤ 20% or flips
between sizes, so the text was rewritten to match the measurements instead.

| Problem | Correctness | Decomposition | Hints | At scale | What changed |
|---|:-:|:-:|:-:|:-:|---|
| 01-market-analysis-i | 5 | 5 | 5 | 5 | Nothing. Tried NULL buyer, year boundaries, orphan buyers, duplicate-looking orders: all already covered by edge sets; text matches bench. |
| 02-confirmation-rate | 5 | 5 | 5 | 2 | Bench: 02 (join then group) is ~20% faster than "optimal" 03 at 1M in both phases. The README's cost models contradicted the bench's own EXPLAIN ANALYZE (it claimed a hash join + temp-table aggregate for 02; the plan is a PK nested loop with a streaming aggregate, while 03 pays to materialise the CTE). Rewrote the approach 1–3 cost models, "Why the optimal one wins", 6(a), and the index bullet in 6(b) (the index changes nothing measurable). |
| 03-investments-in-2016 | 5 | 5 | 5 | 2 | Correctness held: tried signed zero (`0` vs `-0.0`) as tiv twins, NULL tiv, and twins disqualified by their own location; all solutions agree. Bench: with `indexes.sql` the "optimal" EXISTS query becomes ~10× slower (1.7 s → 16.8 s at 1M) and the slowest of the three, because the optimizer swaps the hash semi-join for a nested loop with duplicate weed-out. The README only hedged about this. Rewrote section 5 cost models (02's plan does not use the indexes; 03's index trap), "Why the optimal one wins", 6(a), 6(b), and the stale approach numbering in `indexes.sql`; added a note to the 03 solution header. |
