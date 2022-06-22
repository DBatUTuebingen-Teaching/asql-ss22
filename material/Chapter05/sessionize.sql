-- Sessionization of the Police HQ computer usage log


DROP TABLE IF EXISTS log;
CREATE TABLE log(uid text NOT NULL,
                 ts  timestamp NOT NULL);

-- ➊ Police HQ computer log data
--
INSERT INTO log(uid, ts) VALUES
  ('Cop', '05-25-2020 07:25:12'),  -- assumes datestyle = 'ISO, MDY'
  ('Cop', '05-25-2020 07:25:18'),
  ('Cop', '05-25-2020 07:25:21'),
  ('Spy', '05-25-2020 08:01:55'),
  ('Spy', '05-25-2020 08:05:07'),
  ('Spy', '05-25-2020 08:05:30'),
  ('Spy', '05-25-2020 08:05:53'),
  ('Spy', '05-25-2020 08:06:19'), -- ⎱ sessions by Spy and Cop within
  ('Cop', '05-25-2020 08:06:30'), -- ⎰ 30 seconds, still *two* sessions ⇒ partition by uid ⁑
  ('Cop', '05-25-2020 08:06:42'),
  ('Cop', '05-25-2020 18:32:07'),
  ('Cop', '05-25-2020 18:32:27'),
  ('Cop', '05-25-2020 18:32:44'),
  ('Cop', '05-25-2020 18:33:00'),
  ('Spy', '05-25-2020 22:20:06'),
  ('Spy', '05-25-2020 22:20:16');

-- After this time of inactivity, a session is considered complete
\set inactivity '30 seconds'

WITH
-- ➋ + ➌ Assign start of session tags (1: new session begins, 0: session continues)
tagged(uid, ts, sos) AS (
  SELECT l.*,
         CASE WHEN l.ts >                               -- ⁑
                   LAG (l.ts, 1, '-infinity') OVER (PARTITION BY l.uid ORDER BY l.ts) + :'inactivity'
              THEN 1 --       ↑         ↑
              ELSE 0 -- previous row   used as "zeroth" timestamp when accessing first row in l.ts order
          END AS sos
  FROM   log AS l
  ORDER BY l.uid, l.ts  -- ← for presentation purposes only
),
-- ➍ Perform a running sum over the start of session tag to assign session IDs
sessionized(uid, ts, sos, session) AS (
  SELECT t.*,
         SUM (t.sos) OVER (PARTITION BY t.uid ORDER BY t.ts) AS session
      --  ↑
      --  |
      -- start of group contributes 1, continuation of group contributes 0
  FROM   tagged AS t
  ORDER BY t,uid, t.ts  -- ← for presentation purposes only
),
-- Measure the length of each session
measured(uid, session, duration) AS (
  SELECT s.uid,
         s.session,
         MAX(s.ts) - MIN(s.ts) AS duration
  FROM   sessionized AS s
  GROUP BY s.uid, s.session
  ORDER BY s.uid, s.session  -- ← for presentation purposes only
)
TABLE measured;

-- What is the average length of a session?
-- SELECT AVG(m.duration)
-- FROM   measured AS m;


-- How to assign *global session IDs*?
--
-- A single-line change in `sessionized' is needed:

-- WITH
-- ⋮
-- -- ➍ Perform a running sum over the start of session tag to assign session IDs
-- sessionized(uid, ts, sos, session) AS (
--   SELECT t.*,
--          SUM (t.sos) OVER (ORDER BY t.uid, t.ts) AS session
--       --                      ↑
--       -- change: omit PARTITION BY t.uid, but use ORDER BY t.uid, t.ts
--   FROM   tagged AS t
--   ORDER BY t,uid, t.ts  -- ← for presentation purposes only
-- ),
-- ⋮

