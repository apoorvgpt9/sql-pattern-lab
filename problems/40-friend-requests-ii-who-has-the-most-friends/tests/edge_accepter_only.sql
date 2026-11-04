-- The winner (9) never sent a request: they appear only in accepter_id.
-- Requester-only counting misses them, and so does an INNER JOIN of per-role counts.
INSERT INTO RequestAccepted (requester_id, accepter_id, accept_date) VALUES
  (1, 9, '2024-02-01'),
  (2, 9, '2024-02-02'),
  (3, 9, '2024-02-03'),
  (1, 2, '2024-02-04');

-- expect: 9,3 | accepter in (1,9), (2,9), (3,9) and never a requester. Others: 1 has 2 ((1,9),(1,2)), 2 has 2 ((2,9),(1,2)), 3 has 1
