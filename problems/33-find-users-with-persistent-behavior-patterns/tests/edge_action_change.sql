-- The action must be the same on every day of the streak. User 1 is active 6 days in a row, but
-- the action changes on 05-04, so 'a' has two streaks of 3 and 2 and 'b' a streak of 1.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-05-01', 'a'), (1, '2024-05-02', 'a'), (1, '2024-05-03', 'a'),
  (1, '2024-05-04', 'b'),                                   -- single action, but a different one
  (1, '2024-05-05', 'a'), (1, '2024-05-06', 'a'),
  (2, '2024-05-01', 'swim'), (2, '2024-05-02', 'swim'), (2, '2024-05-03', 'swim'),
  (2, '2024-05-04', 'swim'), (2, '2024-05-05', 'swim');

-- expect: 2,swim,5,2024-05-01,2024-05-05 | same action 5 days running; user 1 never repeats one action 5 days
