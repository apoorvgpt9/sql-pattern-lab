-- Typical: the winner (3) is a requester twice and an accepter twice. User 1 has the most rows as a
-- requester (3), so any count that looks at only one column picks the wrong person.
INSERT INTO RequestAccepted (requester_id, accepter_id, accept_date) VALUES
  (1, 2, '2024-01-01'),
  (1, 3, '2024-01-02'),
  (1, 4, '2024-01-03'),
  (3, 5, '2024-01-04'),
  (3, 6, '2024-01-04'),
  (7, 3, '2024-01-05'),
  (5, 6, '2024-01-06');

-- expect: 3,4 | accepter in (1,3) and (7,3), requester in (3,5) and (3,6): 2 + 2 = 4. Next best: user 1 with 3 (requester only); 5 and 6 have 2; 2, 4, 7 have 1
