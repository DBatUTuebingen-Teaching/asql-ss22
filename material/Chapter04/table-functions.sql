-- Table-generating (set-returning) SQL Functions

-----------------------------------------------------------------------
-- generate_series, generate_subscripts

-- 1, 3, 5, 7, 9 (since 1 ⩽ i ⩽ 10)
SELECT i
FROM   generate_series(1,10,2) AS i;

-- 0, -0.1, ..., -2.0
SELECT i
FROM   generate_series(0,-2,-0.1) AS i;


-- generate subscripts in dimension d of the given array
SELECT i
FROM   generate_subscripts(array[[10,20,30], [40,50,60]], 2) AS i;
--                                                        ↑
--                                               dimension (here: 1 or 2)

WITH matrix(m) AS (
  SELECT array[[10,20,30],
               [40,50,60]]
)
SELECT row, col, mx.m[row][col]
FROM   matrix AS mx,
       generate_subscripts(mx.m, 1) AS row,
       generate_subscripts(mx.m, 2) AS col;

-----------------------------------------------------------------------
-- string_to_table, string_to_array


-- ➊ Split string into individual words/characters, together with their index
SELECT words.pos, words.word
FROM   string_to_table('Luke, I am Your Father', ' ')
       WITH ORDINALITY AS words(word, pos);
--                                                ↑
--                                   separator string  (if NULL, split on each character)
--                                                ↓
SELECT string_to_array('Luke, I am Your Father', ' ');


-- ➋ Split string into individual words/characters, together with their index
--
SELECT words.pos, words.word
FROM   unnest(string_to_array('Luke, I am Your Father', ' '))
       WITH ORDINALITY AS words(word, pos);


-- ➌ Split string into individual words/characters, together with their index
--
SELECT pos, words[pos]
FROM   (SELECT string_to_array('Luke, I am Your Father', ' ')) AS _(words),
       generate_subscripts(words, 1) AS pos;


-----------------------------------------------------------------------
-- regexp_matches, regexp_split_to_table

-- Breaking Bad: Parse a chemical formula
--
-- (C₆H₅O₇³⁻ is Citrate)

-- Variant on slide: report NULL (≡ no charge) if charge unspecified
SELECT t.match[1] AS element, t.match[2] AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?',
                      'g')                    -- ────────────────
       AS t(match);                           -- does not match if no charge ⇒ yields NULL


SELECT t.match[1] AS element, t.match[2] AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',                                            -- input text ‹t›
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)((?:[⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?)',  -- regular expression ‹re›
                      'g')                    -- ─────────────────────
       AS t(match);                           -- matches empty string if no charge ⇒ yields ''


-- Split string into whitespace-separated words
--
SELECT words.*
FROM   regexp_split_to_table('Luke, I am Your Father', '\s+')
       WITH ORDINALITY AS words(word, pos);
--                                                       ↑
--                       any white space character, alternatively: [[:space:]]



-----------------------------------------------------------------------
-- Zipping

-- Watching Star Wars: The (Extended) Machete Order
--
SELECT starwars.*
FROM   unnest(array[4,5,1,2,3,6,7,8,9],          -- episode numbers
              array['A New Hope',                -- episode titles
                    'The Empire Strikes Back',
                    'The Phantom Menace',
                    'Attack of the Clones',
                    'Revenge of the Sith',
                    'Return of the Jedi',
                    'The Force Awakens',
                    'The Last Jedi',
                    'The Rise of Skywalker'])
       WITH ORDINALITY AS starwars(episode,film,watch)
ORDER BY watch;


\set expression '4*10+x'
\set operators  '([*+\-/])'

-- Extract subexpressions and operators from arithmetic expression
--
SELECT  t.exp AS subexpression, t.op[1] AS operator
FROM    ROWS FROM(regexp_split_to_table(:'expression', :'operators'),
                  regexp_matches       (:'expression', :'operators', 'g')) AS t(exp,op);


-- Reconstruct original expression from constituents:
--
SELECT  string_agg(t.exp || COALESCE(t.op[1], ''), '' ORDER BY t.pos) AS expression
FROM    ROWS FROM(regexp_split_to_table(:'expression', :'operators'),
                  regexp_matches       (:'expression', :'operators', 'g'))
        WITH ORDINALITY AS t(exp,op,pos);

-- Note:
--  - COALESCE(e₁,e₂,...,eₙ): evaluate the eᵢ :: τ in order, return the
--    value of the first non-NULL eᵢ



-----------------------------------------------------------------------
-- User-defined SQL Functions


-- Atomic return type (int)
-- Map subscript symbols to their numeric value: '₀' to 0, '₁' to 1, ...
-- (returns NULL if a non-subscript symbol is passed)
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value
  FROM   (VALUES ('₀', 0),
                 ('₁', 1),
                 ('₂', 2),
                 ('₃', 3),
                 ('₄', 4),
                 ('₅', 5),
                 ('₆', 6),
                 ('₇', 7),
                 ('₈', 8),
                 ('₉', 9)) AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Alternative variant using array/WITH ORDINALITY
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value::int - 1
  FROM   unnest(array['₀','₁','₂','₃','₄','₅','₆','₇','₈','₉'])
         WITH ORDINALITY AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Modify chemical formula parser (see above): returns actual atom count
--
--                                 ↓
SELECT t.match[1] AS element, subscript(t.match[2]) AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?',
                      'g')                    -- ────────────────
       AS t(match);                           -- does not match if no charge ⇒ yields NULL



