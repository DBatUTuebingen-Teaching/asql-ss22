-- Auxiliary: Convert array xs to string (abbreviates long arrays)
--
DROP FUNCTION IF EXISTS show(anyarray);
CREATE FUNCTION show(xs anyarray) RETURNS text AS
$$
  SELECT CASE WHEN c < 10
              THEN xs :: text
              ELSE (xs[1:2] :: text[] || array['…'] || xs[c-1:c] :: text[]) :: text || ' (' || c || ' elements)'
         END
  FROM   (VALUES (cardinality(xs))) AS _(c)
$$
LANGUAGE SQL IMMUTABLE;

-----------------------------------------------------------------------

-- ➊ Generate the sequence of integers i ∊ {1,2,...,10}
-- (UNION variant):
--
WITH RECURSIVE
  series(i) AS (
    VALUES (1)
      UNION
    SELECT s.i + 1 AS i
    FROM   series AS s
    WHERE  s.i < 10
)
TABLE series;


-- ➊ Generate the sequence of integers i ∊ {1,2,...,10}
-- (UNION variant, tracing the recursive table):
--
WITH RECURSIVE
  series(i, "table 𝘀𝗲𝗿𝗶𝗲𝘀 after this iteration") AS (
    VALUES (1, show(array[1]))
      UNION
    SELECT s.i + 1 AS i, show(array_agg(s.i + 1) OVER ())
    FROM   series AS s
    WHERE  s.i < 10
)
TABLE series;


-- ➊a Function that re-implements the generate_series(‹from›,‹to›) built-in:
--
DROP FUNCTION IF EXISTS my_generate_series(int, int);
CREATE FUNCTION my_generate_series("from" int, "to" int) RETURNS TABLE(i int) AS
$$
  WITH RECURSIVE
    series(i) AS (
      VALUES ("from")
        UNION
      SELECT s.i + 1 AS i
      FROM   series AS s
      WHERE  s.i < "to"
  )
  TABLE series;
$$
LANGUAGE SQL IMMUTABLE;

-- Now use our own variant of generate_series()
SELECT i
FROM   my_generate_series(1135,1141) AS i;


-- ➋ In the UNION variant, only previously undiscovered rows are added
--   to the final result and fed into the next iteration:
--
WITH RECURSIVE
  series(i) AS (
    VALUES (1)
      UNION
    SELECT s.i + δ AS i -- generates one known + one new row (only the new row is kept)
    FROM   series AS s, (VALUES (0), (1)) AS _(δ)
    WHERE  s.i < 10
)
TABLE series;


-- ➋a In the UNION variant, only previously undiscovered rows are added
--    to the final result and fed into the next iteration:
--
WITH RECURSIVE
  series(i) AS (
    VALUES (1)
      UNION
    SELECT s.i + 1 AS i -- generates the same new row twice (only one copy is kept)
    FROM   series AS s, (VALUES (0), (1)) AS _
    WHERE  s.i < 10
)
TABLE series;


-----------------------------------------------------------------------


-- ➌ UNION ALL variant: *all* rows generated in the iteration are added to
--   the result and fed into the next iteration:
--
WITH RECURSIVE
  series(i) AS (
    VALUES (1)
      UNION ALL -- ⚠ bag semantics
    SELECT s.i + 1 AS i -- generates two rows for any input row (*both* rows are kept)
    FROM   series AS s, (VALUES (0), (1)) AS _
    WHERE  s.i < 5
)
TABLE series;



-- ➌ UNION ALL variant: *all* rows generated in the iteration are added to
--   the result and fed into the next iteration (tracing the recursive table):
--
WITH RECURSIVE
  series(i, "table 𝘀𝗲𝗿𝗶𝗲𝘀 after this iteration") AS (
    VALUES (1, show(array[1]))
      UNION ALL -- ⚠ bag semantics
    SELECT s.i + 1 AS i, show(array_agg(s.i + 1) OVER ())
    FROM   series AS s, (VALUES (0), (1)) AS _
    WHERE  s.i < 5
)
TABLE series;



-- ➍ Quiz: What will happen (and why?) with this UNION ALL variant of query ➋?
--
WITH RECURSIVE
  series(i) AS (
    VALUES (1)
      UNION ALL -- ⚠ bag semantics
    SELECT s.i + δ AS i -- generates one known + one new row for any input row (*both* rows are kept)
    FROM   series AS s, (VALUES (0), (1)) AS _(δ)
    WHERE  s.i < 10
)
TABLE series;
