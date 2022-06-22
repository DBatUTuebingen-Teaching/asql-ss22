-- Run-length encoding (compression) of pixel images

-- Sample input image
--
DROP TABLE IF EXISTS input;
CREATE TEMPORARY TABLE input (
  y      serial,
  pixels text NOT NULL
);

\COPY input(pixels) FROM stdin
░▉▉░░░▉▉░░░▉░░░
▉░░▉░▉░░▉░░▉░░░
▉░░░░▉░░▉░░▉░░░
░▉▉░░▉░░▉░░▉░░░
░░░▉░▉░▉▉░░▉░░░
▉░░▉░▉░░▉░░▉░░░
░▉▉░░░▉▉░▉░▉▉▉▉
\.

TABLE input;

-- (x,y,color) representation of image to encode
--
DROP TYPE IF EXISTS color CASCADE;
CREATE TYPE color AS ENUM ('undefined', '░', '▉');

DROP TABLE IF EXISTS original;
CREATE TABLE original (
  x     int   NOT NULL,
  y     int   NOT NULL,
  pixel color NOT NULL,
  PRIMARY KEY (x,y)
);

-- Load image from sample input
INSERT INTO original(x,y,pixel)
  SELECT col.x, row.y, col.pixel :: color
  FROM   input AS row,
         LATERAL string_to_table(row.pixels, NULL) WITH ORDINALITY AS col(pixel,x);

TABLE original;

-----------------------------------------------------------------------
-- Run-length encoding

DROP TABLE IF EXISTS encoding;
CREATE TEMPORARY TABLE encoding AS -- save result for later decoding

WITH
changes(x,y,pixel,"change?") AS (
  SELECT o.x, o.y, o.pixel,
         o.pixel <> LAG(o.pixel, 1, 'undefined') OVER byrow AS "change?"
  FROM   original AS o
  WINDOW byrow AS (ORDER BY o.y, o.x)
                -- ──────────────
                -- scans image row-by-row
),
runs(x,y,pixel,run) AS (
  SELECT c.x, c.y, c.pixel,
         SUM(c."change?" :: int) OVER byrow AS run
         --  ───────────────
         --  true → 1, false → 0
  FROM   changes AS c
  WINDOW byrow AS (ORDER BY c.y, c.x) -- default: RANGE FROM UNBOUNDED PRECEDING TO CURRENT ROW ⇒ SUM scan
),
encoding(run,length,pixel) AS (
  SELECT r.run, COUNT(*) AS length, r.pixel
  FROM   runs AS r
  GROUP BY r.run, r.pixel
               -- ────
               -- does not affect grouping since run → pixel (all pixels in a run have the same color)
  ORDER BY r.run
)
TABLE encoding;

-----------------------------------------------------------------------
-- Decoding

DROP TABLE IF EXISTS decoding;
CREATE TEMPORARY TABLE decoding AS -- save result for comparison with original image

WITH dimension(width) AS (
  SELECT MAX(o.x) AS width
  FROM   original AS o
),
expansion(pos,pixel) AS (
  SELECT ROW_NUMBER() OVER (ORDER BY e.run, nth) - 1 AS pos, e.pixel
  FROM   encoding AS e,
         LATERAL generate_series(1, e.length) AS nth
),
decoding(x,y,pixel) AS (
  SELECT e.pos % d.width + 1 AS x, e.pos / d.width + 1 AS y, e.pixel
  FROM   expansion AS e, dimension AS d
  ORDER BY y, x
)
TABLE decoding;


-- If original and decoded image are identical,
-- this should yield no rows:
TABLE original EXCEPT TABLE decoding
  UNION
TABLE decoding EXCEPT TABLE original;


-- Output decoded image in 2D format:
SELECT d.y, string_agg(d.pixel :: text, NULL ORDER BY d.x) AS pixels
FROM   decoding AS d
GROUP BY d.y
ORDER BY d.y;
