-- Create playground table T and populate it with sample rows:

DROP TABLE IF EXISTS T;
CREATE TABLE T (a int PRIMARY KEY,
                b text,
                c boolean,
                d int);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);


-- Extract all rows and all columns of table T (this is equivalent to
--   SELECT t.*
--   FROM   T AS t)

TABLE T;


-- Iterate over all rows of table T, row variable t is
-- successively bound to the rows of T (i.e., t has a row type)
SELECT t
FROM   T AS t;


-----------------------------------------------------------------------
-- Create table T1 identical to T, but create the row type τ first

DROP TABLE IF EXISTS T1;

-- (1) Create row type τ (no table yet):

DROP TYPE IF EXISTS τ;
CREATE TYPE τ AS (a int, b text, c boolean, d int);

-- (2) Create table T1 based on row type τ:

CREATE TABLE T1 OF τ;
ALTER TABLE T1 ADD PRIMARY KEY (a);

-- (3) Copy the rows of T into T1:

INSERT INTO T1(a, b, c, d)
  TABLE T;


TABLE T1;

-----------------------------------------------------------------------
-- Using the VALUES clause to specify (unnamed) literal tables
-- (the first row value determines the row type of the table)

-- two rows, one column "column1":

VALUES (1),
       (2);

-- one row, two columns "column1", "column2":

VALUES (1, 2);


-- three rows, two columns:

VALUES (false,   0),
       (true,    1),
       (NULL, NULL);
--        ↑     ↑
-- :: boolean  :: int

-----------------------------------------------------------------------
-- Using column aliasing to rename table columns

-- Row type of row variable t is (column1 boolean, column2 int):

SELECT t.*
FROM   (VALUES (false, 0),
               (true,  1)) AS t;


-- Row type of row variable t is (truth boolean, "binary" int):

SELECT t.*
FROM   (VALUES (false, 0),
               (true,  1)) AS t(truth, "binary");


-- Row type of row variable t is (truth boolean, column2 int):

SELECT t.*
FROM   (VALUES (false, 0),
               (true,  1)) AS t(truth);  -- rename first column only (🙁 bad style)


-----------------------------------------------------------------------
-- FROM computes Cartesian product of row bindings

SELECT t1.*, t2.*
FROM   T AS t1,
       T AS t2(a2, b2, c2, d2);


SELECT onetwo.num, t.*
FROM   (VALUES ('➊'), ('➋')) AS onetwo(num),
       T AS t;


-----------------------------------------------------------------------
-- WHERE discards row bindings

SELECT onetwo.num, t.*
FROM   (VALUES ('➊'), ('➋')) AS onetwo(num), T AS t
WHERE  onetwo.num = '➋';


SELECT t.*
FROM   T AS t
WHERE  t.a * 10 = t.d;


SELECT t.*
FROM   T AS t
WHERE  t.c;  -- ≡ WHERE t.c = true 😕


SELECT t.*
FROM   T AS t
WHERE  t.d IS NULL;

-- A =-comparison with NULL yields NULL:

SELECT t.d, t.d IS NULL AS "IS NULLL", t.d = NULL AS "= NULL"   -- ⚠ t.d = NULL yields NULL ≠ true
FROM   T AS t;


-- Form pairs of rows t1, t2 whose values in column a differ by at most 1:

SELECT t1.a, t1.b || ',' || t2.b AS b₁b₂  -- to illustrate: add ..., t2.a
FROM   T AS t1, T AS t2
WHERE  t1.a BETWEEN t2.a - 1 AND t2.a + 1;


-----------------------------------------------------------------------
-- Scalar subqueries

--        generate single column
--                  ↓

SELECT 2 + (SELECT t.d AS _
            FROM   T AS t
            WHERE  t.a = 2)  AS "The Answer";   -- ⚠ t.a = 0,  t.a > 2

--                 └──┬──┘
--      equality predicate on key column,
--      will yield ⩽ 1 rows



-----------------------------------------------------------------------
-- Correlation

