-- The winner (4) only ever sent requests; the mirror image of edge_accepter_only.
-- User 8 has the most rows as an accepter (2), so an accepter-only count picks 8.
INSERT INTO RequestAccepted (requester_id, accepter_id, accept_date) VALUES
  (4, 1, '2024-04-01'),
  (4, 2, '2024-04-01'),
  (4, 8, '2024-04-02'),
  (6, 8, '2024-04-03');

-- expect: 4,3 | requester in (4,1), (4,2), (4,8), never an accepter. 8 has 2 (accepter twice); 1, 2, 6 have 1
