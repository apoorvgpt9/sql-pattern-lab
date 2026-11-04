-- Only six days of data: no day has six earlier days, so there is no output at all.
INSERT INTO Customer (customer_id, name, visited_on, amount) VALUES
  (1, 'Ann', '2024-01-01', 10),
  (2, 'Bob', '2024-01-02', 20),
  (1, 'Ann', '2024-01-03', 30),
  (3, 'Cy',  '2024-01-04', 40),
  (2, 'Bob', '2024-01-05', 50),
  (4, 'Dee', '2024-01-06', 60);

-- expect-empty: six distinct days < 7, so no day has six earlier days available