-- Will yield empty result since {a} is key and thus a→b

-- EXPLAIN (TIMING false, COSTS false)

SELECT t1.*
FROM   T AS t1
WHERE  t1.b <> (SELECT t2.b
                FROM   T AS t2
                WHERE  t1.a = t2.a);

-- Use EXPLAIN (TIMING false, COSTS false) to see the iterated evaluation of the
-- subquery:
-- ┌─────────────────────────────────────────┐
-- │               QUERY PLAN                │
-- ├─────────────────────────────────────────┤
-- │ Seq Scan on t t1                        │
-- │   Filter: (b <> (SubPlan 1))            │
-- │   SubPlan 1                             │
-- │     ->  Index Scan using t_pkey on t t2 │
-- │           Index Cond: (a = t1.a)        │
-- └─────────────────────────────────────────┘

-- Use EXPLAIN (ANALYZE, TIMING false, COSTS false) to also see the number of
-- subquery iterations (loop=…) actually performed:
-- ┌─────────────────────────────────────────────────────────────────┐
-- │                           QUERY PLAN                            │
-- ├─────────────────────────────────────────────────────────────────┤
-- │ Seq Scan on t t1 (actual rows=0 loops=1)                        │
-- │   Filter: (b <> (SubPlan 1))                                    │
-- │   Rows Removed by Filter: 5                                     │
-- │   SubPlan 1                                                     │
-- │     ->  Index Scan using t_pkey on t t2 (actual rows=1 loops=5) │
-- │           Index Cond: (a = t1.a)                                │
-- │ Planning Time: 0.252 ms                                         │
-- │ Execution Time: 0.118 ms                                        │
-- └─────────────────────────────────────────────────────────────────┘




-----------------------------------------------------------------------
-- Row ordering

SELECT t.*
FROM   T AS t
ORDER BY t.d ASC NULLS FIRST;  -- default: NULL larger than any non-NULL value

SELECT t.*
FROM   T AS t
ORDER BY t.b DESC, t.c;        -- default: ASC, false < true

SELECT t.*, t.d / t.a AS ratio
FROM   T AS t
ORDER BY ratio;                -- may refer to computed columns


VALUES (1, 'one'),
       (2, 'two'),
       (3, 'three')
ORDER BY column1 DESC;


SELECT t.*
FROM   T AS t
ORDER BY t.a DESC
OFFSET 1          -- skip 1 row
LIMIT 3;          -- fetch ⩽ 3 rows (≡ FETCH NEXT 3 ROWS ONLY)




-----------------------------------------------------------------------
-- Duplicate removal (DISTINCT ON, DISTINCT)


-- Keep the d-smallest row for each of the two false/true groups

-- EXPLAIN (TIMING false, COSTS false)
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.c, t.d ASC;


-- In absence of ORDER BY, we get *any* representative from the
-- two groups (PostgreSQL still uses sorting on t.c, however):

--EXPLAIN (TIMING false, COSTS false)
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t;

-- An "incompatible" clause lets PostgreSQL choke:
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.a;


-----------------------------------------------------------------------
-- Aggregation

-- Aggregate all rows in table T, resulting table has one row (even
-- if no rows are supplied):

SELECT COUNT(*)          AS "#rows",
       COUNT(t.d)        AS "#d",
       SUM(t.d)          AS "∑d",
       MAX(t.b)          AS "max(b)",
       bool_and(t.c)     AS "∀c",
       bool_or(t.d = 42) AS "∃d=42"
FROM   T AS t
WHERE  true;

TABLE T;


-- Ordered aggregate (',' separates the aggregated string values):

SELECT string_agg(t.a :: text, ',' ORDER BY t.d) AS "all a"
FROM   T AS t;

TABLE T;

-- Filtered aggregate:

SELECT SUM(t.d) FILTER (WHERE t.c) AS picky,
       SUM(t.d)                    AS "don't care"
FROM   T As t;

