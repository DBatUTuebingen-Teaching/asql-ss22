-- A SQL implementation of the K-Means clustering algorithm (bag semantics)
--
-- K-Means: https://en.wikipedia.org/wiki/K-means_clustering

-----------------------------------------------------------------------
-- visualization of the K-Means clustering progress

DROP FUNCTION round(point, decimal);
CREATE FUNCTION round(p point, f decimal) RETURNS point AS
$$
  SELECT point(round(p[0] :: decimal / f) * f,
               round(p[1] :: decimal / f) * f);
$$
LANGUAGE SQL IMMUTABLE;

\set width  7
\set height 5
\set resolution 0.5
-----------------------------------------------------------------------

-- # of K-Means iterations to perform in bag semantics
\set iterations 4

-- Set of points P that we will cluster
DROP TABLE IF EXISTS points;
CREATE TABLE points (
  point  int GENERATED ALWAYS AS IDENTITY ,   -- unique point ID/label
  loc    point                                -- location of point in 2D space
);

-- Instantiate P
INSERT INTO points(loc) VALUES
   (point(1.0, 1.0)),
   (point(2.0, 1.5)),
   (point(4.0, 3.0)),
   (point(7.0, 5.0)),
   (point(5.0, 3.5)),
   (point(5.0, 4.5)),
   (point(4.5, 3.5));

TABLE points;

-----------------------------------------------------------------------

-- K-Means using bag semantics (UNION ALL), ends computation after a
-- predetermined number of iterations (see :iterations).
--
WITH RECURSIVE
-- k_means(‹i›, ‹p›, ‹c›, ‹mean›):
--   in iteration ‹i›, point ID ‹p› has been assigned to cluster ID ‹c›,
--   the centroid of ‹c› is point ‹mean›
--   (i.e., there exists an FD ‹c› → ‹mean›).
k_means(iter, point, cluster, mean) AS (
-- From P, choose a sample of points (these will become the
-- initial cluster centers), assign unique cluster IDs
  SELECT 0 AS iter, p.point, ROW_NUMBER() OVER () AS cluster, p.loc AS mean
  FROM   points AS p
  --TABLESAMPLE BERNOULLI(30) -- choose ≈ 30% of points as initial cluster centers
  WHERE  p.point IN (5, 6)     -- choose points {5,6} as initial cluster centers (⇒ good example)
    UNION ALL
  -- 2. Update
  SELECT assign.iter + 1 AS iter, assign.point, assign.cluster,
         point(AVG(assign.loc[0]) OVER cluster,                                      -- ⎱ computes centroid
               AVG(assign.loc[1]) OVER cluster) AS mean                              -- ⎰ of assign.cluster
         -- 1. Assignment
  FROM   (SELECT DISTINCT ON (p.point) k.iter, p.point, k.cluster, p.loc             -- ⎫ for each point p ∊ P
          FROM   points AS p, k_means AS k                                           -- ⎬ find cluster center
          ORDER BY p.point, p.loc <-> k.mean) AS assign(iter, point, cluster, loc)   -- ⎭ that is closest to p
  WHERE  assign.iter < :iterations
  WINDOW cluster AS (PARTITION BY assign.cluster)
),
-----------------------------------------------------------------------
-- visualization of the K-Means clustering progress
--  - ⚫: points before assignment to any cluster
--  - ➊: point assigned to cluster 1
--  - ①: mean of cluster 1
symbols(iter, loc, sym) AS (
  SELECT 0 AS iter, round(p.loc, :resolution) AS loc, '⚫' AS sym
  FROM   points AS p
    UNION ALL
  SELECT k.iter, round(p.loc, :resolution) AS loc, chr(ascii('➊') - 1 + k.cluster :: int) AS sym
  FROM   k_means AS k, points AS p
  WHERE  k.point = p.point
  AND    k.iter > 0
    UNION ALL
  SELECT k.iter, round(k.mean, :resolution) AS loc, chr(ascii('①') - 1 + k.cluster :: int) AS sym
  FROM   k_means AS k
  ORDER BY iter, sym, loc
),
grid(iter, x, y, sym) AS (
  SELECT iter, x, y, '⋅' AS sym
  FROM   generate_series(0,:iterations) AS iter,
         generate_series(0,:width, :resolution) AS x,
         generate_series(0,:height,:resolution) AS y
  WHERE  (iter,x,y) NOT IN (SELECT s.iter, s.loc[0] AS x, s.loc[1] AS y
                            FROM   symbols AS s)
    UNION ALL
    -- if two symbols occupy the same iter/x/y spot, prefer ① over ⚫, ➊ (① < ⚫ < ➊)
  (SELECT DISTINCT ON (s.iter, s.loc[0], s.loc[1]) s.iter, s.loc[0] AS x, s.loc[1] AS y, s.sym
   FROM   symbols AS s
   ORDER BY s.iter, s.loc[0], s.loc[1], s.sym)
),
render(iter, y, points) AS (
  SELECT g.iter, g.y, string_agg(g.sym, NULL ORDER BY g.x) AS points
  FROM   grid AS g
  GROUP BY g.iter, g.y
  ORDER BY g.iter, g.y
)
-- TABLE k_means
-- ORDER BY iter, cluster;
SELECT iter, points
FROM   render
ORDER BY iter, y DESC;

-----------------------------------------------------------------------

-- Notes on SQL:
--
-- - The DISTINCT ON (...) may *not* be moved to the query top-level since
--   we depend on the ORDER BY which is syntactically forbidden inside
--   a UNION ALL.
--
-- - DISTINCT ON (p.point) ... ORDER BY p.point, p.loc <-> k.centroid:
--   - ORDER BY brings all (p,k) with the same point ID together; inside
--     such a point group, the (p,k) pair with minimum distance comes FIRST
--   - From this ordered group of pairs (p,k), DISTINCT ON (p.point) is
--     guaranteed to pick the FIRST and thus also finds the centroid that
--     is closest:
--
--          p₁ k₃ ⎫  ← DISTINCT ON will pick this (k₃ is closest to p₁)
--          p₁ k₄ ⎬  "group" for point p₁
--          p₁ k₂ ⎭
--          p₂ k₂ ⎫  ← DISTINCT ON will pick this (k₂ is closest to p₂)
--          p₂ k₃ ⎬  "group" for point p₂
--          p₂ k₄ ⎭
--
-- - DISTINCT ON (...) is helpful here since the recursive table k_means
--   may not appear in a nested subquery.  This is a non-solution to
--   compute the cluster assignment for point p:
--
--     SELECT ..., (SELECT k.cluster
--                  FROM   k_means k
--                  ORDER BY p.loc <-> k.centroid
--                  LIMIT 1) AS cluster
--     FROM   points p



