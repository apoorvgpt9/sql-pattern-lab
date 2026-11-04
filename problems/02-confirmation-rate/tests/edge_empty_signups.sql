-- Signups is empty but Confirmations is not (requests from users we know nothing about).
INSERT INTO Confirmations (user_id, time_stamp, action) VALUES
  (1, '2021-04-01 10:00:00', 'confirmed'),
  (2, '2021-04-01 11:00:00', 'timeout');

-- expect-empty: the output grain is Signups; with no signups there are no users to report on
