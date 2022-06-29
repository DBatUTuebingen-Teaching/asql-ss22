-- Liquid flow simulation
-- (example of a cell automaton in which a cell is influenced by as well
--  as influences its neighbours)
--
-- Loosely based on
-- https://www.reddit.com/r/cellular_automata/comments/6jhdfw/i_used_1dimensional_cellular_automata_to_make_a/
--
-- The (very simple) cellular automaton rules are found in fluid-1D-rules.py
-- Visualize using ./fluid.py ‹CSV output file›

-- Initial world
--
-- One cell of the autmaton = one column (ground + water) in the world
--
DROP TABLE IF EXISTS fluid;
CREATE TABLE fluid (
  x      int     NOT NULL,                         -- x coordinate
  ground int     NOT NULL CHECK (ground % 8 = 0),  -- elevation at point x (divisible by 8, because of character-based rendering)
  water  numeric NOT NULL,                         -- water volume at point x
  PRIMARY KEY (x)
);


-- A repertoire of initial worlds
--
DROP TABLE IF EXISTS input;
CREATE TEMPORARY TABLE input (
  y     serial,
  cells text NOT NULL
);



-- \COPY input(cells) FROM stdin
-- ░▄           ▄░
-- ░██         ██░
-- ░██         ██░
-- ░██         ██░
-- ░██         ██░
-- ░░░░░░░░░░░░░░░
-- \.


-- \COPY input(cells) FROM stdin
-- ░                  ███░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░                █████░
-- ░░░░░░░░░░░░░░░░░░░░░░░
-- \.


-- \COPY input(cells) FROM stdin
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░         █████        ░
-- ░░░░░░░░░░░░░░░░░░░░░░░░
-- \.


-- \COPY input(cells) FROM stdin
-- ░                      ░
-- ░                      ░
-- ░                      ░
-- ░████████      ████████░
-- ░████████      ████████░
-- ░████████      ████████░
-- ░████████      ████████░
-- ░████████      ████████░
-- ░████████      ████████░
-- ░░░░░░░░░░░░░░░░░░░░░░░░
-- \.


\COPY input(cells) FROM stdin
░                        ▄░
░                     ████░
░                   ██████░
░░    ░░░         ████████░
░░░  ░░░░░░      █████████░
░░░░░░░░░░░░     █████████░
░░░░░░░░░░░░░░░░░░░░░░░░░░░
\.

TABLE input;

-- Turn input table format into valid initial world
--
INSERT INTO fluid(x, ground, water)
  SELECT col.x,
         COALESCE(SUM(8) FILTER (WHERE col.cell = '░')                                 , 0) AS ground,
         COALESCE(SUM(array_position(array['▁','▂','▃','▄','▅','▆','▇','█'], col.cell)), 0) AS water
  FROM   input AS row,
         LATERAL string_to_table(row.cells, NULL) WITH ORDINALITY AS col(cell,x)
  GROUP BY col.x;

TABLE fluid
ORDER BY x;

-- influence of neighboring cells on position x
DROP TYPE IF EXISTS influence CASCADE;
CREATE TYPE influence AS (
  x        int,
  Δwater   numeric,
  Δkinetic numeric
);

