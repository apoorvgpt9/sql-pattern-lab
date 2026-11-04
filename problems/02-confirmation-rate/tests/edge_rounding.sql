-- Rounding: a repeating decimal and an exact half. MySQL divides exact numbers (DECIMAL), giving 4 extra
-- decimal places, and ROUND on a DECIMAL rounds halves away from zero.
INSERT INTO Signups (user_id, time_stamp) VALUES
  (1, '2022-01-01 00:00:00'),
  (2, '2022-01-01 00:00:00'),
  (3, '2022-01-01 00:00:00');

-- user 1: 8 requests, 1 confirmed. user 2: 6 requests, 1 confirmed. user 3: none.
INSERT INTO Confirmations (user_id, time_stamp, action) VALUES
  (1, '2022-02-01 00:00:00', 'confirmed'),
  (1, '2022-02-02 00:00:00', 'timeout'),
  (1, '2022-02-03 00:00:00', 'timeout'),
  (1, '2022-02-04 00:00:00', 'timeout'),
  (1, '2022-02-05 00:00:00', 'timeout'),
  (1, '2022-02-06 00:00:00', 'timeout'),
  (1, '2022-02-07 00:00:00', 'timeout'),
  (1, '2022-02-08 00:00:00', 'timeout'),
  (2, '2022-03-01 00:00:00', 'timeout'),
  (2, '2022-03-02 00:00:00', 'confirmed'),
  (2, '2022-03-03 00:00:00', 'timeout'),
  (2, '2022-03-04 00:00:00', 'timeout'),
  (2, '2022-03-05 00:00:00', 'timeout'),
  (2, '2022-03-06 00:00:00', 'timeout');

-- expect: 1,0.13 | 1/8 = 0.1250 exactly; ROUND(0.1250, 2) rounds the half up -> 0.13 (binary floating point would give 0.12)
-- expect: 2,0.17 | 1/6 = 0.1667 (4 decimals) -> 0.17
-- expect: 3,0.00 | no requests
