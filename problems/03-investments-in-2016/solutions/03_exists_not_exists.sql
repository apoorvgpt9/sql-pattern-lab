-- Approach 3 (optimal on MySQL 8.0): the wording is about EXISTENCE of another row, not a count, so say exactly
-- that. EXISTS / NOT EXISTS lets the optimizer use a semi-join and an anti-join (hash joins in 8.0) that stop
-- at the first match, instead of counting every twin. `pid <> i.pid` is what makes it "another" policy.
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE EXISTS (SELECT 1 FROM Insurance j
              WHERE j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid)
  AND NOT EXISTS (SELECT 1 FROM Insurance k
                  WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);
