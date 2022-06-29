-- Temporarily disable hash-based aggregation to force the use of
-- B-tree scans (to render queries ➊ and ➋ comparable).
-- (NB: even with enable_hashagg = ON, the loose index scan wins by far.)
SET enable_hashagg = off;


-- Input table with column containing duplicate values
--
DROP TABLE IF EXISTS t CASCADE;
CREATE TABLE t (
  key int GENERATED ALWAYS AS IDENTITY,
  dup int NOT NULL      -- column dup expected to feature duplicate values
);

-- Populate input table
--
\set table_size    1000000  -- size of input table
\set distinct_vals 1000     -- # of distinct values in column dup

TRUNCATE t;
INSERT INTO t(dup)
  SELECT i % :distinct_vals AS dup
  FROM   generate_series(1, :table_size) AS i;

-- Build a B-tree on the dup column
CREATE INDEX t_dup ON t USING btree (dup);
ANALYZE;


-- ➊ Regular DISTINCT operation on duplicate column
--   (uses index-only scan on B-tree t_dup)
EXPLAIN ANALYZE
SELECT DISTINCT t.dup
FROM t;

-- ➋ Simulate a loose index scan on duplicate column
--
EXPLAIN ANALYZE
WITH RECURSIVE
loose(xᵢ) AS (
  SELECT MIN(t.dup) AS xᵢ                 -- Find first value in loose index scan
  FROM   t                                 -- (fetches one row using B-tree t_dup)
    UNION ALL  -- ⚠ bag semantics: dup values increase monotonically (until dup ≡ NULL)
  SELECT (SELECT MIN(t.dup)                -- Fetch next larger value, subquery yields
          FROM   t                         -- NULL if there is no further larger value
          WHERE  t.dup > l.xᵢ) AS dup      -- (fetches one row using B-tree t_dup)
  FROM   loose AS l
  WHERE  l.xᵢ IS NOT NULL                  -- NULL indicates no further value in scan
)
SELECT l.xᵢ
FROM   loose AS l
WHERE  l.xᵢ IS NOT NULL;




SET enable_hashagg = on;
