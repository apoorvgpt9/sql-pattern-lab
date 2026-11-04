-- Ordering: user_id ascending as a NUMBER (7, 20, 30, 100), inserted scrambled.
-- Sorted as text the order would be 100, 20, 30, 7.
INSERT INTO UserActivity (user_id, activity_date, activity_type, activity_duration) VALUES
  (30,  '2024-06-01', 'free_trial', 10), (30,  '2024-06-05', 'paid', 20),
  (7,   '2024-06-01', 'free_trial',  4), (7,   '2024-06-05', 'paid',  8),
  (100, '2024-06-01', 'free_trial',  1), (100, '2024-06-05', 'paid',  2),
  (20,  '2024-06-01', 'free_trial',  6), (20,  '2024-06-05', 'paid', 12);

-- expect: 7,4.00,8.00 | smallest id first
-- expect: 20,6.00,12.00 | second
-- expect: 30,10.00,20.00 | third
-- expect: 100,1.00,2.00 | largest id last (numeric, not alphabetical)
