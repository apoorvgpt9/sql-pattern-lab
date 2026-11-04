-- Dates in other years: the comparison is on the full date, not on month/day or year alone.
-- A zero price and a price equal to the default are legitimate values.
INSERT INTO Products (product_id, new_price, change_date) VALUES
  (1, 7, '2018-12-31'),
  (2, 8, '2019-01-01'),
  (2, 9, '2019-12-31'),
  (3, 1, '2020-01-01'),
  (4, 0, '2017-05-05'),
  (5, 10, '2018-01-01');

-- expect: 1,7 | a change in an earlier year is still the latest one on or before the date
-- expect: 2,8 | 2019-01-01 is in effect; the 2019-12-31 change is later in the year than 08-16
-- expect: 3,10 | the only change is in 2020: default
-- expect: 4,0 | price 0 is a real price, not "missing"
-- expect: 5,10 | explicit price 10 from an old change, same as the default but not defaulted
