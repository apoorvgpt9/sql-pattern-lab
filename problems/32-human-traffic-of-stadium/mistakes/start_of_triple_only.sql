-- breaks: edge_typical, edge_boundary_100, edge_id_vs_date_gaps, edge_nulls, edge_ordering
-- MISTAKE: "display the records" means every row of the run. Returning only the row that starts
-- a triple (x, x+1, x+2) drops the last two rows of every run.
SELECT s1.id, s1.visit_date, s1.people
FROM Stadium s1
JOIN Stadium s2 ON s2.id = s1.id + 1 AND s2.people >= 100
JOIN Stadium s3 ON s3.id = s1.id + 2 AND s3.people >= 100
WHERE s1.people >= 100
ORDER BY s1.visit_date;
