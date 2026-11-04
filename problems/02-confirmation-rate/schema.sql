-- Confirmation Rate: tables for MySQL 8.0. Names mirror the original.
-- No foreign key from Confirmations to Signups (the original declares one): it lets the edge
-- datasets contain a confirmation for a user who never signed up, which the output must ignore.

CREATE TABLE Signups (
  user_id    INT PRIMARY KEY,                -- grain: one row per user
  time_stamp DATETIME NOT NULL
);

CREATE TABLE Confirmations (
  user_id    INT NOT NULL,                   -- grain: one row per confirmation request
  time_stamp DATETIME NOT NULL,
  action     ENUM('confirmed','timeout') NOT NULL,
  PRIMARY KEY (user_id, time_stamp)
);
