-- breaks: edge_id_vs_date_gaps
-- MISTAKE: after filtering to busy days, "the next busy row" is not "the next id". Counting runs
-- by position in the filtered list (here: ROW_NUMBER minus a count of quiet rows before it)
-- glues busy rows together across ids that do not exist.
WITH flagged AS (
  SELECT id, visit_date, people,
         SUM(CASE WHEN people >= 100 THEN 0 ELSE 1 END) OVER (ORDER BY id) AS quiet_before
  FROM Stadium
),
sized AS (
  SELECT id, visit_date, people, COUNT(*) OVER (PARTITION BY quiet_before) AS island_size
  FROM flagged
  WHERE people >= 100
)
SELECT id, visit_date, people FROM sized WHERE island_size >= 3
ORDER BY visit_date;
