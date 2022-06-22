-- Visibility in hilly environment as observed from point p₀
-- (this variant computes visibility right of p₀ only, see
--  visible-left-right.sql for a left+right facing version)

DROP TABLE IF EXISTS map;
CREATE TABLE map (
  x   integer NOT NULL PRIMARY KEY,  -- location
  alt integer NOT NULL               -- altidude at location
);

-- Observer p₀ (x)
\set p0 0

INSERT INTO map(x, alt) VALUES
  (  0, 200),
  ( 10, 200),
  ( 20, 200),
  ( 30, 300),
  ( 40, 400),
  ( 50, 400),
  ( 60, 400),
  ( 70, 200),
  ( 80, 400),
  ( 90, 700),
  (100, 800),
  (110, 700),
  (120, 500);


-----------------------------------------------------------------------
-- Interlude (optional):
-- render a textual version of altitude profile the above map
-- (based on code provided by student Tim Fischer)

-- horizontal/vertical scaling of the rendering
\set H 1
\set V 1

WITH
peak(alt) AS (
  SELECT MAX(alt)
  FROM   map
),
blocks(x, alt, c) AS (
  SELECT m.x, altitude AS alt,
         CASE WHEN altitude <= m.alt THEN '█' ELSE ' ' END AS c
  FROM   peak, generate_series(peak.alt, 0, -100 / :V) AS altitude, map AS m
)
SELECT   b.alt AS alt,
         array_to_string(array_agg(repeat(b.c, :H) ORDER BY b.x), '') AS profile
FROM     blocks AS b
GROUP BY b.alt
ORDER BY b.alt DESC;

-----------------------------------------------------------------------


WITH
-- ➊ Location (x and altitude) of observer p₀
p0(x, alt) AS (
  SELECT :p0 AS x, m.alt
  FROM   map AS m
  WHERE  m.x = :p0
),
-- ➋ Angles from view point of p₀ (facing right)
angles(x, angle) AS (
  SELECT m.x,
         degrees(atan((m.alt - p0.alt) / abs(p0.x - m.x))) AS angle
  FROM   map AS m, p0
  WHERE  m.x > p0.x
),
-- ➌ Max angle scan from p₀
max_scan(x, max_angle) AS (
  SELECT a.x,
         MAX(a.angle) OVER (ORDER BY abs(p0.x - a.x)) AS max_angle
  FROM   angles AS a, p0
),
-- ➍ Visibility from p₀
visibility(x, "visible?") AS (
  SELECT m.x, a.angle >= m.max_angle AS "visible?"
  FROM   angles AS a, max_scan AS m
  WHERE  a.x = m.x
)
TABLE visibility
ORDER BY x;

