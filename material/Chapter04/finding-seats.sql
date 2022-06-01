-- SQL implementation of the ACM ICPC 2007 South American Regional Task
-- "Finding Seats"


-- Demonstrates:
-- - LATERAL
-- - table functions (generate_series(), string_to_table())
-- - WITH ORDINALITY
-- - WITH (CTEs)


-- ACM ICPC problem instances (pick one)

-- ➊ Seat reservation map and number of wanted seats
-- ...XX
-- .X.XX
-- XX...
\set cinema '...XX\\n.X.XX\\nXX...'
\set K 5

-- ➋ Seat reservation map and number of wanted seats
-- ..X.X.
-- .XXX..
-- .XX.X.
-- .XXX.X
-- .XX.XX
-- \set cinema '..X.X.\\n.XXX..\\n.XX.X.\\n.XXX.X\\n.XX.XX'
-- \set K 6



WITH
-- "Parse" ASCII seat map into table (row, col, taken?)
seats(row, col, "taken?") AS (
  SELECT row.pos AS row, col.pos AS col, col.x = 'X' AS "taken?"
  FROM   string_to_table(:'cinema', '\n')       -- split lines
         WITH ORDINALITY AS row(xs, pos),
         LATERAL string_to_table(row.xs, NULL)  -- split between any two characters
                 WITH ORDINALITY AS col(x, pos)
),
-- Extent of cinema's seating area (rows × cols seats)
extent(rows, cols) AS (
  SELECT MAX(s.row) AS rows, MAX(s.col) AS cols
  FROM   seats AS s
),
-- Upper left (nw) corner and width/height of all
-- rectangular seating areas that have sufficient free seats
rects(nw, width, height) AS (
  SELECT ROW(row_nw, col_nw) AS nw,
         col_se - col_nw + 1 AS width,
         row_se - row_nw + 1 AS height
  FROM   extent AS e(rows, cols),
         LATERAL generate_series(1, e.rows)      AS row_nw,  -- ⎱ iterate over all possible
         LATERAL generate_series(1, e.cols)      AS col_nw,  -- ⎰ north-west rectangle corners
         LATERAL generate_series(row_nw, e.rows) AS row_se,  -- ⎱ iterate over all possible
         LATERAL generate_series(col_nw, e.cols) AS col_se   -- ⎰ south-east (lower right) corners
  WHERE  :K <=
         (SELECT COUNT(*) FILTER (WHERE NOT s."taken?")      -- # of free seats in the
          FROM   seats AS s                                  -- current rectangle of seats
          WHERE  s.row BETWEEN row_nw AND row_se
          AND    s.col BETWEEN col_nw AND col_se)
)
-- Extract all rectangles that have minimal area
SELECT r.nw, r.width, r. height
FROM   rects AS r
WHERE  r.width * r.height = (SELECT MIN(r.width * r.height)
                             FROM   rects AS r);
