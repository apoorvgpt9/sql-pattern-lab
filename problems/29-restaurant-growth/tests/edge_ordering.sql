-- Tests the output order (visited_on ascending). Eight days, inserted in scrambled order, one customer per day.
-- Daily totals by date: 10, 20, 30, 40, 50, 60, 70, 80.
INSERT INTO Customer (customer_id, name, visited_on, amount) VALUES
  (5, 'Eli',  '2024-05-05', 50),
  (1, 'Ann',  '2024-05-01', 10),
  (8, 'Hal',  '2024-05-08', 80),
  (3, 'Cy',   '2024-05-03', 30),
  (7, 'Gus',  '2024-05-07', 70),
  (2, 'Bob',  '2024-05-02', 20),
  (6, 'Fay',  '2024-05-06', 60),
  (4, 'Dee',  '2024-05-04', 40);

-- expect: 2024-05-07,280,40.00 | days 1-7 = 10+20+30+40+50+60+70 = 280; 280/7 = 40.00; earlier date, so first
-- expect: 2024-05-08,350,50.00 | days 2-8 = 20+30+40+50+60+70+80 = 350; 350/7 = 50.00; later date, so second
