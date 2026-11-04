-- Approach 2: one aggregate per parity, then stitch them onto the list of dates.
-- Two scans of the table instead of two per date. The LEFT JOINs keep days that have only one parity;
-- an INNER JOIN between odd_day and even_day would drop them.
WITH days AS (
  SELECT DISTINCT transaction_date FROM transactions
),
odd_day AS (
  SELECT transaction_date, SUM(amount) AS s
  FROM transactions
  WHERE MOD(amount, 2) <> 0
  GROUP BY transaction_date
),
even_day AS (
  SELECT transaction_date, SUM(amount) AS s
  FROM transactions
  WHERE MOD(amount, 2) = 0
  GROUP BY transaction_date
)
SELECT
  d.transaction_date,
  COALESCE(o.s, 0) AS odd_sum,
  COALESCE(e.s, 0) AS even_sum
FROM days d
LEFT JOIN odd_day  o ON o.transaction_date = d.transaction_date
LEFT JOIN even_day e ON e.transaction_date = d.transaction_date
ORDER BY d.transaction_date;
