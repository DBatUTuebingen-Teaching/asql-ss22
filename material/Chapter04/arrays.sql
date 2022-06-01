-- Represent labelled forests using arrays:
-- - if parents[i] = j, then j is parent node of node i,
-- - if labels[i] = ℓ, then ℓ is the label of node i.

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

INSERT INTO Trees(tree, parents, labels) VALUES
  (1, array[NULL,1,2,2,1,5],   array['a','b','d','e','c','f']),
  (2, array[4,1,1,6,4,NULL,6], array['d','f','a','b','e','g','c']),
  (3, array[NULL,1,NULL,1,3],  string_to_array('a;b;d;c;e',';'));

TABLE trees;

-- Consistency: length of parents[] and labels[] match for all trees?
--
SELECT bool_and(cardinality(t.parents) = cardinality(t.labels))
FROM   Trees AS t;


-- Which trees (and nodes) carry an 'f' label?
--
SELECT t.tree, array_positions(t.labels, 'f') AS "f nodes"
FROM   Trees AS t
WHERE  'f' = ANY(t.labels);


-- Find the label of the (first) root
--
SELECT t.tree, t.labels[array_position(t.parents,NULL)] AS root
FROM   Trees AS t;


-- Which trees actually are forests (collection of trees with more
-- than one root)?
--
SELECT t.tree AS forest
FROM   Trees AS t
WHERE  cardinality(array_positions(t.parents,NULL)) > 1;



-----------------------------------------------------------------------
-- The following should be simple but are hard (impossible?) to
-- formulate:

-- ➊ Find the largest label.  Transform all labels to uppercase.
--   Find the parents of all nodes with label 'c'.
--   (Need to access all/iterate over array elements)

-- ➋ Concatenate two trees (leaf ℓ of t₁ is new parent of root of t₂)
--   (Need to adapt/shift elements in parents[], then form new array)

-- (↯☠☹⛈)

-- So many array functions, so little can be done.
-- SOMETHING'S MISSING...


-----------------------------------------------------------------------
-- unnest / array_agg

SELECT t.*
FROM   unnest(array['x₁','x₂','x₃']) WITH ORDINALITY AS t(elem,idx);

--                                   try: DESC
--                                      ↓
SELECT array_agg(t.elem ORDER BY t.idx ASC) AS xs
FROM   (VALUES ('x₁',1),
               ('x₂',2),
               ('x₃',3)) AS t(elem,idx);



-- unnest() indeed is a n-ary function that unnest multiple
-- arrays at once: unnest(xs₁,...,xsₙ), one per column.  Shorter
-- columns are padded with NULL (see zipping in table-functions.sql):
--
SELECT node.parent, node.label
FROM   Trees AS t,
       unnest(t.parents, t.labels) AS node(parent,label)
WHERE  t.tree = 2;


SELECT node.*
FROM   Trees AS t,
       unnest(t.parents, t.labels) WITH ORDINALITY AS node(parent,label,idx)
WHERE  t.tree = 2;


-- Transform all labels to uppercase:
--
SELECT t.tree,
       array_agg(node.parent ORDER BY node.idx) AS parents,
       array_agg(upper(node.label) ORDER BY node.idx) AS labels
FROM   Trees AS t,
       unnest(t.parents,t.labels) WITH ORDINALITY AS node(parent,label,idx)
GROUP BY t.tree;


-- Find the parents of all nodes with label 'c'
--
SELECT t.tree, t.parents[node.idx] AS "parent of c"
FROM   Trees AS t,
       unnest(t.labels) WITH ORDINALITY AS node(label,idx)
WHERE  node.label = 'c';


-- Find the forests among the trees:
--
SELECT t.*
FROM   Trees AS t,
       unnest(t.parents) AS node(parent)
WHERE  node.parent IS NULL
GROUP BY t.tree
HAVING COUNT(*) > 1; -- true forests have more than one root node


-- Problem ➋ (attach tree t₂ to leaf 6/f of t₁).  Yes, this is getting
-- ugly and awkward.  Arrays are helpful, but SQL is not an array
-- programming language.
--
-- Plan: append nodes of t₁ to those of t₂:
--
-- 1. Determine root r and size s (= node count) of t₂
-- 2. Shift all parents of t₁ by s, preserve labels
-- 3. Concatenate the parents of t₂ and t₁, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t₂ and t₁

\set t1 1
\set ℓ 6
\set t2 2

WITH
-- 1. Determine root r and size s (= node count) of t2
t2(root,size,parents,labels) AS (
  SELECT array_position(t2.parents,NULL) AS root,
         cardinality(t2.parents) AS size,
         t2.parents,
         t2.labels
  FROM   Trees AS t2
  WHERE  t2.tree = :t2
),
-- 2. Shift all parents of t1 by s, preserve labels
t1(parents,labels) AS (
  SELECT (SELECT array_agg(node.parent + t2.size ORDER BY node.idx)
          FROM   unnest(t1.parents) WITH ORDINALITY AS node(parent,idx)) AS parents,
         t1.labels
  FROM   Trees AS t1, t2
  WHERE  t1.tree = :t1
)
-- 3. Concatenate the parents of t2 and t1, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t2 and t1
SELECT (SELECT array_agg(CASE node.idx WHEN t2.root THEN :ℓ + t2.size
                                       ELSE node.parent
                         END
                         ORDER BY node.idx)
        FROM   unnest(t2.parents) WITH ORDINALITY AS node(parent,idx)) || t1.parents AS parents,
       t2.labels || t1.labels AS labels
FROM   t1, t2;

-- Problem ➌:
--
-- Which nodes are on the path from node labeled 'f' to the root?
--
-- (↯☠☹⛈)
--
-- Would need to repeatedly peek into parents[] array until we hit
-- the root node.  But how long will the path be?
--
-- SOMETHING'S STILL MISSING. (⇒ Later)
