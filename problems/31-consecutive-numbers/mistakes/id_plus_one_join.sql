-- breaks: edge_id_gaps
-- MISTAKE: Joining on id + 1 and id + 2. It is the textbook version, and it silently requires gap-free ids:
-- the project's reading of 'consecutive' is adjacent in id order, so rows around a deleted id still count as neighbours.
SELECT DISTINCT l1.num AS ConsecutiveNums
FROM Logs l1
JOIN Logs l2 ON l2.id = l1.id + 1
JOIN Logs l3 ON l3.id = l1.id + 2
WHERE l1.num = l2.num AND l2.num = l3.num;
