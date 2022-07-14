-- Demonstrates Procedural SQL (PostgreSQL's PL/pgSQL variant)

-- Re-create our old friend, playground table T
DROP TABLE IF EXISTS T CASCADE;
CREATE TABLE T (a int PRIMARY KEY,
                b text,
                c boolean,
                d int);

INSERT INTO T VALUES
  (1, 'x', true,  10),
  (2, 'y', true,  40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x', true,  NULL);


-- Notes:
--  - RAISE NOTICE ‹e₁›, ‹e₂›, … reports values of ‹eᵢ› to database client (and writes to log),
--    ‹e₁› may be a literal format string in which `%'s are replaced by ‹e₂›, …

-----------------------------------------------------------------------
-- Block structure and variable scoping

DROP FUNCTION IF EXISTS f(text);
CREATE FUNCTION f(x text) RETURNS text AS
$$
-- ← << f >>  (implicit label for function body block)
BEGIN
  RAISE NOTICE 'outer block: x is %', x;
  DECLARE x text;
  BEGIN
    x := 'inner';
    RAISE NOTICE 'sub-block: x is %'  , x;
    RAISE NOTICE 'sub-block: f.x is %', f.x;
    f.x := 'overwritten ' || f.x;
  END;
  RETURN x;
END;
$$
LANGUAGE PLPGSQL;

SELECT f('outer');


-----------------------------------------------------------------------
-- Use c%TYPE in variable declaration to declare local variables
-- whose type matches polymorphic parameters

DROP FUNCTION IF EXISTS poly(anyelement);
CREATE FUNCTION poly(x anyelement) RETURNS anyelement AS
$$
DECLARE
  y x%TYPE;   -- type of y will be the same as x's type (say τ)
BEGIN
  y := 2 * x; -- will work for τ ∊ {int,float,numeric} since operation * is polymorphic, too
  RETURN y;
END;
$$
LANGUAGE PLPGSQL;

SELECT poly(21);  -- → 42
SELECT poly(2.1); -- → 4.2



-- Use the row type of a table to declare function parameters,
-- use dot notation to access fields in a row

-- Note: PostgreSQL reports `NOTICE:  type reference t.b%TYPE converted to text'
-- when the function is declared
DROP FUNCTION IF EXISTS get_b(T);
CREATE FUNCTION get_b(t T) RETURNS T.b%TYPE AS
$$
DECLARE x T.b%TYPE;
BEGIN
  x := t.b;   -- access row fields using dot notation
  RETURN x;
END;
$$
LANGUAGE PLPGSQL;

SELECT t.*
FROM   T AS t
WHERE  get_b(t) = 'x';  -- effectively: t.b = 'x'



-----------------------------------------------------------------------
-- Demonstrates assignment (via :=), implicit casts (also from textual syntax),
-- and the evaluation of expressions with free variables

DROP FUNCTION IF EXISTS expr(int);
CREATE FUNCTION expr(x int) RETURNS int AS
$$
DECLARE xs  int[];
        p   point;
        q   point;
BEGIN
  xs := array[20,x,54];
  p := '(0,0)';             -- may use textual syntax like in SQL, cast applied automatically
  q := point(xs[1],xs[2]);
  RETURN p <-> q;           -- see below ⁂, result will be cast to return type int
END;
$$
LANGUAGE PLPGSQL;

SELECT expr(37);


-- ⁂ Evaluation of PL/SQL expression p <-> q:
--
-- Expression compilation (once):
-- ➊ Find the free variables in expression (here: p, q)
-- ➋ PREPARE (≡ parse, analyse, compile to execution plan) named
--   expression with holes $n for free variables:
PREPARE expression1(point, point) AS
  SELECT $1 <-> $2;

-- Expression evaluation (possibly many times, e.g. in loops):
-- ➌ EXECUTE the prepared expression, supply the current variable
--   bindings for p, q as parameter values for $1, $2:
EXECUTE expression1(point(0,0), point(20,37));

-- Clean up
DEALLOCATE expression1;


-----------------------------------------------------------------------
-- Demonstrates SELECT INTO

-- Return maximum "a" value in table "T" for the given "b" value (default: 0)
DROP FUNCTION IF EXISTS max_a_for_b(T.b%TYPE);
CREATE FUNCTION max_a_for_b(b T.b%TYPE) RETURNS T.a%TYPE AS
$$
DECLARE max_a T.a%TYPE;
BEGIN
  SELECT t.a
  INTO   max_a                -- no STRICT modifier here: we may find 0 rows
  FROM   T as t
  WHERE  t.b = max_a_for_b.b  -- WHERE t.b = b: ambigious reference to b
  ORDER BY t.a DESC
  LIMIT 1;                    -- we may omit this (INTO picks the first row if we find many)
  -- return default value 0 in case no row was returned
  IF NOT FOUND THEN
    max_a = 0;
  END IF;
  --
  RETURN max_a;
END;
$$
LANGUAGE PLPGSQL;

SELECT max_a_for_b('x') AS x,
       max_a_for_b('y') AS y,
       max_a_for_b('?') AS "?";


-----------------------------------------------------------------------
-- Demonstrate the construction of a result set with RETURN NEXT

DROP FUNCTION IF EXISTS from_to(int, int);
CREATE FUNCTION from_to(f int, t int) RETURNS SETOF int AS
$$
BEGIN
  LOOP
    RETURN NEXT f;
    IF f = t THEN
      RETURN;
    END IF;
    f := f + sign(t - f);  -- f may be ≶ t, arbitrarily
  END LOOP;
END;
$$
LANGUAGE PLPGSQL;

SELECT i
FROM   from_to(1,10) AS i;

-- Demonstrate RETURN QUERY/RETURN NEXT

DROP FUNCTION IF EXISTS rows_or_default(int);
CREATE FUNCTION rows_or_default(d int) RETURNS SETOF T AS
$$
BEGIN
  RETURN QUERY SELECT t.*
               FROM   T AS t
               WHERE  t.d = rows_or_default.d;
  -- supply a default row if we found nothing
  IF NOT FOUND THEN
    DECLARE a int;
    BEGIN
      a := (SELECT MAX(t.a)
            FROM   T AS t);
      RETURN NEXT ROW(a + 1, NULL::text, NULL::boolean, NULL::int);  -- fields of a row not casted automatically by PL/SQL
    END;
    RAISE NOTICE '⚠ returning default row';
  END IF;
  RETURN;
END;
$$
LANGUAGE PLPGSQL;

SELECT t.*
FROM   rows_or_default(30) AS t;

SELECT t.*
FROM   rows_or_default(42) AS t;


-----------------------------------------------------------------------
-- Demonstrate control flow shortcuts in loops

-- Semantics "visualized" in terms of nested loops:
--  ────────────┐
--  o = a       │
--  ─────────┐  │
--    i = 1  │  │
--  ─────────┘  │
--  ─────────┐  │
--    i = 2  │  │
--  ─────────┘  │
--  ─────────┐  │
--    i = 3  │  │
--  ─────────┘  │
--  ────────────┘
-- [...]

DROP FUNCTION IF EXISTS control_flow();
CREATE FUNCTION control_flow() RETURNS void AS
$$
DECLARE o text;
        i int;
BEGIN
  << outer >>
  FOREACH o IN ARRAY array['a','b','c'] LOOP
    RAISE NOTICE '────────────┐';
    RAISE NOTICE 'o = %       │', o;
    << inner >>
    FOREACH i in ARRAY array[1,2,3] LOOP
      RAISE NOTICE '─────────┐  │';
      RAISE NOTICE '  i = %  │  │', i;
      -- Demonstrate effect of CONTINUE/EXIT:
      -- CONTINUE outer WHEN (o,i) = ('b',2);
      -- EXIT     outer WHEN (o,i) = ('b',2);
      -- CONTINUE inner WHEN (o,i) = ('b',2);
      -- EXIT     inner WHEN (o,i) = ('b',2);
      RAISE NOTICE '─────────┘  │';
    END LOOP;
    RAISE NOTICE '────────────┘';
  END LOOP;
END;
$$
LANGUAGE PLPGSQL;

SELECT control_flow();
