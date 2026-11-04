-- Changes on the day before, the day itself, and the day after 2019-08-16.
INSERT INTO Products (product_id, new_price, change_date) VALUES
  (10, 11, '2019-08-15'),
  (10, 22, '2019-08-16'),
  (10, 33, '2019-08-17'),
  (11, 44, '2019-08-16'),
  (12, 55, '2019-08-17'),
  (13, 66, '2019-08-15');

-- expect: 10,22 | a change dated exactly 2019-08-16 is in effect on that date; 08-15 is older, 08-17 later
-- expect: 11,44 | its only change is on the date itself: in effect, not the default
-- expect: 12,10 | only change is the day AFTER: default
-- expect: 13,66 | only change is the day before: in effect
