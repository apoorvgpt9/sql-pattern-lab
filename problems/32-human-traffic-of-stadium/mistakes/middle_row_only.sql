-- breaks: edge_typical, edge_boundary_100, edge_id_vs_date_gaps, edge_nulls, edge_ordering
-- MISTAKE: checking only the immediate neighbours (id-1 and id+1 both busy) finds the middle of a
-- triple, never its first or last row.
WITH busy AS (
  SELECT id, visit_date, people,
         LAG(id)  OVER (ORDER BY id) AS prev_id,
         LEAD(id) OVER (ORDER BY id) AS next_id
  FROM Stadium
  WHERE people >= 100
)
SELECT id, visit_date, people
FROM busy
WHERE prev_id = id - 1 AND next_id = id + 1
ORDER BY visit_date;
