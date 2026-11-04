-- Indexes recommended in README "At scale" (b). The bench runs every solution without them, then with them.
-- Both are covering for the lookups (pid is the tie-break column the "other policy" test needs):
--   01: each EXISTS / NOT EXISTS probe becomes an index range read, no table access;
--   02: the GROUP BY ... HAVING subqueries aggregate in index order (no temporary table);
--   03: the window PARTITION BY can read rows already in partition order instead of sorting.
CREATE INDEX idx_insurance_tiv15 ON Insurance (tiv_2015, pid);
CREATE INDEX idx_insurance_loc   ON Insurance (lat, lon, pid);
