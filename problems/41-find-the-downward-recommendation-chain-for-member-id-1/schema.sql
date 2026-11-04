-- Find the downward recommendation chain for member ID 1 (pgexercises recursive/getdownward):
-- tables for MySQL 8.0. Names mirror the original; the cd. schema prefix is dropped because the
-- harness owns the database. Nullability follows the original: only recommendedby may be NULL.
-- The original's self-referencing foreign key is omitted, so test data can be inserted in any order.

CREATE TABLE members (
  memid         INT          NOT NULL,
  surname       VARCHAR(200) NOT NULL,
  firstname     VARCHAR(200) NOT NULL,
  address       VARCHAR(300) NOT NULL,
  zipcode       INT          NOT NULL,
  telephone     VARCHAR(20)  NOT NULL,
  recommendedby INT,                    -- the member who recommended this one; NULL = top of a chain
  joindate      DATETIME     NOT NULL,  -- timestamp in the original
  PRIMARY KEY (memid)                   -- grain: one row per member; memid 0 is the shared GUEST account
);
