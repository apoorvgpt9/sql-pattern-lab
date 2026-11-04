-- Confirmations for users who are not in Signups (users 98 and 99). They must not create output rows.
INSERT INTO Signups (user_id, time_stamp) VALUES
  (1, '2022-05-01 08:00:00');

INSERT INTO Confirmations (user_id, time_stamp, action) VALUES
  (1,  '2022-05-01 08:05:00', 'confirmed'),
  (98, '2022-05-01 09:00:00', 'confirmed'),
  (99, '2022-05-01 09:00:00', 'timeout'),
  (99, '2022-05-02 09:00:00', 'timeout');

-- expect: 1,1.00 | the only signed-up user; 1 of 1. Users 98 and 99 are not signups, so they are not reported
