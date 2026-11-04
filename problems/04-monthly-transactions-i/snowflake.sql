-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
SELECT TO_CHAR(trans_date, 'YYYY-MM')                          AS month,
       country,
       COUNT(*)                                                AS trans_count,
       COUNT_IF(state = 'approved')                            AS approved_count,
       SUM(amount)                                             AS trans_total_amount,
       SUM(IFF(state = 'approved', amount, 0))                 AS approved_total_amount
FROM Transactions
GROUP BY TO_CHAR(trans_date, 'YYYY-MM'), country;
