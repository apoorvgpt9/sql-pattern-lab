-- Monthly Transactions I: tables for MySQL 8.0. Names mirror the original.
-- country is the only nullable column: the spec says a NULL country forms its own group.
-- state, amount and trans_date are NOT NULL (assumption, see README), so every row belongs to a real month.

CREATE TABLE Transactions (
  id         INT PRIMARY KEY,                     -- grain: one row per transaction
  country    VARCHAR(10),
  state      ENUM('approved','declined') NOT NULL,
  amount     INT NOT NULL,
  trans_date DATE NOT NULL
);
