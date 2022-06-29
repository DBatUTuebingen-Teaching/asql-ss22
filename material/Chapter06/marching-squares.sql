-- Marching Squares to trace an isoline (contour line) on a height map
--
-- See https://de.wikipedia.org/wiki/Marching_Squares
-- and https://en.wikipedia.org/wiki/Marching_squares


DROP TABLE IF EXISTS input;
CREATE TEMPORARY TABLE input (
  y   int  GENERATED ALWAYS AS IDENTITY,
  alt text NOT NULL
);


\COPY input(alt) FROM stdin
░░░░░░░░░
░░░░░░░░░
░░░░░▓░░░
░░░░▓▓▓▓░
░░▓▓▓▓▓▓░
░░░▓▓▓▓░░
░░░░░░░░░
\.

TABLE input;


-- The 2D pixel map
--
DROP TABLE IF EXISTS map;
CREATE TABLE map (
  x   int NOT NULL,
  y   int NOT NULL,
  alt int NOT NULL,
  PRIMARY KEY (x,y)
);

-- Populate map from sample input (lower-left is at (0,0)),
-- altitudes: ░ ≡ 100m,  ▓ ≡ 200m
--
INSERT INTO map(x, y, alt)
  SELECT col.x - 1 AS x, (SELECT COUNT(*) FROM input) - row.y AS y,
         100 * array_position(array['░','▓'], col.alt) AS alt
  FROM   input AS row,
         LATERAL string_to_table(row.alt, NULL) WITH ORDINALITY AS col(alt, x);

TABLE map;

-----------------------------------------------------------------------
-- Marching Squares


-- Possible movement (Δx, Δy) of the 2x2 pixel mask
--
DROP TYPE IF EXISTS direction CASCADE;
CREATE TYPE direction AS (
  Δx int,
  Δy int
);

-- (1) Encode the 15 (+ 1) cases that the 2x2 pixel mask may encounter
--
DROP TABLE IF EXISTS directions;
CREATE TABLE directions (
  ll  bool,      -- pixel in lower-left corner set?
  lr  bool,
  ul  bool,
  ur  bool,
  dir direction, -- movement
  PRIMARY KEY (ll, lr, ul, ur));

INSERT INTO directions VALUES
  (false,false,false,false, ( 1, 0)), -- ⎹ ⎸ ︎: →
  (false,false,false,true , ( 1, 0)), -- ⎹▝⎸ : →
  (false,false,true ,false, ( 0, 1)), -- ⎹▘⎸ : ↑
  (false,false,true ,true , ( 1, 0)), -- ⎹▀⎸ : →
  (false,true ,false,false, ( 0,-1)), -- ⎹▗⎸ : ↓
  (false,true ,false,true , ( 0,-1)), -- ⎹▐⎸ : ↓
  (false,true ,true ,false, ( 0, 1)), -- ⎹▚⎸ : ↑
  (false,true ,true ,true , ( 0,-1)), -- ⎹▜⎸ : ↓
  (true ,false,false,false, (-1, 0)), -- ⎹▖⎸ : ←
  (true ,false,false,true , (-1, 0)), -- ⎹▞⎸ : ←
  (true ,false,true ,false, ( 0, 1)), -- ⎹▌⎸ : ↑
  (true ,false,true ,true , ( 1, 0)), -- ⎹▛⎸ : →
  (true ,true ,false,false, (-1, 0)), -- ⎹▄⎸ : ←
  (true ,true ,false,true , (-1, 0)), -- ⎹▟⎸ : ←
  (true ,true ,true ,false, ( 0, 1)), -- ⎹▛⎸ : →
  (true ,true ,true ,true , NULL   ); -- ⎹█⎸ : x

TABLE directions;


-- Iso value of interest (here: 200m, object ≡ ▓ pixels)
\set iso 200

WITH RECURSIVE
-- Threshold height map based on given iso value
pixels(x,y,alt) AS (
  SELECT x, y, alt >= :iso AS alt
  FROM   map
),
-- (2) Establish 2×2 squares on the pixel-fied map,
--     (x,y) designates lower-left corner: ul  ur
--                                           ⬜︎
--                                         ll  lr
squares(x,y,ll,lr,ul,ur) AS (
  SELECT p0.x, p0.y,
         p0.alt AS ll, p1.alt AS lr, p2.alt AS ul, p3.alt AS ur
  FROM   pixels p0, pixels p1, pixels p2, pixels p3
  WHERE  (p1.x,p1.y) = (p0.x+1,p0.y)
  AND    (p2.x,p2.y) = (p0.x  ,p0.y+1)
  AND    (p3.x,p3.y) = (p0.x+1,p0.y+1)
),
-- (3) Perform the march, starting at point (1,1)
march(x,y) AS (
  SELECT 1 AS x, 1 AS y -- start iso line at (1,1)
    UNION
  SELECT new.x AS x, new.y AS y
  FROM   march AS m, squares AS s, directions AS d,
         LATERAL (VALUES (m.x + (d.dir).Δx, m.y + (d.dir).Δy)) AS new(x,y)
  WHERE  (m.x,m.y) = (s.x,s.y)
  AND    (s.ll,s.lr,s.ul,s.ur) = (d.ll,d.lr,d.ul,d.ur)
)
-- TABLE pixels
-- ORDER BY x,y;
--
-- TABLE squares
-- ORDER BY x,y;
--
-- mask coord was lower left, relocate to grid intersection point in middle of square
--       ↓             ↓
SELECT m.x + 0.5 AS x, m.y + 0.5 AS y
FROM   march AS m;
