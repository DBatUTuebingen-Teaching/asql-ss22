-- Visibility in hilly environment as observed from point p₀
-- (this variant computes visibility left AND right of p₀,
--  see ⁑*)

DROP TABLE IF EXISTS map;
CREATE TABLE map (
  x   integer NOT NULL PRIMARY KEY,  -- location
  alt integer NOT NULL               -- altidude at location
);

-- Observer p₀ (x)
\set p0 90

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

-- Quiz: Given table map, can you render the landscape as a text string
--       (like on the slides)?

WITH
-- ➊ Location (x and altitude) of observer p₀
p0(x, alt) AS (
  SELECT :p0 AS x, m.alt
  FROM   map AS m
  WHERE  m.x = :p0
),
-- ➋ Angles from view point of p₀ (facing left and right)
angles(x, angle) AS (
  SELECT m.x,
         degrees(atan((m.alt - p0.alt) / abs(p0.x - m.x))) AS angle
  FROM   map AS m, p0
  WHERE  m.x <> p0.x
),
-- ➌ Max angle scan from p₀
max_scan(x, max_angle) AS (
  SELECT a.x,
         MAX(a.angle) OVER (PARTITION BY sign(p0.x - a.x) ORDER BY abs(p0.x - a.x)) AS max_angle
--                          ──────────────────────────
--                  ⁑* handle left and right of p₀ separately
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