-- The query below implements the same filtered aggregration
--
--                            can use NULL here
--                                     ↓
SELECT SUM(CASE WHEN t.c THEN t.d ELSE 0 END) AS picky,
       SUM(t.d) AS "don't care"
FROM   T As t;


-- Simple pivoting
SELECT SUM(t.d) FILTER (WHERE t.b = 'x')            AS "∑d in region x",
       SUM(t.d) FILTER (WHERE t.b = 'y')            AS "∑d in region y",
       SUM(t.d) FILTER (WHERE t.b NOT IN ('x','y')) AS "∑d elsewhere"
FROM   T As t;


-- Unique aggregate
SELECT COUNT(DISTINCT t.c) AS "#distinct non-NULL",  -- there are only two distinct Booleans...
       COUNT(t.c)          AS "#non-NULL"
FROM   T as t;


-----------------------------------------------------------------------
-- Grouping

-- Aggregates are evaluated once per (qualifying) group:

SELECT t.b                           AS "group",
       COUNT(*)                      AS size,
       SUM(t.d)                      AS "∑d",
       bool_and(t.a % 2 = 0)         AS "∀even(a)", -- true in the 'x' group, false in the 'y' group
       string_agg(t.a :: text, ';')  AS "all a"
FROM   T AS t
GROUP BY t.b;
-- HAVING COUNT(*) > 2;


--   ⚠️ t.a is *not* constant in each group (but t.a % 2 is)
--         ↓

SELECT t.a % 2 AS "a odd?",
       COUNT(*) AS size
FROM   T AS t
GROUP BY t.a % 2;

--           ↑
--     partition T into the odd/even key values


-- For the following example recall table T:
--  • if t.b = 'x', then t.a is odd
--  • if t.b = 'y', then t.a is even
--
SELECT t.b AS "group",
       t.a % 2 AS "a odd?" -- constant in the 'x'/'y' groups, but PostgreSQL doesn't know...
FROM   T AS t
GROUP BY t.b, t.a % 2;
--            └──┬──┘
-- functionally dependent on t.b ⇒ will not affect grouping,
-- list here explicitly as grouping criterion, so we may use
-- it in the SELECT clause


-----------------------------------------------------------------------
-- Bag/set operations

-- For all bag/set operations, the lhs/rhs argument tables need to
-- contribute compatible rows:
-- • row widths must match
-- • field types in corresponding columns must be cast-compatible
-- • the row type of the lhs argument determines the result's
--   field types and names

SELECT t.*
FROM   T AS t
WHERE  t.c
  UNION ALL   -- ≡ UNION (since both queries are disjoint: key t.a included)
SELECT t.*
FROM   T AS t
WHERE  NOT t.c;


SELECT t.b
FROM   T AS t
WHERE  t.c
  UNION ALL       -- ≠ UNION (queries contribute duplicate rows)
SELECT t.b
FROM   T AS t
WHERE  NOT t.c;


-- Which subquery qᵢ contributed what to the result?
SELECT 'q₁' AS q, t.b
FROM   T AS t
WHERE  t.c
  UNION ALL
SELECT 'q₂' AS q, t.b
FROM   T AS t
WHERE  NOT t.c;


SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₁ contributes 2 × 'x', 1 × 'y'
WHERE  t.c        -- ⎭
  EXCEPT ALL
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₂ contributes 1 × 'x', 1 × 'y'
WHERE  NOT t.c;   -- ⎭


-- EXCEPT ALL is *not* commutative (this yields ∅):
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₂ contributes 1 × 'x', 1 × 'y'
WHERE  NOT t.c    -- ⎭
  EXCEPT ALL
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₁ contributes 2 × 'x', 1 × 'y'
WHERE  t.c;       -- ⎭



-----------------------------------------------------------------------

DROP TABLE IF EXISTS prehistoric;
CREATE TABLE prehistoric (class        text,
                          "herbivore?" boolean,
                          legs         int,
                          species      text);

