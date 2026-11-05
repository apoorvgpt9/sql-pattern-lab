-- Indexes discussed in README "At scale" (b). The bench runs every solution without them, then with them.
-- Both are covering for the lookups (pid is the tie-break column the "other policy" test needs):
--   01 (correlated counts): each probe becomes an index range read, no table access. This is what makes 01
--      finish at all.
--   02 (window counts): no effect. Each window still sorts, because it needs the whole row.
--   03 (EXISTS / NOT EXISTS): measured about 10x SLOWER with these. The optimizer drops the hash semi-join for
--      an index nested loop with duplicate weed-out (see the README and the bench EXPLAIN ANALYZE).
CREATE INDEX idx_insurance_tiv15 ON Insurance (tiv_2015, pid);
CREATE INDEX idx_insurance_loc   ON Insurance (lat, lon, pid);
