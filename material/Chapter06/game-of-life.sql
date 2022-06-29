-- Conway's Game of Life

-- N: # of Game of Life iterations
-- (comment this if you use ./conway.sh to animate the Game of Life grid)
-- \set N 3

\set QUIET on
\pset border 0
\pset footer off
\pset tuples_only on
\timing off

-- Character-based representation of initial world
-- (⋅ ≡ empty, any other character ≡ cell)
DROP TABLE IF EXISTS world;
CREATE TABLE world (
  pos int GENERATED ALWAYS AS IDENTITY,
  row text);

\COPY world(row) FROM stdin
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●●⋅⋅⋅⋅⋅⋅
⋅⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅●●●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅●⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅⋅●⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●●●⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
\.


-- Kok's Galaxy (http://www.conwaylife.com/w/index.php?title=Kok%27s_galaxy)
-- \COPY world(row) FROM stdin
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅⋅●⋅⋅●⋅●⋅⋅⋅
-- ⋅⋅●●⋅●⋅●●●⋅⋅⋅
-- ⋅⋅⋅●⋅⋅⋅⋅⋅⋅●⋅⋅
-- ⋅⋅●●⋅⋅⋅⋅⋅●⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅●⋅⋅⋅⋅⋅●●⋅⋅
-- ⋅⋅●⋅⋅⋅⋅⋅⋅●⋅⋅⋅
-- ⋅⋅⋅●●●⋅●⋅●●⋅⋅
-- ⋅⋅⋅●⋅●⋅⋅●⋅⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- \.


-- Snacker (p.55, Figure 3.6 in "Conway's Game of Life — Mathematics and Construction")
-- \COPY world(row) FROM stdin
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅●●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●⋅
-- ⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅
-- ⋅⋅●⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅●⋅⋅
-- ⋅⋅⋅●●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅●●⋅●●●●⋅●●⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅
-- ⋅⋅⋅●●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●⋅⋅⋅
-- ⋅⋅●⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅●⋅⋅
-- ⋅⋅●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●⋅⋅
-- ⋅●●⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅●●⋅
-- ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅
-- \.

-- TABLE world
-- ORDER BY pos;

-- Cell neighborhood:
--
--    0 1 2 x
--  0 ●         x-y is constant on the \ diagonals (⇒ PARTITION BY)
--  1   ●       x+y grows from upper left to lower right (⇒ ORDER BY)
--  2     ●
--  y

--    0 1 2 x
--  0     ●     x+y is constant on the / diagonals (⇒ PARTITION BY)
--  1   ●       x-y grows from upper right to lower left (⇒ ORDER BY)
--  2 ●
--  y

--    0 1 2 x
--  0           y is constant on the - horizontals (⇒ PARTITION BY)
--  1 ● ● ●     x grows from left to right (⇒ ORDER BY)
--  2
--  y

--    0 1 2 x
--  0   ●        x is constant on the | verticals (⇒ PARTITION BY)
--  1   ●        y grows top down (⇒ ORDER BY)
--  2   ●
--  y

WITH RECURSIVE
life(gen, x, y, cell) AS (
  -- Parse initial generation from character-based representation
  -- into (x, y, 0/1) grid form
  SELECT 0 AS gen,
         col.pos AS x, row.pos AS y,
         CASE WHEN col.x = '⋅' THEN 0 ELSE 1 END AS cell
  FROM   world AS row,
         LATERAL string_to_table(row.row, NULL) WITH ORDINALITY AS col(x, pos)
    UNION ALL
  -- Derive next generation based on Conway's Game of Life rules
  SELECT l.gen + 1 AS gen,
         l.x, l.y,
         CASE (l.cell, (  SUM(l.cell) OVER horizontal
                        + SUM(l.cell) OVER vertical
                        + SUM(l.cell) OVER diagonal1
                        + SUM(l.cell) OVER diagonal2
                       ) :: int
              )
           --   (c, p): c ≡ state of cell, p ≡ # of live neighbors
           WHEN (1, 2) THEN 1 -- c lives on
           WHEN (1, 3) THEN 1 -- c lives on
           WHEN (0, 3) THEN 1 -- reproduction
           ELSE             0 -- under/overpopulation
         END AS cell
  FROM   life AS l
  WHERE  l.gen < :N
  WINDOW horizontal AS (PARTITION BY l.y     ORDER BY l.x     ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING EXCLUDE CURRENT ROW),  -- horizontal ⋯
         vertical   AS (PARTITION BY l.x     ORDER BY l.y     ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING EXCLUDE CURRENT ROW),  -- vertical   ⋮
         diagonal1  AS (PARTITION BY l.x+l.y ORDER BY l.x-l.y ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING EXCLUDE CURRENT ROW),  -- diagonal   ⋰
         diagonal2  AS (PARTITION BY l.x-l.y ORDER BY l.x+l.y ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING EXCLUDE CURRENT ROW)   -- diagonal   ⋱
)
-- Output Nᵗʰ generation
SELECT string_agg(CASE WHEN l.cell = 1 THEN '●' ELSE '⋅' END, NULL ORDER BY l.x) AS "Life"
FROM   life AS l
WHERE  l.gen = :N
GROUP BY l.y
ORDER BY l.y;
