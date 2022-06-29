-- Use a recursive CTE to explore node-to-root paths in array-encoded
-- trees.

DROP TABLE IF EXISTS Trees;
CREATE TABLE Trees (tree    int PRIMARY KEY,
                    parents int[],
                    labels  text[]);

--      t₁                  t₂                     t₃
--
--   ¹     ᵃ           ⁶     ᵍ           ¹ ³     ᵃ ╷ᵈ
-- ² ⁵  ᵇ ᶜ        ⁴ ⁷  ᵇ ᶜ                  ╵
--      ╵        ¹ ⁵  ᵈ ᵉ          ² ⁴ ⁵     ᵇ ᶜ ᵉ
-- ³ ⁴⁶   ᵈ ᵉᶠ              
--                    ² ³    ᶠ ᵃ

INSERT INTO Trees VALUES
  (1, array[NULL,1,2,2,1,5],   array['a','b','d','e','c','f']),
  (2, array[4,1,1,6,4,NULL,6], array['d','f','a','b','e','g','c']),
  (3, array[NULL,1,NULL,1,3],  string_to_array('a;b;d;c;e',';'));



-- ➊ Which nodes are on the path from node labeled 'f' to the root?
--
WITH RECURSIVE
paths(tree, node) AS (
  SELECT t.tree, array_position(t.labels, 'f') AS node
  FROM   Trees AS t
    UNION
  SELECT t.tree, t.parents[p.node] AS node
  FROM   paths AS p, Trees AS t
  WHERE  p.tree = t.tree
)
TABLE paths
ORDER BY tree;
-- SELECT p.tree, p.node
-- FROM   paths AS p
-- WHERE  p.node IS NOT NULL
-- ORDER BY p.tree;



-- ➋ Which nodes are on the path from node labeled 'f' to the root
--   and on which position on the path are these nodes?
--
WITH RECURSIVE
paths(tree, pos, node) AS (
  SELECT t.tree, 0 AS pos, array_position(t.labels, 'f') AS node
  FROM   Trees AS t
    UNION
  SELECT t.tree, p.pos + 1 AS pos, t.parents[p.node] AS node
  FROM   paths AS p, Trees AS t
  WHERE  p.tree = t.tree AND p.node IS NOT NULL
  --                         ───────────────
  --           avoid infinite recursion once we reach the root
  --           (yield ∅ once we encounter p.node ≡ NULL the first time)
)
SELECT p.tree, p.pos, p.node
FROM   paths AS p
WHERE  p.node IS NOT NULL
ORDER BY p.tree, p.pos;


-- ➌ Which nodes are on the path from node labeled 'f' to the root?
--   Represents the path as an array of nodes.
--
WITH RECURSIVE
paths(tree, node, path) AS (
  SELECT t.tree,
         array_position(t.labels, 'f') AS node,
         array[] :: int[] AS path
  FROM   Trees AS t
    UNION
  SELECT t.tree,
         t.parents[p.node] AS node,
         p.path || p.node AS path
  FROM   paths AS p, Trees AS t
  WHERE  p.tree = t.tree AND p.node IS NOT NULL
  --                         ───────────────
  --           ➊ avoid infinite recursion once we reach the root
  --        (yield ∅ once we encounter p.node ≡ NULL the first time)
)
SELECT p.*
FROM   paths AS p
WHERE  p.node IS NULL -- ➋ only retain the rows from the last iteration
ORDER BY p.tree;



-- Quiz: Can you adapt the last query to form the paths for multiple
--       labels (say 'f' and 'e')?
