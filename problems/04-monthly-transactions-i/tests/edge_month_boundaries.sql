-- First and last day of months, a year boundary, the same calendar month in two different years (Jan 2019 and
-- Jan 2020 are different groups), and a leap day.
INSERT INTO Transactions (id, country, state, amount, trans_date) VALUES
  (1, 'US', 'approved',  1, '2019-01-31'),
  (2, 'US', 'declined',  2, '2019-02-01'),
  (3, 'US', 'approved',  4, '2019-12-31'),
  (4, 'US', 'declined',  8, '2020-01-01'),
  (5, 'US', 'approved', 16, '2020-01-31'),
  (6, 'US', 'approved', 32, '2019-01-01'),
  (7, 'US', 'approved', 64, '2020-02-29');

-- expect: 2019-01,US,2,2,33,33 | ids 1 (Jan 31) and 6 (Jan 1) are both in Jan 2019: 1+32
-- expect: 2019-02,US,1,0,2,0 | id 2 on Feb 1 belongs to Feb, not Jan; declined
-- expect: 2019-12,US,1,1,4,4 | id 3 on Dec 31 stays in Dec 2019
-- expect: 2020-01,US,2,1,24,16 | ids 4 (Jan 1) and 5 (Jan 31): Jan 2020 is NOT merged with Jan 2019; 8+16 = 24, 16 approved
-- expect: 2020-02,US,1,1,64,64 | id 7 is a leap day, still February
