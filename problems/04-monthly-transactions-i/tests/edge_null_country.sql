-- NULL country: rows with it form their own group per month (GROUP BY treats NULLs as equal), and they
-- must still be counted. Two NULL rows in the same month are one group; a NULL row in another month is another.
INSERT INTO Transactions (id, country, state, amount, trans_date) VALUES
  (1, NULL, 'approved', 10, '2021-05-01'),
  (2, NULL, 'declined', 20, '2021-05-15'),
  (3, NULL, 'approved',  5, '2021-06-01'),
  (4, 'US', 'approved',  7, '2021-05-02');

-- expect: 2021-05,NULL,2,1,30,10 | ids 1,2 form one NULL-country group: 2 transactions, 1 approved, 10+20 = 30, 10 approved
-- expect: 2021-06,NULL,1,1,5,5 | id 3: NULL country in a different month is a different group
-- expect: 2021-05,US,1,1,7,7 | id 4: a real country is not merged with the NULL group
