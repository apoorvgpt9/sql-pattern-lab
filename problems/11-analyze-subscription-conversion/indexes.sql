-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The table's clustered key is (user_id, activity_date, activity_type), which groups a user's rows but interleaves
-- the types by date. (user_id, activity_type, activity_duration) is covering for every query here and keeps
-- each user's trial rows together and paid rows together: approach 1's subqueries become two short index
-- ranges per user, and approaches 2 and 3 can aggregate in index order without a temporary table.
CREATE INDEX idx_ua_user_type_dur ON UserActivity (user_id, activity_type, activity_duration);
