-- Nine consecutive days; several days have two customers, so a day's total is a sum of rows.
-- Daily totals: d1=100, d2=100, d3=120, d4=100, d5=80, d6=100, d7=100, d8=120, d9=150.
INSERT INTO Customer (customer_id, name, visited_on, amount) VALUES
  (1, 'Ann',  '2024-03-01', 100),
  (1, 'Ann',  '2024-03-02',  50), (2, 'Bob',  '2024-03-02',  50),
  (3, 'Cy',   '2024-03-03', 120),
  (2, 'Bob',  '2024-03-04',  30), (3, 'Cy',   '2024-03-04',  70),
  (4, 'Dee',  '2024-03-05',  80),
  (1, 'Ann',  '2024-03-06',  60), (5, 'Eli',  '2024-03-06',  40),
  (2, 'Bob',  '2024-03-07', 100),
  (3, 'Cy',   '2024-03-08',  90), (4, 'Dee',  '2024-03-08',  30),
  (5, 'Eli',  '2024-03-09', 150);

-- expect: 2024-03-07,700,100.00 | 7th day: days 1-7 = 100+100+120+100+80+100+100 = 700; 700/7 = 100.00
-- expect: 2024-03-08,720,102.86 | days 2-8 = 700 - 100 + 120 = 720; 720/7 = 102.8571 (MySQL keeps 4 decimals) -> ROUND 102.86
-- expect: 2024-03-09,770,110.00 | days 3-9 = 720 - 100 + 150 = 770; 770/7 = 110.0000 -> 110.00
-- (Days 1-6 produce no row: fewer than 6 earlier days are available.)
