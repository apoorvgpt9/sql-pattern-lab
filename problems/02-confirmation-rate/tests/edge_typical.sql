-- Typical mix: partial, none confirmed, all confirmed, no requests at all, half and half.
INSERT INTO Signups (user_id, time_stamp) VALUES
  (1, '2020-01-01 10:00:00'),
  (2, '2020-01-01 11:00:00'),
  (3, '2020-01-02 09:00:00'),
  (4, '2020-01-02 10:00:00'),
  (5, '2020-01-03 08:00:00');

INSERT INTO Confirmations (user_id, time_stamp, action) VALUES
  (1, '2020-01-01 10:05:00', 'confirmed'),
  (1, '2020-01-02 10:05:00', 'timeout'),
  (1, '2020-01-03 10:05:00', 'confirmed'),
  (2, '2020-01-01 11:05:00', 'timeout'),
  (2, '2020-01-02 11:05:00', 'timeout'),
  (3, '2020-01-02 09:05:00', 'confirmed'),
  (5, '2020-01-03 08:05:00', 'confirmed'),
  (5, '2020-01-04 08:05:00', 'timeout');

-- expect: 1,0.67 | 2 confirmed of 3 requests = 0.6667 -> 0.67
-- expect: 2,0.00 | 0 confirmed of 2 requests
-- expect: 3,1.00 | 1 of 1
-- expect: 4,0.00 | signed up but made no request: 0, not NULL, and the user must still appear
-- expect: 5,0.50 | 1 of 2