INSERT INTO prehistoric VALUES
  ('mammalia',  true, 2, 'Megatherium'),
  ('mammalia',  true, 4, 'Paraceratherium'),
  ('mammalia', false, 2, NULL),           -- no known bipedal carnivores
  ('mammalia', false, 4, 'Sabretooth'),
  ('reptilia',  true, 2, 'Iguanodon'),
  ('reptilia',  true, 4, 'Brachiosaurus'),
  ('reptilia', false, 2, 'Velociraptor'),
  ('reptilia', false, 4, NULL);           -- no known quadropedal carnivores


TABLE prehistoric;

-- Group in all three dimensions (class, herbivore?, legs)
SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use COALESCE(p.species, '?'))
FROM   prehistoric AS p
GROUP BY GROUPING SETS ((class), ("herbivore?"), (legs));


-- Equivalent to GROUPING SETS ((class), ("herbivore?"), (legs))
SELECT p.class,
       NULL :: boolean             AS "herbivore?", -- ⎱  NULL is polymorphic ⇒ PostgreSQL
       NULL :: int                 AS legs,         -- ⎰  will default to type text
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.class

  UNION ALL

SELECT NULL :: text                AS class,
       p."herbivore?",
       NULL :: int                 AS legs,
       string_agg(p.species, ',' ) AS species
FROM   prehistoric AS p
GROUP BY p."herbivore?"

  UNION ALL

SELECT NULL :: text                AS class,
       NULL :: boolean             AS "herbivore?",
       p.legs AS legs,
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.legs;


-- ROLLUP
SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use COALESCE(p.species, '?'))
FROM   prehistoric AS p
GROUP BY ROLLUP (class, "herbivore?", legs)
-- optional: "visualize" hierarchy (least specific last)
-- ORDER BY (class IS NULL) :: int + ("herbivore?" IS NULL) :: int + (legs IS NULL) :: int, class, "herbivore?", legs
;

-- ROLLUP result:
---
--                                             ┌──────────┬────────────┬──────┬──────────────────────────────────────────────────────────────────────────────────┐
--    GROUP BY ...                             │  class   │ herbivore? │ legs │                                     species                                      │
--                                             ├──────────┼────────────┼──────┼──────────────────────────────────────────────────────────────────────────────────┤
--                    ⎧                        │ mammalia │ t          │    2 │ Megatherium                                                                      │
-- class, herb?, legs ⎨                        │ mammalia │ t          │    4 │ Paraceratherium                                                                  │
--                    │                        │ mammalia │ f          │    4 │ Sabretooth                                                                       │
--                    │       individual       │ mammalia │ f          │    2 │ ▢                                                                                │
--                    │        species         │ reptilia │ t          │    2 │ Iguanodon                                                                        │
--                    │                        │ reptilia │ t          │    4 │ Brachiosaurus                                                                    │
--                    │                        │ reptilia │ f          │    2 │ Velociraptor                                                                     │
--                    ⎩                        │ reptilia │ f          │    4 │ ▢                                                                                │
--                    ⎧  herbivorous mammals →│ mammalia │ t          │    ▢ │ Megatherium, Paraceratherium                                                     │
--       class, herb? ⎨  carnivorous mammals →| mammalia │ f          │    ▢ │ Sabretooth                                                                       │
--                    │ herbivorous reptiles →│ reptilia │ t          │    ▢ │ Iguanodon, Brachiosaurus                                                         │
--                    ⎩ carnivorous reptiles →| reptilia │ f          │    ▢ │ Velociraptor                                                                     │
--              class ⎰              mammals →│ mammalia │ ▢          │    ▢ │ Sabretooth, Megatherium, Paraceratherium                                         │
--                    ⎱             reptiles →│ reptilia │ ▢          │    ▢ │ Velociraptor, Iguanodon, Brachiosaurus                                           │
--                 () {  prehistoric animals →│ ▢        │ ▢          │    ▢ │ Sabretooth, Megatherium, Paraceratherium, Velociraptor, Iguanodon, Brachiosaurus │
--                                             └──────────┴────────────┴──────┴──────────────────────────────────────────────────────────────────────────────────┘


-- With the empty set ∅ ≡ () of grouping criteria,
-- all rows form a *single* large group:
SELECT string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY ();                                -- same as w/o GROUP BY



-- CUBE
SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use coalesce(p.species, '?'))
FROM   prehistoric AS p
GROUP BY CUBE (class, "herbivore?", legs)
-- optional: order groups (least specific last)
-- ORDER BY (class IS NULL) :: int + ("herbivore?" IS NULL) :: int + (legs IS NULL) :: int, class, "herbivore?", legs
;

