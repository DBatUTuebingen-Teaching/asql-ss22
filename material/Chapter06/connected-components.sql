-- Connected components in an undirected graph


-- (0) Build tabular representation of undirected graph:
--
--        A ─── B
--             ╱│
--      E •   ╱ │
--           ╱  │
--        D ─── C
--
--        F ─── G

DROP TABLE IF EXISTS edges CASCADE;
DROP TABLE IF EXISTS nodes CASCADE;

CREATE TABLE nodes (
  node  serial PRIMARY KEY,
  label text);

CREATE TABLE edges (
   "from" int,
   "to"   int,
   FOREIGN KEY ("from") REFERENCES nodes,
   FOREIGN KEY ("to")   REFERENCES nodes);

INSERT INTO nodes(label) VALUES
  ('A'),
  ('B'),
  ('C'),
  ('D'),
  ('E'),
  ('F'),
  ('G');

INSERT INTO edges VALUES
  (1, 2),
  (2, 3),
  (3, 4),
  (2, 4),
  (6, 7);  -- F 🡒 G (+ F 🡐 G = F ── G)

-- (0)
-- Table graph: for any edge (n1,n2) in edges add edge (n2,n1)
-- to simplify the components query below (the graph
-- is undirected and egdes may be traversed in both directions)
--
DROP TABLE IF EXISTS graph;
CREATE TEMPORARY TABLE graph AS
  TABLE edges
    UNION
  SELECT e."to" AS "from", e."from" AS "to"
  FROM   edges e;

TABLE graph;

-----------------------------------------------------------------------

WITH RECURSIVE
-- (1)
-- For each node node perform a walk through the graph, collecting
-- all nodes that we can reach.  A row (n,f) in components indicates
-- that we started a walk in n and have reached front node f.
--
-- Base case: We start the walk at n.node and this is also the last
-- last node we have reached so far (≡ front).
--
-- Recursive case: Continue the walk from the last reached node w.front,
-- we reach g."to".  Record g."to" as the new front.
--
-- The set semantics of UNION will avoid that we run into endless cycles,
-- the same front is never recorded twice.  ⇒ The walks will terminate.
--
walks(node, front) AS (
  SELECT n.node, n.node AS front
  FROM   nodes AS n
    UNION
  SELECT w.node, g."to" AS front
  FROM   walks AS w, graph AS g
  WHERE  w.front = g."from"
),
-- (2)
-- For each node, use its minimum front node ID as the component identifier
-- ⇒ the nodes in one components will agree on the component ID.
--
components(node, component) AS (
  SELECT w.node, MIN(w.front) AS component
  FROM   walks AS w
  GROUP BY w.node
  ORDER BY w.node
),
-- (3 — Post-processing only)
-- Assign sane component IDs (C1, C2, ...)
--
components123(node, component) AS (
  SELECT c.node, 'C' || DENSE_RANK() OVER (ORDER BY c.component) AS component
  FROM   components AS c
),
-- (4 — Post-processing only)
-- Extract the edges of the components' subgraph
--
subgraphs(component, "from", "to") AS (
  SELECT DISTINCT c.component, g."from", g."to"
  FROM   components123 AS c
            LEFT OUTER JOIN -- ← use JOIN if components w/o edges are to be omitted
         graph AS g ON c.node IN (g."from", g."to")
  ORDER BY c.component, g."from", g."to"
)
TABLE walks
ORDER BY node;
--
-- TABLE components
-- ORDER BY node;
--
-- TABLE components123
-- ORDER BY node;
--
-- TABLE subgraphs;


-----------------------------------------------------------------------
-- For debugging/visualization only
-- (tracks WHEN a front node was reached)



WITH RECURSIVE
walks(iter, node, front) AS (
  SELECT 0 AS iter, n.node, n.node AS front
  FROM   nodes AS n
    UNION
  SELECT w.iter + 1 AS iter, w.node, g."to" AS front
  FROM   walks AS w, graph AS g
  WHERE  w.front = g."from"
  AND    w.iter < 10 -- allow for plenty of steps, but ...
)
SELECT w.node, w.front, w.iter AS "encountered at step"
FROM   (SELECT DISTINCT ON (w.node, w.front) w.*  -- ⎫ ... for each node, keep each front encounter
        FROM   walks AS w                         -- ⎬ only once (the one that happened first)
        ORDER BY w.node, w.front, w.iter) AS w    -- ⎭
ORDER BY w.iter, w.node;

