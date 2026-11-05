-- Index discussed in README "At scale" (b). The bench runs every solution without it, then with it.
-- A FUNCTIONAL index (MySQL 8.0.13+) on the exact grouping expression, then country, then the two columns the
-- aggregates read. The optimizer uses it only when the query repeats the expression DATE_FORMAT(trans_date,'%Y-%m').
-- What the bench measured (README 6b): the GROUP BY does become a streaming group aggregate, but the plan reads the
-- index as a NON-covering "Index scan" with a clustered-row fetch per entry, and every approach except 01 gets
-- slower (03: about 3x at 1M rows). Kept so the bench keeps showing the trade-off; do not create it for this query.
CREATE INDEX idx_tx_month_country
  ON Transactions ((DATE_FORMAT(trans_date, '%Y-%m')), country, state, amount);
