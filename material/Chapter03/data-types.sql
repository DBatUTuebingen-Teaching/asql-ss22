-- Query the PostgreSQL system catalog for the supported data types:

SELECT t.typname
FROM   pg_catalog.pg_type AS t
WHERE  t.typelem  = 0      -- disregard array element types
  AND  t.typrelid = 0;     -- list non-composite types only

-----------------------------------------------------------------------

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

-----------------------------------------------------------------------
-- (Implicit) Type casts

-- Runtime type conversion
SELECT 6.2 :: int;          -- ➝ 6
SELECT 6.6 :: int;          -- ➝ 7
SELECT date('May 4, 2022'); -- ➝ 2022-05-04 (May the Force ...)

-- Implicit conversion if target type is known (here: schema of T)
INSERT INTO T(a,b,c,d) VALUES (6.2, NULL, 'true', '0');
--                              ↑     ↑      ↑     ↑
--                             int  text  boolean int


-- Literal input syntax using '...' (cast from text to any other type):
SELECT booleans.yup :: boolean, booleans.nope :: boolean
FROM   (VALUES ('true', 'false'),
               ('True', 'False'),
               ('t',    'f'),   -- any prefix of 'true'/'false' is OK (whitespace, case do not matter)
               ('1',    '0'),
               ('yes',  'no'),
               ('on',   'off')) AS booleans(yup, nope);

-- May use $‹id›$...$‹id›$ instead of '...'
SELECT $$<t a='42'><l/><r/></t>$$ :: xml;

-- Type casts perform computation, validity checks, and thus are *not* for free:
SELECT $$<t a='42'><l/><r></t>$$ :: xml;
--                      ↑
--              ⚠️ no closing tag

-- Implicit cast from text to target during *input conversion*:
DELETE FROM T;

COPY T(a,b,c,d) FROM STDIN WITH (FORMAT CSV, NULL '▢');
1,x,true,10
2,y,true,40
3,x,false,30
4,y,false,20
5,x,true,▢
\.

TABLE T;

-----------------------------------------------------------------------
-- Text data types