-- Atomic return type (text), incurs side effect
-- Generate a unique ID of the form '‹prefix›###' and log time of generation
--
DROP TABLE IF EXISTS issue;
CREATE TABLE issue (
  id     int GENERATED ALWAYS AS IDENTITY,
  "when" timestamp);

DROP FUNCTION IF EXISTS new_ID(text);
CREATE FUNCTION new_ID(prefix text) RETURNS text AS
$$
  INSERT INTO issue(id, "when") VALUES
    (DEFAULT, 'now'::timestamp)
  RETURNING prefix || id::text
$$
LANGUAGE SQL VOLATILE;
--              ↑
--  "function" incurs a side-effect


-- Everybody is welcome as our customer, even bi-pedal dinosaurs!
--
SELECT new_ID('customer') AS customer, d.species
FROM   dinosaurs AS d
WHERE  d.legs = 2;

-- How is customer acquisition going?
TABLE issue;



-- Table-generating UDF (polymorphic): unnest a two-dimensional array
-- in column-major order:
--
CREATE OR REPLACE FUNCTION unnest2(xss anyarray)
  RETURNS SETOF anyelement AS
$$
SELECT xss[row][col]
FROM   generate_subscripts(xss,1) AS row,
       generate_subscripts(xss,2) AS col
ORDER BY col, row  --  return elements in column-major order
$$
LANGUAGE SQL IMMUTABLE;

                    --  columns of 2D array
SELECT t.*          --      ↓   ↓   ↓
FROM   unnest2(array[array['a','b','c'],
                     array['d','e','f'],
                     array['x','y','z']])
       WITH ORDINALITY AS t(elem,pos);






-----------------------------------------------------------------------
-- Dependent iteration (LATERAL)

-- Exception: dependent iteration OK in table-generating functions
--
SELECT t.tree, MAX(node.label) AS "largest label"
FROM   Trees AS t,
       LATERAL unnest(t.labels) AS node(label)  -- ⚠️ refers to t.labels: dependent iteration
GROUP BY t.tree;


-- Equivalent reformulation (dependent iteration → subquery in SELECT)
--
SELECT t.tree, (SELECT MAX(node.label)
                FROM   unnest(t.labels) AS node(label)) AS "largest label"
FROM   Trees AS t
GROUP BY t.tree;


-- ⚠️ This reformulation is only possible if the subquery yields
--   a scalar result (one row, one column) only ⇒ LATERAL is more general.
--   See the example (and its somewhat awkward reformulation) below.



-- Find the three tallest two- or four-legged dinosaurs:
--
SELECT locomotion.legs, tallest.species, tallest.height
FROM   (VALUES (2), (4)) AS locomotion(legs),
       LATERAL (SELECT d.*
                FROM   dinosaurs AS d
                WHERE  d.legs = locomotion.legs
                ORDER BY d.height DESC
                LIMIT 3) AS tallest;


-- Equivalent reformulation without LATERAL
--
WITH ranked_dinosaurs(species, legs, height, rank) AS (
  SELECT d1.species, d1.legs, d1.height,
         (SELECT COUNT(*)                          -- number of
          FROM   dinosaurs AS d2                   -- dinosaurs d2
          WHERE  d1.legs = d2.legs                 -- in d1's peer group
          AND    d1.height <= d2.height) AS rank   -- that are as large or larger as d1
  FROM   dinosaurs AS d1
  WHERE  d1.legs IS NOT NULL
)
SELECT d.legs, d.species, d.height
FROM   ranked_dinosaurs AS d
WHERE  d.legs IN (2,4)
AND    d.rank <= 3
ORDER BY d.legs, d.rank;

