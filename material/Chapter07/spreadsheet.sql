-- Simple spreadsheet
--
-- Formulæ in cells may refer to each other.  The code below finds
-- dependencies between cells (a DAG) and uses topological sorting
-- to determine an evaluation order.

-- Valid formulæ:
-- 1. float literal (e.g. 4.2)
-- 2. cell reference (e.g., A3)
-- 3. n-ary operator (+, -, *, /) with n argument formulæ
-- 4. aggregate (sum, avg, max, min) over rectangular cell range (e.g. sum(A2:D5))

-- The spreadsheet is stored in table sheet, one cell per row.  Spreadsheet
-- evaluation *updates* the cells in table sheet.


-- A cell address (‹col›,‹row›), ('A',3) to represent A3
DROP TYPE IF EXISTS cell CASCADE;
CREATE TYPE cell AS (
  col   text, -- column (A..)
  "row" int   -- row (1..)
);

-- The spreadsheet
DROP TABLE IF EXISTS sheet;
CREATE TABLE sheet (
  cell    cell PRIMARY KEY,  -- cell address
  formula jsonb              -- contained formula (JSON representation, see below)
);

-- JSON representation of formulæ:
-- 1. float literal:  {"entry":"num",  "num":4.2}
-- 2. cell reference: {"entry":"cell", "cell":"(A,3)"}
-- 3. operator:       {"entry":"op",   "op":"+", args:[‹formula›,‹formula›]}
-- 4. aggregate:      {"entry":"agg",  "agg":"sum", "from":"(A,2)", "to":"(D,5)"}


-- A sample spreadsheet instance (also see slides)
--
--   |     A        B        C         D
-- --+-------------------------------------
-- 1 |     1       3.50    A1×B1      0.88
-- 2 |     2       6.10    A2×B2
-- 3 |     2       0.98    A3×B3
-- 4 | SUM(A1:A3)        SUM(C1:C3)  D1×C4
--
TRUNCATE sheet;
INSERT INTO sheet(cell, formula) VALUES
  (('A',1), '{"entry":"num", "num":1}'),
  (('A',2), '{"entry":"num", "num":2}'),
  (('A',3), '{"entry":"num", "num":2}'),
  (('A',4), '{"entry":"agg", "agg":"sum", "from":"(A,1)", "to":"(A,3)"}'),
  (('B',1), '{"entry":"num", "num":3.50}'),
  (('B',2), '{"entry":"num", "num":6.10}'),
  (('B',3), '{"entry":"num", "num":0.98}'),
  (('C',1), '{"entry":"op" , "op" :"*", "args":[{"entry":"cell", "cell":"(A,1)"}, {"entry":"cell", "cell":"(B,1)"}]}'),
  (('C',2), '{"entry":"op" , "op" :"*", "args":[{"entry":"cell", "cell":"(A,2)"}, {"entry":"cell", "cell":"(B,2)"}]}'),
  (('C',3), '{"entry":"op" , "op" :"*", "args":[{"entry":"cell", "cell":"(A,3)"}, {"entry":"cell", "cell":"(B,3)"}]}'),
  (('C',4), '{"entry":"agg", "agg":"sum", "from":"(C,1)", "to":"(C,3)"}'),
  (('D',1), '{"entry":"num", "num":0.88}'),
  (('D',4), '{"entry":"op" , "op" :"*", "args":[{"entry":"cell", "cell":"(D,1)"}, {"entry":"cell", "cell":"(C,4)"}]}');


-----------------------------------------------------------------------

-- Generate all cells in the rectangular area defined by cells c1, c2
--
DROP FUNCTION IF EXISTS cells(cell,cell);
CREATE FUNCTION cells(c1 cell, c2 cell) RETURNS SETOF cell AS
$$
  SELECT (chr(col), "row")::cell
  FROM   generate_series(ascii(LEAST(c1.col, c2.col)), ascii(GREATEST(c1.col, c2.col))) AS col,
         generate_series(LEAST(c1."row", c2."row"),    GREATEST(c1."row", c2."row"))    AS "row";
$$
LANGUAGE SQL;

-- Find all cells referenced by formula e
-- NB.  e->>'f' accesses field f of jsonb value e and casts the result to text
--
DROP FUNCTION IF EXISTS refs(jsonb);
CREATE FUNCTION refs(e jsonb) RETURNS SETOF cell AS
$$
BEGIN
  CASE e['entry']
    WHEN '"op"' THEN
        -- recursively collect references found in operator arguments
        RETURN QUERY SELECT c.*
                     FROM   jsonb_array_elements(e['args']) AS arg,
                            LATERAL refs(arg) AS c;
    WHEN '"agg"'  THEN
        -- all cells in rectangular area are referenced
        RETURN QUERY SELECT c.*
                     FROM   cells((e->>'from')::cell, (e->>'to')::cell) AS c;
    WHEN '"cell"' THEN RETURN NEXT (e->>'cell')::cell;  -- reference to single cell
    WHEN '"num"'  THEN NULL;                            -- no reference
    ELSE RAISE EXCEPTION 'refs: unknown cell entry % found', e['entry'];
  END CASE;
  RETURN;
