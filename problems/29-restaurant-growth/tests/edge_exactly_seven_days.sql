-- Exactly seven days: the 7th day is the first (and only) day with six earlier days. Two days have two customers.
-- Daily totals: 10, 20, 30, 40, 50, 60, 70.
INSERT INTO Customer (customer_id, name, visited_on, amount) VALUES
  (1, 'Ann', '2024-01-01', 10),
  (1, 'Ann', '2024-01-02', 5),  (2, 'Bob', '2024-01-02', 15),
  (3, 'Cy',  '2024-01-03', 30),
  (2, 'Bob', '2024-01-04', 40),
  (4, 'Dee', '2024-01-05', 20), (5, 'Eli', '2024-01-05', 30),
  (1, 'Ann', '2024-01-06', 60),
  (3, 'Cy',  '2024-01-07', 70);

-- expect: 2024-01-07,280,40.00 | days 1-7 = 10+20+30+40+50+60+70 = 280; 280/7 = 40.00. Days 1-6 have no full window
