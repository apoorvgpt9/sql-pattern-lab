-- Two countries over a year change. Includes an approved transaction with amount 0 (counted, adds nothing)
-- and a (month, country) group whose only transaction is declined.
INSERT INTO Transactions (id, country, state, amount, trans_date) VALUES
  (1, 'US', 'approved', 100, '2018-12-18'),
  (2, 'US', 'declined',  50, '2018-12-19'),
  (3, 'US', 'approved', 200, '2019-01-03'),
  (4, 'DE', 'approved',   0, '2018-12-20'),
  (5, 'DE', 'approved',  30, '2018-12-31'),
  (6, 'DE', 'declined',  70, '2019-01-01'),
  (7, 'US', 'declined',  10, '2018-12-25');

-- expect: 2018-12,US,3,1,160,100 | ids 1,2,7: 3 transactions; only id 1 approved; 100+50+10 = 160 total; 100 approved
-- expect: 2019-01,US,1,1,200,200 | id 3 alone
-- expect: 2018-12,DE,2,2,30,30 | ids 4,5 both approved; id 4 counts as approved with amount 0, so the count is 2 but the amount is 30
-- expect: 2019-01,DE,1,0,70,0 | id 6 alone and declined: the approved columns are 0, not NULL, and the group must still appear
