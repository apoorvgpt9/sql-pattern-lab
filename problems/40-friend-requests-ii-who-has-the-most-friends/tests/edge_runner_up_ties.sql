-- Unique winner, three-way tie for second place. A tie below the top does not affect LIMIT 1.
INSERT INTO RequestAccepted (requester_id, accepter_id, accept_date) VALUES
  (50, 10, '2024-03-01'),
  (20, 50, '2024-03-02'),
  (50, 30, '2024-03-03'),
  (10, 20, '2024-03-04'),
  (30, 40, '2024-03-05');

-- expect: 50,3 | requester in (50,10) and (50,30), accepter in (20,50): 3. Then 10, 20, 30 tie at 2 and 40 has 1
