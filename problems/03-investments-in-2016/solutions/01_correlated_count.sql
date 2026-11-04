-- Approach 1 (brute force): per policy, COUNT the policies with the same tiv_2015 and the same location,
-- with correlated scalar subqueries. The count includes the policy itself, hence "> 1" and "= 1".
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE (SELECT COUNT(*) FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015) > 1
  AND (SELECT COUNT(*) FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon) = 1;
