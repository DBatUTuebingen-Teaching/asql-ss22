-- Demonstrate the use of recursive queries to implement a
-- deterministic finite state machine (FSM), implementing
-- regular expression matching.

-----------------------------------------------------------------------
-- Relational representation of finite state machine

DROP DOMAIN IF EXISTS state CASCADE;
CREATE DOMAIN state AS integer;

-- Transition table
DROP TABLE IF EXISTS fsm;
CREATE TABLE fsm (
  source   state NOT NULL, -- source state of transition
  labels   text  NOT NULL, -- transition labels (input)
  target   state,          -- target state of transition
  "final?" boolean,        -- is source a final state?
  PRIMARY KEY (source, labels)
);

-- Create DFA transition table for regular expression
-- ([A-Za-z]+[₀-₉]*([⁰-⁹]*[⁺⁻])?)+
INSERT INTO fsm(source,labels,target,"final?") VALUES
  (0, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',           1, false ),
  (1, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz₀₁₂₃₄₅₆₇₈₉', 1, true ),
  (1, '⁰¹²³⁴⁵⁶⁷⁸⁹',                                                     2, true),
  (1, '⁺⁻',                                                             3, true ),
  (2, '⁰¹²³⁴⁵⁶⁷⁸⁹',                                                     2, false),
  (2, '⁺⁻',                                                             3, false ),
  (3, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',           1, true );

SELECT f.source, left(f.labels,10) AS labels, f.target, f."final?"
FROM   fsm AS f;

---------------------------------------------------------------------
-- Molecule table
DROP TABLE IF EXISTS compounds;
CREATE TABLE compounds (
  compound text NOT NULL PRIMARY KEY,
  formula  text
);

INSERT INTO compounds(compound, formula) VALUES
  ('dichromate anion', 'Cr₂O₇²⁻'),
  ('citrate',          'C₆H₅O₇³⁻'),
  ('glucose',          'C₆H₁₂O₆'),
  ('hydronium',        'H₃O⁺'),
  ('grustium',         'T₄₂G⁺⁺');    -- Uhm?

TABLE compounds;

-----------------------------------------------------------------------

WITH RECURSIVE
match(compound, step, state, input) AS (
   SELECT c.compound, 0 AS step, 0 AS state, c.formula
   FROM   compounds AS c
     UNION ALL
   SELECT m.compound,
          m.step + 1         AS step,
          f.target           AS state,
          right(m.input, -1) AS input
   FROM   match AS m, fsm AS f
   WHERE  length(m.input) > 0
   AND    m.state = f.source
   AND    strpos(f.labels, left(m.input, 1)) > 0
)
--
-- ➊ Observe matching progress for each compound individually
-- SELECT m.*
-- FROM   match AS m
-- ORDER BY m.compound, m.step;
--
-- ➋ Observe parallel matching progress for all compounds
-- SELECT m.step, m.compound, m.state, m.input
-- FROM   match AS m
-- ORDER BY m.step, m.compound;
--
-- ➌
SELECT DISTINCT ON (m.compound) m.compound,
       m.input = '' AND m.state IN (SELECT f.source                  -- ⎫
                                    FROM   fsm AS f                  -- ⎬  all FSM final states
                                    WHERE  f."final?") AS "success?" -- ⎭
FROM   match AS m
ORDER BY m.compound, m.step DESC;

