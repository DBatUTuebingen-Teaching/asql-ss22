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
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.c, t.d ASC;


-- In absence of ORDER BY, we get *any* representative from the
-- two groups (PostgreSQL still uses sorting on t.c, however):
EXPLAIN (TIMING false, COSTS false)
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t;

-- An "incompatible" clause lets PostgreSQL choke:
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.a;

