-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The primary key (requester_id, accepter_id) already serves every lookup or GROUP BY on requester_id.
-- accepter_id has no index of its own, so:
--   01: the OR in each correlated count can become an index merge (PK range + this index) instead of a full scan;
--   02/03: GROUP BY accepter_id can stream in index order instead of building a temporary table.
CREATE INDEX idx_ra_accepter ON RequestAccepted (accepter_id);