-- CUBE result:
--
--                                               ┌──────────┬────────────┬──────┬──────────────────────────────────────────────────────────────────────────────────┐
--    GROUP BY ...                               │  class   │ herbivore? │ legs │                                     species                                      │
--                                               ├──────────┼────────────┼──────┼──────────────────────────────────────────────────────────────────────────────────┤
--                    ⎧                          │ mammalia │ t          │    2 │ Megatherium                                                                      │
-- class, herb?, legs ⎨                          │ mammalia │ t          │    4 │ Paraceratherium                                                                  │
--                    │                          │ mammalia │ f          │    2 │ ▢                                                                                │
--                    │       individual         │ mammalia │ f          │    4 │ Sabretooth                                                                       │
--                    │        species           │ reptilia │ t          │    2 │ Iguanodon                                                                        │
--                    │                          │ reptilia │ t          │    4 │ Brachiosaurus                                                                    │
--                    │                          │ reptilia │ f          │    2 │ Velociraptor                                                                     │
--                    ⎩                          │ reptilia │ f          │    4 │ ▢                                                                                │
--                    ⎧    herbivorous mammals →│ mammalia │ t          │    ▢ │ Megatherium, Paraceratherium                                                     │
--       class, herb? ⎨    carnivorous mammals →│ mammalia │ f          │    ▢ │ Sabretooth                                                                       │
--                    │   herbivorous reptiles →│ reptilia │ t          │    ▢ │ Iguanodon, Brachiosaurus                                                         │
--                    ⎩   carnivorous reptiles →│ reptilia │ f          │    ▢ │ Velociraptor                                                                     │
--                    ⎧        bipedal mammals →│ mammalia │ ▢          │    2 │ Megatherium                                                                      │
--        class, legs ⎨    quadropedal mammals →│ mammalia │ ▢          │    4 │ Sabretooth, Paraceratherium                                                      │
--                    │       bipedal reptiles →│ reptilia │ ▢          │    2 │ Velociraptor, Iguanodon                                                          │
--                    ⎩   quadropedal reptiles →│ reptilia │ ▢          │    4 │ Brachiosaurus                                                                    │
--                    ⎧     bipedal herbivores →│ ▢        │ t          │    2 │ Megatherium, Iguanodon                                                           │
--        herb?, legs ⎨ quadropedal herbivores →│ ▢        │ t          │    4 │ Paraceratherium, Brachiosaurus                                                   │
--                    │     bipedal carnivores →│ ▢        │ f          │    2 │ Velociraptor                                                                     │
--                    ⎩ quadropedal carnivores →│ ▢        │ f          │    4 │ Sabretooth                                                                       │
--              class ⎰                mammals →│ mammalia │ ▢          │    ▢ │ Sabretooth, Megatherium, Paraceratherium                                         │
--                    ⎱               reptiles →│ reptilia │ ▢          │    ▢ │ Velociraptor, Iguanodon, Brachiosaurus                                           │
--              herb? ⎰             herbivores →│ ▢        │ t          │    ▢ │ Megatherium, Iguanodon, Paraceratherium, Brachiosaurus                           │
--                    ⎱             carnivores →│ ▢        │ f          │    ▢ │ Velociraptor, Sabretooth                                                         │
--               legs ⎰               bipedals →│ ▢        │ ▢          │    2 │ Megatherium, Velociraptor, Iguanodon                                             │
--                    ⎱           quadropedals →│ ▢        │ ▢          │    4 │ Sabretooth, Paraceratherium, Brachiosaurus                                       │
--                 () {    prehistoric animals →│ ▢        │ ▢          │    ▢ │ Sabretooth, Megatherium, Paraceratherium, Velociraptor, Iguanodon, Brachiosaurus │
--                                               └──────────┴────────────┴──────┴──────────────────────────────────────────────────────────────────────────────────┘

-----------------------------------------------------------------------
-- SQL evaluation order

EXPLAIN VERBOSE

SELECT DISTINCT ON ("∑d") 1 AS branch, NOT t.c AS "¬c", SUM(t.d) AS "∑d"
FROM   T AS t
WHERE  t.b = 'x'
GROUP BY "¬c"
HAVING SUM(t.d) > 0

  UNION ALL

SELECT DISTINCT ON ("∑d") 2 AS branch, NOT t.c AS "¬c", SUM(t.d) AS "∑d"
FROM   T AS t
WHERE  t.b = 'x'
GROUP BY "¬c"
HAVING SUM(t.d) > 0

ORDER BY branch
OFFSET 0
LIMIT  7;

-- Numbers in ⚫ refer to the slide "SQL Evaluation vs. Reading Order"
-- ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
-- │                                           QUERY PLAN                                            │
-- ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
-- │ Limit  (cost=49.76..49.77 rows=4 width=13) @(10) ➓                                             │
-- │   Output: (1), ((NOT t.c)), (sum(t.d))                                                          │
-- │   ->  Sort  (cost=49.76..49.77 rows=4 width=13) ➒                                              │
-- │         Output: (1), ((NOT t.c)), (sum(t.d))                                                    │
-- │         Sort Key: (1)                                                                           │
-- │         ->  Append  (cost=24.83..49.72 rows=4 width=13) ➑                                      │
-- │               ->  Unique  (cost=24.83..24.84 rows=2 width=5) ➐                                 │
-- │                     Output: (1), ((NOT t.c)), (sum(t.d))                                        │
-- │                     ->  Sort  (cost=24.83..24.84 rows=2 width=5)                                │
-- │                           Output: (1), ((NOT t.c)), (sum(t.d))                                  │
-- │                           Sort Key: (sum(t.d))                                                  │
-- │                           ->  HashAggregate  (cost=24.80..24.82 rows=2 width=5)                 │
-- │                                 Output: 1, ((NOT t.c)), sum(t.d) ➏                             │
-- │                                 Group Key: (NOT t.c) ➍                                         │
-- │                                 Filter: (sum(t.d) > 0) ➎                                       │
-- │                                 ->  Seq Scan on public.t  (cost=0.00..24.75 rows=6 width=5) ➊  │
-- │                                       Output: (NOT t.c), t.d ➌                                 │
-- │                                       Filter: (t.b = 'x'::text) ➋                              │
-- │               ->  Unique  (cost=24.83..24.84 rows=2 width=9)                                    │
-- │                     Output: (2), ((NOT t_1.c)), (sum(t_1.a))                                    │
-- │                     ->  Sort  (cost=24.83..24.84 rows=2 width=9)                                │
-- │                           Output: (2), ((NOT t_1.c)), (sum(t_1.a))                              │
-- │                           Sort Key: (sum(t_1.a))                                                │
-- │                           ->  HashAggregate  (cost=24.80..24.82 rows=2 width=9)                 │
-- │                                 Output: 2, ((NOT t_1.c)), sum(t_1.a)                            │
-- │                                 Group Key: (NOT t_1.c)                                          │
-- │                                 Filter: (sum(t_1.d) > 0)                                        │
-- │                                 ->  Seq Scan on public.t t_1  (cost=0.00..24.75 rows=6 width=9) │
-- │                                       Output: (NOT t_1.c), t_1.a, t_1.d                         │
-- │                                       Filter: (t_1.b = 'x'::text)                               │
-- └─────────────────────────────────────────────────────────────────────────────────────────────────┘
