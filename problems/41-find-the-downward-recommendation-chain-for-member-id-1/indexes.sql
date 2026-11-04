-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (recommendedby) turns "who did X recommend?" into an index range read:
--   03: the anchor (recommendedby = 1) and every recursive step (m.recommendedby = d.memid) probe
--       the index instead of scanning all members once per level;
--   01: walks up via the primary key, so it gains little; its cost is the size of the closure.
CREATE INDEX idx_members_recommendedby ON members (recommendedby);
