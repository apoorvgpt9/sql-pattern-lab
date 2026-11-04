-- Nobody converted. Several users have two DIFFERENT activity types, but never both trial and paid:
-- counting distinct types (or any two rows) instead of the two specific types would let them through.
INSERT INTO UserActivity (user_id, activity_date, activity_type, activity_duration) VALUES
  (1, '2024-01-01', 'free_trial', 10),
  (1, '2024-01-02', 'free_trial', 12),
  (2, '2024-01-01', 'paid',       30),
  (3, '2024-01-01', 'free_trial', 10),
  (3, '2024-01-09', 'cancelled',   0),   -- trial then cancelled: two types, no conversion
  (4, '2024-01-01', 'paid',       30),
  (4, '2024-01-09', 'cancelled',   0),   -- paid then cancelled: two types, no trial
  (5, '2024-01-01', 'cancelled',   5);

-- expect-empty: no user has both a free_trial row and a paid row
