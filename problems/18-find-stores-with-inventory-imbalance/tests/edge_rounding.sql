-- Rounding follows MySQL arithmetic: integer / integer is DECIMAL with 4 extra places (div_precision_increment=4),
-- and ROUND on an exact DECIMAL rounds half away from zero. 13/8 = 1.6250 -> 1.63; 201/200 = 1.0050 -> 1.01
-- (binary floating point would give 1.62 and 1.00). One store has an exact ratio.
INSERT INTO stores (store_id, store_name, location) VALUES
  (1, 'Half',  'X'),
  (2, 'Tiny',  'Y'),
  (3, 'Exact', 'Z');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1, 1, 'h1', 8,   90.00),
  (2, 1, 'h2', 1,   50.00),
  (3, 1, 'h3', 13,  10.00),
  (4, 2, 't1', 200, 90.00),
  (5, 2, 't2', 1,   50.00),
  (6, 2, 't3', 201, 10.00),
  (7, 3, 'e1', 4,   90.00),
  (8, 3, 'e2', 1,   50.00),
  (9, 3, 'e3', 10,  10.00);

-- expect: 3,Exact,Z,e1,e3,2.50 | 10/4 = 2.5000 -> 2.50
-- expect: 1,Half,X,h1,h3,1.63 | 13/8 = 1.6250; the half rounds away from zero to 1.63
-- expect: 2,Tiny,Y,t1,t3,1.01 | 201/200 = 1.0050; rounds to 1.01 (float math would say 1.00)
