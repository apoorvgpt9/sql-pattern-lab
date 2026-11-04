-- Approach 1 (brute force): for each user, count their 2019 buyer orders with a correlated subquery.
-- Natural first attempt: it reads exactly like the requirement, one user at a time.
-- COUNT(*) over an empty subquery is 0, so users with no orders come out as 0 for free.
SELECT
  u.user_id   AS buyer_id,
  u.join_date,
  (SELECT COUNT(*)
     FROM Orders o
    WHERE o.buyer_id = u.user_id
      AND YEAR(o.order_date) = 2019) AS orders_in_2019
FROM Users u;
