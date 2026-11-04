-- Trips and Users: tables for MySQL 8.0. Names mirror the original.
-- request_at is a 'YYYY-MM-DD' string, as in the original. No foreign keys are declared (the original documents
-- them): that lets edge_orphan_users contain a trip whose client or driver is not in Users.

CREATE TABLE Users (
  users_id INT PRIMARY KEY,                           -- grain: one row per user
  banned   ENUM('Yes','No') NOT NULL,
  role     ENUM('client','driver','partner') NOT NULL
);

CREATE TABLE Trips (
  id        INT PRIMARY KEY,                          -- grain: one row per trip request
  client_id INT NOT NULL,                             -- references Users.users_id
  driver_id INT NOT NULL,                             -- references Users.users_id
  city_id   INT NOT NULL,
  status    ENUM('completed','cancelled_by_driver','cancelled_by_client') NOT NULL,
  request_at VARCHAR(10) NOT NULL                     -- 'YYYY-MM-DD'
);