SELECT '01234' :: char(3);   -- truncation to enforce limit after cast
--     └──┬──┘               -- NB: column name is `bpchar': blank-padded characters,
--      text                 --     PostgreSQL-internal name for char(‹n›)


-- Values of type char(n) are padded with blanks (spaces, ⎵) when stored or
-- printed, but trailing blanks are removed before computation:
SELECT '012' :: char(5) = '012  ' :: char(5);
--                            ⎵⎵
--                        trailing blanks



-- Character length vs. storage size in bytes (PostgreSQL built-in function octet_length())
SELECT t.c,
       length(t.c)       AS chars,
       octet_length(t.c) AS bytes
FROM   (VALUES ('x'),
               ('⚠'), -- ⚠ = U+26A0, in UTF8: 0xE2 0x9A 0xA0
               ('👩🏾')
       ) AS t(c);


-- Decide the default character encoding when database instance is created
-- (see https://www.postgresql.org/docs/current/multibyte.html)



SELECT octet_length('012346789' :: varchar(5)) AS c1, -- 5 (truncation)
       octet_length('012'       :: varchar(5)) AS c2, -- 3 (within limits)
       octet_length('012'       :: char(5))    AS c3, -- 5 (blank padding in storage)
       length('012'             :: char(5))    AS c4, -- 3 (padding in storage only)
       length('012  '           :: char(5))    AS c5; -- 3 (trailing blanks removed)


-----------------------------------------------------------------------
-- Overhead of NUMERIC(p,0) ≡ NUMERIC(p) arithmetics

\pset t on
SELECT (2::numeric)^100000; -- OK¹ (⚠ SQL syntax allows numeric(1000) only)
\pset t off

-- ¹ PostgresSQL actual limits:
--   up to 131072 digits before the decimal point,
--   up to 16383 digits after the decimal point


-- The following two queries to "benchmark" the
-- performance of numeric(.,.) vs. int arithmetics
-- (also see the resulting row width as output by EXPLAIN):

EXPLAIN (ANALYZE, VERBOSE, COSTS false, TIMING false)
-- 1M rows of byte width 32
WITH one_million_rows(x) AS (
  SELECT t.x :: numeric(8,0)
  FROM   generate_series(1, 1000000) AS t(x)
)
SELECT t.x + t.x AS add       -- ⎱ execution time for + (Function Scan): ~ 0.6s
FROM   one_million_rows AS t; -- ⎰



EXPLAIN (ANALYZE, VERBOSE, COSTS false, TIMING false)
-- 1M rows of width 4
WITH one_million_rows(x) AS (
  SELECT t.x :: int
  FROM   generate_series(1, 1000000) AS t(x)
)
SELECT t.x + t.x AS add       -- ⎱ execution time for + (Function Scan): ~ 0.3s
FROM   one_million_rows AS t; -- ⎰


-----------------------------------------------------------------------
-- Timestamps/Intervals


SELECT 'now'::date      AS "now (date)",
       'now'::time      AS "now (time)",
       'now'::timestamp AS "now (timestamp)";


-- Timestamps may be optionally annotated with time zones
SELECT 'now'::timestamp AS now,
       'now'::timestamp with time zone AS "now with tz";



--            output  input interpretation
--             ┌─┴──┐ ┌┴┐
SET datestyle='German,MDY';
SELECT '5-4-2022' :: date;  -- May 4, 2022

SET datestyle='German,DMY';
SELECT '5-4-2022' :: date;  -- April 4, 2022

-- Back to the default datestyle
SET datestyle='ISO,MDY';

-- Dates may be specified in a variety of forms
SELECT COUNT(DISTINCT birthdays.d::date) AS interpretations
FROM   (VALUES ('August 26, 1968'),
               ('Aug 26, 1968'),
               ('8.26.1968'),
               ('08-26-1968'),
               ('8/26/1968')) AS birthdays(d);

-- Special timestamps and dates
SELECT 'epoch'::timestamp    AS epoch,
       'infinity'::timestamp AS infinity,
       'today'::date         AS today,
       'yesterday'::date     AS yesterday,
       'tomorrow'::date      AS tomorrow;


SELECT '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::interval
        =
       'P1Y2M3DT4H5M6S'::interval; -- ISO 8601
--      └──┬──┘└──┬──┘
--   date part   time part


-- Date/time arithmetics with intervals
\x on
SELECT 'Aug 31, 2035'::date - 'now'::timestamp                     AS retirement,
       'now'::date + '30 days'::interval                           AS in_one_month,
       'now'::date + 2 * '1 month'::interval                       AS in_two_months,
       'tomorrow'::date - 'now'::timestamp                         AS til_midnight,
        extract(hours from ('tomorrow'::date - 'now'::timestamp))  AS hours_til_midnight,
       'tomorrow'::date - 'yesterday'::date                        AS two, -- ⚠ yields int
       make_interval(days => 'tomorrow'::date - 'yesterday'::date) AS two_days;
\x off


--                year    month  day               ignore time 00:00:00, keep date only
--                 ↓        ↓     ↓                         ↓
SELECT (make_date(2022, months.m, 1) - '1 day'::interval)::date AS last_day_of_month
FROM   generate_series(1,12) AS months(m);


SELECT timezones.tz AS timezone,
       'now'::timestamp with time zone -- uses default ("show time zone")
         -
       ('now'::timestamp::text || ' ' || timezones.tz)::timestamp with time zone AS difference
FROM   (VALUES ('America/New_York'),
               ('Europe/Berlin'),
               ('Asia/Tokyo'),
               ('PST'),
               ('UTC'),
               ('UTC-6'),
               ('+3')
       ) AS timezones(tz)
ORDER BY difference;

-- Do two periods of date/time overlap (infix operator 'overlaps')?
SELECT holiday.holiday
FROM   (VALUES ('Easter',    'Apr 19, 2022', 'Apr 23, 2022'),
               ('Pentecost', 'Jun  7, 2022', 'Jun 18, 2022'),
               ('Summer',    'Jul 28, 2022', 'Sep 10, 2022'),
               ('Autumn',    'Nov  2, 2022', 'Nov  4, 2022'),
               ('Winter',    'Dec 21, 2022', 'Jan  7, 2023')) AS holiday(holiday, "start", "end")
WHERE  (holiday.start :: date, holiday.end :: date) overlaps ('today','today');


-----------------------------------------------------------------------
-- Enumerations

--            deletes tables with episode columns
--                             ↓
DROP TYPE IF EXISTS episode CASCADE;
CREATE TYPE episode AS ENUM
  ('ANH', 'ESB', 'TPM', 'AOTC', 'ROTS', 'ROTJ', 'TFA', 'TLJ', 'TROS');

DROP TABLE IF EXISTS starwars;
CREATE TABLE starwars(film    episode PRIMARY KEY,
                      title   text,
                      release date);

INSERT INTO starwars(film,title,release) VALUES
    ('TPM',  'The Phantom Menace',      'May 19, 1999'),
    ('AOTC', 'Attack of the Clones',    'May 16, 2002'),
    ('ROTS', 'Revenge of the Sith',     'May 19, 2005'),
    ('ANH',  'A New Hope',              'May 25, 1977'),
    ('ESB',  'The Empire Strikes Back', 'May 21, 1980'),
    ('ROTJ', 'Return of the Jedi',      'May 25, 1983'),
    ('TFA',  'The Force Awakens',       'Dec 18, 2015'),
    ('TLJ',  'The Last Jedi',           'Dec 15, 2017'),
    ('TROS', 'The Rise of Skywalker',   'Dec 19, 2019');
--     ↑              ↑                        ↑
-- ::episode       ::text                    ::date

INSERT INTO starwars(film,title,release) VALUES
  ('R1', 'Rogue One', 'Dec 15, 2016');
--   ↑
-- ⚠️ not an episode value

-- Order of enumerated type (almost) yields the Star Wars Machete order
SELECT s.*
FROM   starwars AS s
ORDER BY s.film; -- s.release; -- yields chronological order


-----------------------------------------------------------------------
-- Binary byte sequences

-- See extra file glados.sql (requires *.wav files).


-----------------------------------------------------------------------
-- Geometric objects


-- Estimate the value of π using the "Monte Carlo method"
-- (see https://graui.de/code/montePi/):
--
-- ➊ Place circle c with r = 0.5 at point (0.5, 0.5).
--   Area of c is πr² = π/4.
-- ➋ Generate random point p in unit square (0,0)-(1,1).
--   Area of square is 1.
-- ⇒ Chance of p being in c = (π/4)/1 = π/4.
--
--               π/4 = nᵢₙ/n


-- # of random points to generate
\set N 1000000

SELECT (COUNT(*)::float / :N) * 4 AS π
FROM   generate_series(1, :N) AS _
WHERE  circle(point(0.5,0.5), 0.5) @> point(random(),random());
--                                 ↑
--                       circle contains point?



-- See extra files scanner.sql / scanner.gpl (requires Gnuplot).


-----------------------------------------------------------------------
-- JSON

-- jsonb
VALUES (1, '{ "b":1, "a":2 }'       ::jsonb),  -- ← pair order may flip
       (2, '{ "a":1, "b":2, "a":3 }'       ),  -- ← duplicate field
       (3, '[ 0,   false,null ]'           );  -- ← whitespace normalized

-- json
VALUES (1, '{ "b":1, "a":2 }'       ::json ),  -- ← pair order and ...
       (2, '{ "a":1, "b":2, "a":3 }'       ),  -- ← ... duplicates preserved
       (3, '[ 0,   false,null ]'           );  -- ← whitespace preserved



--  Navigating a JSON value using subscripting
SELECT ('{ "a":0, "b": { "b₁":[1,2], "b₂":3 } }' :: jsonb)['b']['b₁'][1] :: int + 40;
--                                                                       ↑
--                                     extracts a jsonb value, cast for computation

--  Navigating a JSON value using SQL/JSON path syntax
--    (SQL/JSON paths represented as quoted literals of type jsonpath)
--
--    JSON describes tree-shaped data:
--
--                   root $       {}               level 0
--                              ᵃ╱  ╲ᵇ
--                              𝟬    {}            level 1
--                                 ᶜ╱  ╲ᵈ
--                                 []   𝟯          level 2
--                               ⁰╱  ╲¹
--                               𝟭    𝟮            level 3

SELECT j
FROM   jsonb_path_query('{ "a":0, "b": { "c":[1,2], "d":3 } }' :: jsonb,
                     '$'                        -- root value
                     -- '$.*'                   -- all child values of the root
                     -- '$.a'                   -- child a of the root
                     -- '$.b.d'                 -- grandchild d below child b
                     -- '$.b.c[1]'              -- 2nd array element of array c
                     -- '$.b.c[*]'              -- all array elements in array c
                     -- '$.**'                  -- recursion: all values including root
                     -- '$.**{3}'               -- all values at level 3
                     -- '$.**{last}'            -- all leaf values
                       ) AS j;

-------------------------------
-- Goal: Convert table into JSON (jsonb) array of objects

-- Step ➊: convert each row into a JSON object (columns ≡ fields)
--
SELECT row_to_json(t)::jsonb
FROM   T AS t;

-- Step ➋: aggregate the table of JSON objects into one JSON array
--          (here: in some element order)
--
--  may understood as a unity for now (array_agg() in focus soon)
--     ╭──────────┴───────────╮
SELECT array_to_json(array_agg(row_to_json(t)))::jsonb
FROM   T as t;


-- Pretty-print JSON output
--
SELECT jsonb_pretty(array_to_json(array_agg(row_to_json(t)))::jsonb)
FROM   T as t;


-- Table T represented as a JSON object (JSON value in single row/single column)
DROP TABLE IF EXISTS like_T_but_as_JSON;
CREATE TEMPORARY TABLE like_T_but_as_JSON(a) AS
  SELECT array_to_json(array_agg(row_to_json(t)))::jsonb
  FROM   T as t;

TABLE like_T_but_as_JSON;

-------------------------------
-- Goal: Convert JSON object (array of regular objects) into a table:
--       can we do a round-trip and get back the original T?


-- Step ➊: convert JSON array into table of JSON objects
--
SELECT objs.o
FROM   jsonb_array_elements((TABLE like_T_but_as_JSON)) AS objs(o);

-- NB: Steps ➋a and ➋b/c lead to alternative tabular representation:

-- Step ➋a: turn JSON objects into key/value pairs (⚠️ column value::jsonb)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE like_T_but_as_JSON)) AS objs(o),
       jsonb_each(objs.o) AS t;


-- Step ➋b: turn JSON objects into rows (fields ≡ columns)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE like_T_but_as_JSON)) AS objs(o),
       jsonb_to_record(objs.o) AS t(a int, b text, c boolean, d int);
--                                ╰────────────────┬───────────────╯
--                   explicitly provide column name and type information
--                      (⚠️ column and field names/types must match)


-- Step ➋c: turn JSON objects into rows (fields ≡ columns)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE like_T_but_as_JSON)) AS objs(o),
       jsonb_populate_record(NULL :: T, objs.o) AS t;
--                          ╰───┬────╯
--   derive column names and types from T's row type (cf. Chapter 02)
--            (⚠️ column and field names/types must match)



-- Steps ➊+➋: from array of JSON objects directly to typed tables
SELECT t.*
FROM   jsonb_populate_recordset(NULL :: T, (TABLE like_T_but_as_JSON)) AS t;


-----------------------------------------------------------------------
-- Sequences

-- ⚠ Sequences and table share a common name space, watch out for
--   collisions
DROP SEQUENCE IF EXISTS seq;
CREATE SEQUENCE seq START 41 MAXVALUE 100 CYCLE;

SELECT nextval('seq');      -- ⇒ 41
SELECT nextval('seq');      -- ⇒ 42
SELECT currval('seq');      -- ⇒ 42
SELECT setval ('seq',100);  -- ⇒ 100 (+ side effect)
SELECT nextval('seq');      -- ⇒ 1   (wrap-around)

-- Behind the scenes, sequences are system-maintained single-row tables:
--
TABLE seq;

-- ┌────────────┬─────────┬───────────┐
-- │ last_value │ log_cnt │ is_called │
-- ├────────────┼─────────┼───────────┤
-- │          1 │      32 │ t         │ ← has nextval() been called already?
-- └────────────┴─────────┴───────────┘

--                     is_called
--                         ↓
SELECT setval ('seq',100,false);  -- ⇒ 100 (+ side effect)
SELECT nextval('seq');            -- ⇒ 100


DROP TABLE IF EXISTS self_concious_T;
CREATE TABLE self_concious_T (me int GENERATED ALWAYS AS IDENTITY,
                              a  int ,
                              b  text,
                              c  boolean,
                              d  int);


--                    column me missing (⇒ receives GENERATED identity value)
--                         ╭───┴──╮
INSERT INTO self_concious_T(a,b,c,d) VALUES
  (1, 'x',  true, 10);

INSERT INTO self_concious_T(a,b,c,d) VALUES
  (2, 'y',  true, 40);

INSERT INTO self_concious_T(a,b,c,d) VALUES
  (5, 'x', true,  NULL),
  (4, 'y', false, 20),
  (3, 'x', false, 30)
  RETURNING me, c;
--            ↑
--     General INSERT feature:
--     Any list of expressions involving the column name of
--     the inserted rows (or * to return entire inserted rows)
--     ⇒ User-defined SQL functions (UDFs)
