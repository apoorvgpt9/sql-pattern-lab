-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
SELECT
  transaction_date,
  SUM(IFF(MOD(amount, 2) <> 0, amount, 0)) AS odd_sum,   -- MOD keeps the sign of the dividend here too
  SUM(IFF(MOD(amount, 2) =  0, amount, 0)) AS even_sum   -- NULL amount -> condition is NULL -> IFF takes the else branch
FROM transactions
GROUP BY transaction_date
ORDER BY transaction_date;
