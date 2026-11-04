-- Target date is 2019-08-16. Typical mix, inserted out of date order on purpose:
-- product 1: two changes before the date; product 2: one before, one after (the after is ignored);
-- product 3: only a later change (default 10); product 4: price DROPPED over time (MAX would be wrong).
INSERT INTO Products (product_id, new_price, change_date) VALUES
  (2, 65, '2019-08-20'),
  (1, 30, '2019-08-12'),
  (4, 60, '2019-08-01'),
  (3, 20, '2019-08-18'),
  (1, 20, '2019-08-10'),
  (4, 80, '2019-07-01'),
  (2, 50, '2019-08-14');

-- expect: 1,30 | latest change on or before 2019-08-16 is 08-12 (30), not 08-10 (20)
-- expect: 2,50 | 08-14 (50) is in effect; the 08-20 change (65) has not happened yet
-- expect: 3,10 | its only change is on 08-18, after the date: initial price 10
-- expect: 4,60 | latest change 08-01 (60); the earlier 80 is higher but older
