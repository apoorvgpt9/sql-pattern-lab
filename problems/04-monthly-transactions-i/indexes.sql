-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- A FUNCTIONAL index (MySQL 8.0.13+) on the exact grouping expression, then country, then the two columns the
-- aggregates read. The optimizer uses it only when the query repeats the expression DATE_FORMAT(trans_date,'%Y-%m').
--   - covering for all three solutions: no clustered-row fetches;
--   - the GROUP BY (expression, country) arrives already in index order, so a streaming group aggregate replaces the
--     temporary table (checked with EXPLAIN on a sample for approach 3).
-- A plain index on trans_date cannot do this: the grouping key is a function of it, not the column itself.
CREATE INDEX idx_tx_month_country
  ON Transactions ((DATE_FORMAT(trans_date, '%Y-%m')), country, state, amount);