END;
$$
LANGUAGE PLPGSQL;




-- Access float value stored in cell c
-- (we assume that cell c has already been evaluated and updated
-- to hold a float value)
--
DROP FUNCTION IF EXISTS value(cell);
CREATE FUNCTION value(c cell) RETURNS float AS
$$
DECLARE v float;
BEGIN
  SELECT s.formula->>'num'
         INTO v
  FROM   sheet AS s
  WHERE  s.cell = c AND s.formula['entry'] = '"num"';
  -- bail out if we've not found a value in cell c
  IF NOT FOUND THEN
    RAISE EXCEPTION 'value: expected number in cell % but there isn''t any', c;
  END IF;
  -- v is the value in cell c
  RETURN v;
END;
$$
LANGUAGE PLPGSQL;


DROP FUNCTION IF EXISTS eval(jsonb);
CREATE FUNCTION eval(e jsonb) RETURNS float AS
$$
DECLARE v float;
BEGIN
  CASE e['entry']
    WHEN '"op"' THEN
      CASE e['op']
        WHEN '"+"' THEN v := eval(e['args'][0]) + eval(e['args'][1]);
        WHEN '"-"' THEN v := eval(e['args'][0]) - eval(e['args'][1]);
        WHEN '"*"' THEN v := eval(e['args'][0]) * eval(e['args'][1]);
        WHEN '"/"' THEN v := eval(e['args'][0]) / eval(e['args'][1]);
        ELSE RAISE EXCEPTION 'eval: unknown operator %', e['op'];
      END CASE;
    WHEN '"agg"' THEN v := (SELECT CASE e['agg']
                                     WHEN '"sum"' THEN SUM(value(c)) -- OK because of topo sort
                                     WHEN '"avg"' THEN AVG(value(c))
                                     WHEN '"max"' THEN MAX(value(c))
                                     WHEN '"min"' THEN MIN(value(c))
                                   END
                            FROM   cells((e->>'from')::cell, (e->>'to')::cell) AS c);
    WHEN '"cell"' THEN v := value((e->>'cell')::cell); -- OK because of topo sort
    WHEN '"num"'  THEN v := e->>'num';
    ELSE RAISE EXCEPTION 'eval: unknown cell entry %', e['entry'];
  END CASE;
  -- v is the value of expression e
  RETURN v;
END;
$$
LANGUAGE PLPGSQL;



DROP FUNCTION IF EXISTS eval_sheet(cell[]);
CREATE FUNCTION eval_sheet(cs cell[]) RETURNS boolean AS
$$
DECLARE c cell;
        v float;
        e jsonb;
BEGIN
  FOREACH c IN ARRAY cs LOOP
    SELECT s.formula
           INTO e
    FROM   sheet AS s
    WHERE  s.cell = c;
    -- bail out if there is no cell c in the sheet
    IF NOT FOUND THEN
      RAISE NOTICE 'eval_sheet: unknown cell % referenced', c;
      RETURN false;
    END IF;
    -- evaluate expression e
    v := eval(e);
    -- replace expression e by its value v in the sheet
    UPDATE sheet AS s
    SET    formula = jsonb_build_object('entry', 'num', 'num', v)
    WHERE  s.cell = c;
  END LOOP;
  RETURN true;
END;
$$
LANGUAGE PLPGSQL;


-- Sheet evaluation
--
WITH RECURSIVE
-- ➊ Populate dependencies based on formulæ in sheet
dependencies(cell, uses) AS (
  SELECT DISTINCT s.cell, u
  FROM   sheet AS s,
         LATERAL refs(s.formula) AS u
),
-- ➋ Topologically sort cells based on the dependencies
--   to determine an evaluation order
earliest(pos, col, "row") AS (
  SELECT DISTINCT 0 AS pos, (d.uses).col, (d.uses)."row"
  FROM   dependencies AS d
  WHERE  d.uses NOT IN (SELECT d1.cell
                        FROM   dependencies AS d1)
    UNION
  SELECT e.pos + 1 AS pos, (d.cell).col, (d.cell)."row"
  FROM   earliest AS e, dependencies AS d
  WHERE  d.uses = (e.col, e."row")
),
topo_sort(pos, cell) AS (
  SELECT MAX(e.pos) AS pos, (e.col, e."row")::cell AS cell
  FROM   earliest AS e
  GROUP BY e.col, e."row"
)
-- ➌ Evaluate the entire sheet, given an evaluation order on its cells
SELECT eval_sheet((SELECT array_agg(t.cell ORDER BY t.pos)
                   FROM   topo_sort AS t));
--
-- TABLE dependencies
-- ORDER BY cell;
--
-- TABLE topo_sort
-- ORDER BY pos, cell;

-- Show evaluated sheet
--
TABLE sheet
ORDER BY cell;

