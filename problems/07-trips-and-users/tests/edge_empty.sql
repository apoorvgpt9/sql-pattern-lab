-- Users exist, there are no trips.
INSERT INTO Users (users_id, banned, role) VALUES
  (1,  'No', 'client'),
  (10, 'No', 'driver');

-- expect-empty: no trips means no day has an eligible trip
