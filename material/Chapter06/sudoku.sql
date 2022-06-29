-- Brute force solver for Sudoku
-- (adapted from http://www.sqlite.org/lang_with.html#recursivecte)
--
-- Returns all possible solutions in about 600ms (a good Suduko board
-- has a unique solution).
--
-- Invariant for table sudoku:
--
-- If (board, blank) ∊ sudoku, then board is a 9×9=81-integer array of a (partially solved)
-- valid Sudoku board in which blank ∊ {0,2,...,80} is the offset of the first unknown digit
-- (represented by 0).  If blank is NULL, then board is a complete solution.
--
-- (Note: array_position(xs, 0) yields NULL if 0 is not found in xs)



DROP TABLE IF EXISTS puzzle;
CREATE TEMPORARY TABLE puzzle (
  row    int  GENERATED ALWAYS AS IDENTITY,
  digits text NOT NULL
);

-- Sample Sudoku instances

-- \COPY puzzle(digits) FROM stdin
-- 53..7....
-- 6..195...
-- .98....6.
-- 8...6...3
-- 4..8.3..1
-- 7...2...6
-- .6....28.
-- ...419..5
-- ....8..79
-- \.

\COPY puzzle(digits) FROM stdin
...6...75
4...5.8.1
.3..7..2.
..6..1...
...7..58.
.9..3...6
.4...9...
..18..2..
.......3.
\.

TABLE puzzle;

-----------------------------------------------------------------------

WITH RECURSIVE
-- encode Sudoku board as one-dimensional array in row-major order
input(board) AS (
  SELECT array_agg(digits::int) AS board
  FROM   unnest((SELECT string_to_array(string_agg(replace(p.digits, '.', '0'), NULL ORDER BY p.row), NULL)
                 FROM   puzzle AS p)) AS digits
),
-- solve Sudoko board by a recursive generate-and-test process
sudoku(board, blank) AS (
  SELECT i.board AS board, array_position(i.board, 0)-1 AS blank
  FROM   input AS i
      UNION ALL
  SELECT                s.board[1:s.blank] || fill_in || s.board[s.blank+2:81]       AS board,
         array_position(s.board[1:s.blank] || fill_in || s.board[s.blank+2:81], 0)-1 AS blank
  FROM  sudoku AS s, generate_series(1,9) AS fill_in
  WHERE s.blank IS NOT NULL
    AND NOT EXISTS (
      SELECT NULL
      FROM   generate_series(1,9) AS i
      WHERE  fill_in IN (s.board[(s.blank/9) * 9                           + i],                  --  row of blank (offset i)
                         s.board[s.blank%9                                 + (i-1)*9 + 1],        --  column of blank (offset i)
                         s.board[((s.blank/3) % 3) * 3 + (s.blank/27) * 27 + i + ((i-1)/3) * 6])  --  box of blank (offset i)
   )
),
-- (recursive) post-processing only: generate formatted board output
output(board, row, digits, rest) AS (
  SELECT ROW_NUMBER() OVER () AS board,
         0 AS row,
         left(array_to_string(s.board, ''),    9) AS digits,
         right(array_to_string(s.board, ''), - 9) AS rest
  FROM   sudoku AS s
  WHERE  s.blank IS NULL
    UNION ALL
  SELECT o.board,
         o.row + 1 AS row,
         left(o.rest, 9) AS digits,
         right(o.rest, length(o.rest) - 9) AS rest
  FROM   output AS o
  WHERE  o.rest <> ''
)
-- ➊ Raw input Sudoku board in array-encoding
-- TABLE input;
-- ➋ Complete progress towards solved board (⚠ huge)
-- TABLE sudoku;
-- ➌ Raw solved Sudoku board
SELECT s.board
FROM   sudoku AS s
WHERE  s.blank IS NULL;
-- ➍ Formatted solved Sudoku board
-- SELECT o.board AS number, o.digits AS solution
-- FROM   output AS o
-- ORDER BY o.board, o.row;


-- Computing offsets (with blank ∊ {0,...,80}):
--
-- (blank/9) * 9 ∊ {0,9,18,27,36,45,54,63,72}:                        beginning (left) of row containing blank
-- blank%9 ∊ {0,1,2,3,4,5,6,7,8}:                                     beginning (top)  of column containing blank
-- ((blank/3) % 3) * 3 + (blank/27) * 27 ∊ {0,3,6,27,30,33,54,57,60}: beginning (top left) of box containing blank