-- Save flow simulation result so that we can copy it to a CSV file below
DROP TABLE IF EXISTS simulation;
CREATE TEMPORARY TABLE simulation AS
--
WITH RECURSIVE
sim(iter,x,ground,water,kinetic) AS (
  SELECT 0 AS iter, f.x, f.ground, f.water, 0.0 AS kinetic
  FROM   fluid AS f
    UNION ALL
  (--  prepare for multiple references
   --  to the recursive table sim
   -- ────────────────────────────────────
   WITH sim(iter,x,ground,water,kinetic) AS (
     TABLE sim
   )
   SELECT s0.iter + 1 AS iter, s0.x, s0.ground,
          --  if cell s0 has not been updated, Δwater ≡ NULL (we then keep our current water volume)
          --           ──────────────────────────────
          s0.water   + COALESCE(agg.Δwater  , 0) AS water,   -- water volume at x
          s0.kinetic + COALESCE(agg.Δkinetic, 0) AS kinetic  -- kinetic energy at x (< 0: towards left neighbor, > 0: towards right neighbor)
   FROM   --  first reference to recursive table sim:
          --  iterate over all cells s0 to find the changes that apply to it
          --  ──
          sim AS s0
          -- aggregate all the influences to be applied to current cell s0 (if there are none these yield NULL)
          --                      ────────────             ───────────────
            LEFT OUTER JOIN
          LATERAL (SELECT infs.x, SUM(infs.Δwater) AS Δwater, SUM(infs.Δkinetic) AS Δkinetic
                          -- encodes the rules of the fluid flow automaton:
                          -- the SELECT yields a single array of entries (x,Δwater,Δkinetic)
                          -- to indicate that the cell at x needs to change
                          -- its water volum by Δwater and its kinetic energy by Δkinetic
                   FROM   (SELECT (-- flow to the left
                                   --           potential energy
                                   --        ─────────────────
                                   CASE WHEN s1.ground + s1.water - s1.kinetic > LAG(s1.ground, 1) OVER horizontal + LAG(s1.water, 1) OVER horizontal + LAG(s1.kinetic, 1) OVER horizontal
                                   THEN array[ROW(s1.x-1,  LEAST(s1.water, s1.ground + s1.water - s1.kinetic - (LAG(s1.ground, 1) OVER horizontal + LAG(s1.water, 1) OVER horizontal + LAG(s1.kinetic, 1) OVER horizontal)) / 4, 0.0),
                                              ROW(s1.x  , -LEAST(s1.water, s1.ground + s1.water - s1.kinetic - (LAG(s1.ground, 1) OVER horizontal + LAG(s1.water, 1) OVER horizontal + LAG(s1.kinetic, 1) OVER horizontal)) / 4, 0.0),
                                              ROW(s1.x-1, 0.0, -LAG(s1.kinetic, 1) OVER horizontal / 2 - LEAST(s1.water, s1.ground + s1.water - s1.kinetic - (LAG(s1.ground, 1) OVER horizontal + LAG(s1.water, 1) OVER horizontal + LAG(s1.kinetic, 1) OVER horizontal)) / 4)
                                             ] :: influence[]
                                   END
                                   ||
                                   -- flow to the right
                                   CASE WHEN s1.ground + s1.water + s1.kinetic > LEAD(s1.ground, 1) OVER horizontal + LEAD(s1.water, 1) OVER horizontal - LEAD(s1.kinetic, 1) OVER horizontal
                                   THEN array[ROW(s1.x+1,  LEAST(s1.water, s1.ground + s1.water + s1.kinetic - (LEAD(s1.ground, 1) OVER horizontal + LEAD(s1.water, 1) OVER horizontal - LEAD(s1.kinetic, 1) OVER horizontal)) / 4, 0.0),
                                              ROW(s1.x  , -LEAST(s1.water, s1.ground + s1.water + s1.kinetic - (LEAD(s1.ground, 1) OVER horizontal + LEAD(s1.water, 1) OVER horizontal - LEAD(s1.kinetic, 1) OVER horizontal)) / 4, 0.0),
                                              ROW(s1.x+1, 0.0, -LEAD(s1.kinetic, 1) OVER horizontal / 2 + LEAST(s1.water, s1.ground + s1.water + s1.kinetic - (LEAD(s1.ground, 1) OVER horizontal + LEAD(s1.water, 1) OVER horizontal - LEAD(s1.kinetic, 1) OVER horizontal)) / 4)
                                             ] :: influence[]
                                   END
                                  ) AS influence
                           --     second reference to recursive table sim
                           --     ──────
                           FROM   sim AS s1
                           -- window that allows us to inspect cells in the horizontal neighborhood
                           --     ──────────────────────────
                           WINDOW horizontal AS (ORDER BY s1.x)
                          ) AS inf(influence),
                           --   turn array into table of (x,Δwater,Δkinetic) influence entries
                           --     ──────────────────────────
                          LATERAL unnest(inf.influence) AS infs
                   GROUP BY infs.x
                   ) AS agg(x, Δwater, Δkinetic)
                   -- find those influences that relate to current cell s0
                   -- ───────────
                   ON (s0.x = agg.x)
   WHERE  s0.iter < 300
  ) -- inner WITH (non-recursive, allow multiple references to table sim)
) -- top-level WITH RECURSIVE
SELECT s.iter, s.x, s.ground, s.water
FROM   sim AS s
ORDER BY s.iter, s.x;

TABLE simulation
ORDER BY iter, x
LIMIT 100;

-- Export table simulation in CSV format for rendering in the terminal
-- (see Python program fluid-1D.py)
\COPY simulation TO 'fluid-1D.csv' WITH (FORMAT csv);
