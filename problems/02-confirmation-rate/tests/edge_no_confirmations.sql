-- Confirmations is completely empty: every signed-up user is a "no requests" user.
INSERT INTO Signups (user_id, time_stamp) VALUES
  (1, '2021-03-01 00:00:00'),
  (2, '2021-03-02 00:00:00'),
  (3, '2021-03-03 00:00:00');

-- expect: 1,0.00 | no requests -> 0.00
-- expect: 2,0.00 | no requests -> 0.00
-- expect: 3,0.00 | no requests -> 0.00
