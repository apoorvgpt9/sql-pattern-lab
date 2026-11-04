-- Approach 1 (brute force): list the distinct (month, country) groups, then compute each of the four
-- numbers for each group with its own correlated subquery. `<=>` (NULL-safe equality) is what lets the
-- NULL-country group find its own rows: `country = NULL` is never true.
SELECT g.month, g.country,
       (SELECT COUNT(*) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country) AS trans_count,
       (SELECT COUNT(*) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country
           AND t.state = 'approved') AS approved_count,
       (SELECT SUM(t.amount) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country) AS trans_total_amount,
       (SELECT COALESCE(SUM(t.amount), 0) FROM Transactions t
         WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = g.month AND t.country <=> g.country
           AND t.state = 'approved') AS approved_total_amount
FROM (SELECT DISTINCT DATE_FORMAT(trans_date, '%Y-%m') AS month, country FROM Transactions) g;
