-- Use window function ROW_NUMBER() to identify consecutive ranges
-- of values.
--
-- Use case: convert citation "... as shown in [5,2,14,3,1,42,6,10,7,13] ..."
--           into             "... as shown in [1-3,5-7,10,13&14,42] ..."


DROP TABLE IF EXISTS citations;
CREATE TABLE citations(ref int PRIMARY KEY);

INSERT INTO citations VALUES
  (5), (2), (14), (3), (1), (42), (6), (10), (7), (13);

TABLE citations;

-- CTE `ranges' effectively computes
-- ┌─────┐
-- │ ref │
-- ├─────┤
-- │   1 │ -  1 =  0      ⎫
-- │   2 │ -  2 =  0      ⎬  range 0
-- │   3 │ -  3 =  0 ____ ⎭
-- │   5 │ -  4 =  1      ⎫
-- │   6 │ -  5 =  1      ⎬  range 1
-- │   7 │ -  6 =  1 ____ ⎭
-- │  10 │ -  7 =  3 ____ }  range 3
-- │  13 │ -  8 =  5      ⎱  range 5
-- │  14 │ -  9 =  5 ____ ⎰
-- │  42 │ - 10 = 32      }  range 32
-- └─────┘

WITH ranges(ref, range) AS (
  SELECT c.ref,
         c.ref - ROW_NUMBER() OVER (ORDER BY c.ref) AS range
    FROM citations AS c
),
output(range, first, last) AS (
  SELECT r.range, MIN(r.ref) AS first, MAX(r.ref) AS last
  FROM   ranges AS r
  GROUP BY r.range
)
SELECT string_agg(CASE o.last - o.first
                    WHEN 0 THEN o.first :: text
                    WHEN 1 THEN o.first || '&' || o.last
                    ELSE        o.first || '-' || o.last
                  END,
                  ','
                  ORDER BY o.range) AS citations
FROM   output AS o;
-- TABLE ranges
-- ORDER BY range;
-- TABLE output
-- ORDER BY range;
